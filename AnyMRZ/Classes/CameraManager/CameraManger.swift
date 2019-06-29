//
//  CameraManger.swift
//  AnyMRZ
//
//  Created by Bohdan Mihiliev on 29.06.2019.
//  Copyright © 2019 Bohdan Mihiliev. All rights reserved.
//  swiftlint:disable type_body_length file_length cyclomatic_complexity

import AVFoundation
import Photos
import ImageIO
import MobileCoreServices
import CoreMotion
import Photos

final class CameraManager: NSObject, AVCaptureFileOutputRecordingDelegate, UIGestureRecognizerDelegate {
    
    // MARK: - Public properties
    var captureSession: AVCaptureSession?
    var showErrorsToUsers = false
    var showAccessPermissionPopupAutomatically = true
    var writeFilesToPhoneLibrary = false
    var shouldFlipFrontCameraImage = false
    var shouldKeepViewAtOrientationChanges = false
    var animateCameraDeviceChange: Bool = true
    var animateShutter: Bool = true
    var recordedDuration: CMTime { return movieOutput?.recordedDuration ?? CMTime.zero }
    var recordedFileSize: Int64 { return movieOutput?.recordedFileSize ?? 0 }
    var focusMode: AVCaptureDevice.FocusMode = .continuousAutoFocus
    var exposureMode: AVCaptureDevice.ExposureMode = .continuousAutoExposure
    var captureRawCIImageFromCamera: ((CIImage, CGImagePropertyOrientation) -> Void)?
    var imageCompletion: ((UIImage?, NSError?) -> Void)?
    
    // MARK: - Public properties observers
    var shouldRespondToOrientationChanges = true {
        didSet {
            if shouldRespondToOrientationChanges {
                startFollowingDeviceOrientation()
            } else {
                stopFollowingDeviceOrientation()
            }
        }
    }
    
    var shouldEnableTapToFocus = true {
        didSet {
            focusGesture.isEnabled = shouldEnableTapToFocus
        }
    }
    
    var shouldEnablePinchToZoom = true {
        didSet {
            zoomGesture.isEnabled = shouldEnablePinchToZoom
        }
    }
    
    var shouldUseLocationServices: Bool = false {
        didSet {
            if shouldUseLocationServices == true {
                locationManager = CameraLocationManager()
            }
        }
    }
    
    var cameraDevice = CameraDevice.back {
        didSet {
            if cameraIsSetup {
                if cameraDevice != oldValue {
                    if animateCameraDeviceChange {
                        doFlipAnimation()
                    }
                    updateCameraDevice(cameraDevice)
                    //          _updateFlashMode(flashMode)
                    setupMaxZoomScale()
                    zoom(0)
                }
            }
        }
    }
    
    var flashMode = CameraFlashMode.off {
        didSet {
            if cameraIsSetup {
                if flashMode != oldValue {
                    //          _updateFlashMode(flashMode)
                    Logger.i("Flash Mode: \(flashMode.rawValue)")
                }
            }
        }
    }
    
    var cameraOutputQuality = CameraOutputQuality.high {
        didSet {
            if cameraIsSetup {
                if cameraOutputQuality != oldValue {
                    updateCameraQualityMode(cameraOutputQuality)
                }
            }
        }
    }
    
    var cameraOutputMode = CameraOutputMode.stillImage {
        didSet {
            if cameraIsSetup {
                if cameraOutputMode != oldValue {
                    setupOutputMode(cameraOutputMode, oldCameraOutputMode: oldValue)
                }
                setupMaxZoomScale()
                zoom(0)
            }
        }
    }
    
    // MARK: - Computed Properties
    var cameraIsReady: Bool {
        return cameraIsSetup
    }
    
    var hasFrontCamera: Bool {
        return !AVCaptureDevice.videoDevices.filter { $0.position == .front }.isEmpty
        //    let frontDevices = AVCaptureDevice.videoDevices.filter { $0.position == .front }
        //    return !frontDevices.isEmpty
    }
    
    var hasFlash: Bool {
        return !AVCaptureDevice.videoDevices.filter { $0.hasFlash }.isEmpty
        //    let hasFlashDevices = AVCaptureDevice.videoDevices.filter { $0.hasFlash }
        //    return !hasFlashDevices.isEmpty
    }
    
    var currentCameraState: CameraState {
        let deviceHasCamera = UIImagePickerController.isCameraDeviceAvailable(UIImagePickerController.CameraDevice.rear) || UIImagePickerController.isCameraDeviceAvailable(UIImagePickerController.CameraDevice.front)
        if deviceHasCamera {
            let authorizationStatus = AVCaptureDevice.authorizationStatus(for: AVMediaType.video)
            let userAgreedToUseIt = authorizationStatus == .authorized
            if userAgreedToUseIt {
                return .ready
            } else if authorizationStatus == AVAuthorizationStatus.notDetermined {
                return .notDetermined
            } else {
                _show(NSLocalizedString("Camera access denied", comment: ""),
                      message: NSLocalizedString("You need to go to settings app and grant acces to the camera device to use it.",
                                                 comment: ""))
                return .accessDenied
            }
        } else {
            _show(NSLocalizedString("Camera unavailable", comment: ""),
                  message: NSLocalizedString("The device does not have a camera.",
                                             comment: ""))
            return .noDeviceFound
        }
    }
    
    // MARK: - Private properties
    private var locationManager: CameraLocationManager?
    private weak var embeddingView: UIView?
    private var videoCompletion: ((_ videoURL: URL?, _ error: NSError?) -> Void)?
    private var sessionQueue: DispatchQueue = DispatchQueue(label: "CameraSessionQueue", attributes: [])
    private var photoOutput: AVCapturePhotoOutput?
    private var movieOutput: AVCaptureMovieFileOutput?
    private var rawDataOutput: AVCaptureVideoDataOutput?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var library: PHPhotoLibrary?
    private var cameraIsSetup = false
    private var cameraIsObservingDeviceOrientation = false
    private var zoomScale = CGFloat(1.0)
    private var beginZoomScale = CGFloat(1.0)
    private var maxZoomScale = CGFloat(1.0)
    private var deviceOrientation: UIDeviceOrientation = .portrait
    private var coreMotionManager: CMMotionManager!
    
    // MARK: - Private Computed Properties
    private var frontCameraDevice: AVCaptureDevice? {
        return AVCaptureDevice.videoDevices.filter { $0.position == .front }.first
    }
    
    private var backCameraDevice: AVCaptureDevice? {
        return AVCaptureDevice.videoDevices.filter { $0.position == .back }.first
    }
    
    private var mic: AVCaptureDevice? {
        return AVCaptureDevice.default(for: AVMediaType.audio)
    }
    
    fileprivate func _currentCaptureVideoOrientation() -> AVCaptureVideoOrientation {
        
        if deviceOrientation == .faceDown
            || deviceOrientation == .faceUp
            || deviceOrientation == .unknown {
            return _currentPreviewVideoOrientation()
        }
        
        return _videoOrientation(forDeviceOrientation: deviceOrientation)
    }
    
    fileprivate func _currentPreviewDeviceOrientation() -> UIDeviceOrientation {
        if shouldKeepViewAtOrientationChanges {
            return .portrait
        }
        
        return UIDevice.current.orientation
    }
    
    fileprivate func _currentPreviewVideoOrientation() -> AVCaptureVideoOrientation {
        let orientation = _currentPreviewDeviceOrientation()
        return _videoOrientation(forDeviceOrientation: orientation)
    }
    
    func resetOrientation() {
        //Main purpose is to reset the preview layer orientation.  Problems occur if you are recording landscape, present a modal VC,
        //then turn portriat to dismiss.  The preview view is then stuck in a prior orientation and not redrawn.  Calling this function
        //will then update the orientation of the preview layer.
        orientationChanged()
    }
    
    fileprivate func _videoOrientation(forDeviceOrientation deviceOrientation: UIDeviceOrientation) -> AVCaptureVideoOrientation {
        switch deviceOrientation {
        case .landscapeLeft:
            return .landscapeRight
        case .landscapeRight:
            return .landscapeLeft
        case .portraitUpsideDown:
            return .portraitUpsideDown
        case .faceUp:
            /*
             Attempt to keep the existing orientation.  If the device was landscape, then face up
             getting the orientation from the stats bar would fail every other time forcing it
             to default to portrait which would introduce flicker into the preview layer.  This
             would not happen if it was in portrait then face up
             */
            if let validPreviewLayer = previewLayer, let connection = validPreviewLayer.connection {
                return connection.videoOrientation //Keep the existing orientation
            }
            //Could not get existing orientation, try to get it from stats bar
            return _videoOrientationFromStatusBarOrientation()
        case .faceDown:
            /*
             Attempt to keep the existing orientation.  If the device was landscape, then face down
             getting the orientation from the stats bar would fail every other time forcing it
             to default to portrait which would introduce flicker into the preview layer.  This
             would not happen if it was in portrait then face down
             */
            if let validPreviewLayer = previewLayer, let connection = validPreviewLayer.connection {
                return connection.videoOrientation //Keep the existing orientation
            }
            //Could not get existing orientation, try to get it from stats bar
            return _videoOrientationFromStatusBarOrientation()
        default:
            return .portrait
        }
    }
    
    fileprivate func _videoOrientationFromStatusBarOrientation() -> AVCaptureVideoOrientation {
        
        var orientation: UIInterfaceOrientation?
        
        DispatchQueue.main.async {
            orientation = UIApplication.shared.statusBarOrientation
        }
        
        /*
         Note - the following would fall into the guard every other call (it is called repeatedly) if the device was
         landscape then face up/down.  Did not seem to fail if in portrait first.
         */
        guard let statusBarOrientation = orientation else {
            return .portrait
        }
        
        switch statusBarOrientation {
        case .landscapeLeft:
            return .landscapeLeft
        case .landscapeRight:
            return .landscapeRight
        case .portrait:
            return .portrait
        case .portraitUpsideDown:
            return .portraitUpsideDown
        default:
            return .portrait
        }
    }
    
    fileprivate func fixOrientation(withImage image: UIImage) -> UIImage {
        guard let cgImage = image.cgImage else { return image }
        
        var isMirrored = false
        let orientation = image.imageOrientation
        if orientation == .rightMirrored
            || orientation == .leftMirrored
            || orientation == .upMirrored
            || orientation == .downMirrored {
            
            isMirrored = true
        }
        
        let newOrientation = _imageOrientation(forDeviceOrientation: deviceOrientation, isMirrored: isMirrored)
        
        if image.imageOrientation != newOrientation {
            return UIImage(cgImage: cgImage, scale: image.scale, orientation: newOrientation)
        }
        
        return image
    }
    private func _imageOrientation(forDeviceOrientation deviceOrientation: UIDeviceOrientation, isMirrored: Bool) -> UIImage.Orientation {
        
        switch deviceOrientation {
        case .landscapeLeft:
            return isMirrored ? .upMirrored : .up
        case .landscapeRight:
            return isMirrored ? .downMirrored : .down
        default:
            break
        }
        
        return isMirrored ? .leftMirrored : .right
    }
    
    private var tempFilePath: URL {
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("tempMovie\(Date().timeIntervalSince1970)")
            .appendingPathExtension("mp4")
        return tempURL
    }
    
    private var photoCaptureSettings: AVCapturePhotoSettings {
        let settings = AVCapturePhotoSettings()
        switch flashMode {
        case .auto: settings.flashMode = .auto
        case .on: settings.flashMode = .on
        default: settings.flashMode = .off
        }
        
        if let previewPixelType = settings.availablePreviewPhotoPixelFormatTypes.first {
            let previewFormat = [
                kCVPixelBufferPixelFormatTypeKey as String: previewPixelType,
                kCVPixelBufferWidthKey as String: 160,
                kCVPixelBufferHeightKey as String: 160
            ]
            
            settings.previewPhotoFormat = previewFormat
        }
        
        return settings
    }
    
    // MARK: - CameraManager
    
    /**
     Inits a capture session and adds a preview layer to the given view.
     Preview layer bounds will automaticaly be set to match given view. Default session is initialized with still image output.
     
     :param: view The view you want to add the preview layer to
     :param: cameraOutputMode The mode you want capturesession to run image / video / video and microphone
     :param: completion Optional completion block
     
     :returns: Current state of the camera: Ready / AccessDenied / NoDeviceFound / NotDetermined.
     */
    @discardableResult
    func addPreviewLayerToView(_ view: UIView,
                               newCameraOutputMode: CameraOutputMode? = nil,
                               completion: (() -> Void)? = nil) -> CameraState {
        if let newCameraOutputMode = newCameraOutputMode { cameraOutputMode = newCameraOutputMode }
        return addLayerPreviewTo(view, newCameraOutputMode: cameraOutputMode, completion: completion)
    }
    
    private func addLayerPreviewTo(_ view: UIView, newCameraOutputMode: CameraOutputMode,
                                   completion: (() -> Void)? = nil) -> CameraState {
        if canLoadCamera {
            if embeddingView != nil {
                if let validPreviewLayer = previewLayer {
                    validPreviewLayer.removeFromSuperlayer()
                }
            }
            if cameraIsSetup {
                addPreviewLayerToView(view)
                cameraOutputMode = newCameraOutputMode
                if let validCompletion = completion {
                    validCompletion()
                }
            } else {
                setupCamera { [weak self] in
                    self?.addPreviewLayerToView(view)
                    self?.cameraOutputMode = newCameraOutputMode
                    if let validCompletion = completion {
                        validCompletion()
                    }
                }
            }
        }
        return currentCameraState
    }
    
    /**
     Asks the user for camera permissions. Only works if the permissions are not yet determined.
     Note that it'll also automaticaly ask about the microphone permissions if you selected VideoWithMic output.
     
     :param: completion Completion block with the result of permission request
     */
    func askUserForCameraPermission(_ completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: AVMediaType.video,
                                      completionHandler: { [weak self] (allowedAccess) -> Void in
                                        if self?.cameraOutputMode == .videoWithMic {
                                            AVCaptureDevice.requestAccess(for: AVMediaType.audio,
                                                                          completionHandler: { (allowedAccess) -> Void in
                                                                            DispatchQueue.main.async {
                                                                                completion(allowedAccess)
                                                                            }
                                            })
                                        } else {
                                            DispatchQueue.main.async {
                                                completion(allowedAccess)
                                            }
                                        }
        })
    }
    
    /**
     Stops running capture session but all setup devices, inputs and outputs stay for further reuse.
     */
    func stopCaptureSession() {
        captureSession?.stopRunning()
        stopFollowingDeviceOrientation()
    }
    
    /**
     Resumes capture session.
     */
    func resumeCaptureSession() {
        if let validCaptureSession = captureSession {
            if !validCaptureSession.isRunning && cameraIsSetup {
                validCaptureSession.startRunning()
                startFollowingDeviceOrientation()
            }
        } else {
            if canLoadCamera {
                if cameraIsSetup {
                    stopAndRemoveCaptureSession()
                }
                setupCamera { [weak self] in
                    if let validEmbeddingView = self?.embeddingView {
                        self?.addPreviewLayerToView(validEmbeddingView)
                    }
                    self?.startFollowingDeviceOrientation()
                }
            }
        }
    }
    
    func stopAndRemoveCaptureSession() {
        stopCaptureSession()
        let oldAnimationValue = animateCameraDeviceChange
        animateCameraDeviceChange = false
        cameraDevice = .back
        cameraIsSetup = false
        previewLayer = nil
        captureSession = nil
        movieOutput = nil
        animateCameraDeviceChange = oldAnimationValue
    }
    
    /**
     Captures still image from currently running capture session.
     */
    func capturePicture() {
        guard cameraIsSetup else {
            _show(NSLocalizedString("No capture session setup", comment: ""),
                  message: NSLocalizedString("I can't take any picture", comment: ""))
            return
        }
        
        guard cameraOutputMode == .stillImage else {
            _show(NSLocalizedString("Capture session output mode video", comment: ""),
                  message: NSLocalizedString("I can't take any picture", comment: ""))
            return
        }
        
        let photoOutput = getPhotoOutput()
        
        photoOutput.capturePhoto(with: photoCaptureSettings, delegate: self)
        if animateShutter { performShutterAnimation(nil) }
    }
    
    /**
     Starts recording a video with or without voice as in the session preset.
     */
    func startRecordingVideo() {
        if cameraOutputMode != .stillImage {
            fileMovieOutput.startRecording(to: tempFilePath, recordingDelegate: self)
        } else {
            _show(NSLocalizedString("Capture session output still image", comment: ""),
                  message: NSLocalizedString("I can only take pictures", comment: ""))
        }
    }
    
    /**
     Stop recording a video. Save it to the cameraRoll and give back the url.
     */
    func stopVideoRecording(_ completion:((_ videoURL: URL?, _ error: NSError?) -> Void)?) {
        if let runningMovieOutput = movieOutput {
            if runningMovieOutput.isRecording {
                videoCompletion = completion
                runningMovieOutput.stopRecording()
            }
        }
    }
    
    /**
     Current camera status.
     
     :returns: Current state of the camera: Ready / AccessDenied / NoDeviceFound / NotDetermined
     */
    //  func currentCameraStatus() -> CameraState {
    //    return _checkIfCameraIsAvailable()
    //  }
    //
    /**
     Change current flash mode to next value from available ones.
     
     :returns: Current flash mode: Off / On / Auto
     */
    func changeFlashMode() -> CameraFlashMode {
        guard let newFlashMode = CameraFlashMode(rawValue: (flashMode.rawValue+1)%3) else { return flashMode }
        flashMode = newFlashMode
        return flashMode
    }
    
    /**
     Change current output quality mode to next value from available ones.
     
     :returns: Current quality mode: Low / Medium / High
     */
    func changeQualityMode() -> CameraOutputQuality {
        guard let newQuality = CameraOutputQuality(rawValue: (cameraOutputQuality.rawValue+1)%3) else { return cameraOutputQuality }
        cameraOutputQuality = newQuality
        return cameraOutputQuality
    }
    
    /**
     Check the camera device has flash
     */
    private func hasFlash(for cameraDevice: CameraDevice) -> Bool {
        let devices = AVCaptureDevice.videoDevices
        for device in devices {
            if device.position == .back && cameraDevice == .back {
                return device.hasFlash
            } else if device.position == .front && cameraDevice == .front {
                return device.hasFlash
            }
        }
        return false
    }
    
    // MARK: - AVCaptureFileOutputRecordingDelegate
    func fileOutput(_ captureOutput: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        // TODO:    _updateFlashMode(.off) // Probably dont need here
        if let error = error {
            _show(NSLocalizedString("Unable to save video to the iPhone", comment: ""), message: error.localizedDescription)
        } else {
            if writeFilesToPhoneLibrary {
                if PHPhotoLibrary.authorizationStatus() == .authorized {
                    saveVideoToLibrary(outputFileURL)
                } else {
                    PHPhotoLibrary.requestAuthorization({ [weak self] autorizationStatus in
                        if autorizationStatus == .authorized {
                            self?.saveVideoToLibrary(outputFileURL)
                        }
                    })
                }
            } else {
                executeVideoCompletionWithURL(outputFileURL, error: error as NSError?)
            }
        }
    }
    
    private func saveVideoToLibrary(_ fileURL: URL) {
        if let validLibrary = library {
            validLibrary.performChanges({ [weak self] in
                let request = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: fileURL)
                request?.creationDate = Date()
                
                if let location = self?.locationManager?.latestLocation {
                    request?.location = location
                }
                }, completionHandler: { [weak self] _, error in
                    if let error = error {
                        self?._show(NSLocalizedString("Unable to save video to the iPhone.", comment: ""), message: error.localizedDescription)
                        self?.executeVideoCompletionWithURL(nil, error: error as NSError?)
                    } else {
                        self?.executeVideoCompletionWithURL(fileURL, error: error as NSError?)
                    }
            })
        }
    }
    
    // MARK: - UIGestureRecognizerDelegate
    private lazy var zoomGesture = UIPinchGestureRecognizer()
    
    private func attachZoom(_ view: UIView) {
        DispatchQueue.main.async { [unowned self] in
            self.zoomGesture.addTarget(self, action: #selector(CameraManager.zoomStart(_:)))
            view.addGestureRecognizer(self.zoomGesture)
            self.zoomGesture.delegate = self
        }
    }
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        
        if gestureRecognizer.isKind(of: UIPinchGestureRecognizer.self) {
            beginZoomScale = zoomScale
        }
        
        return true
    }
    
    @objc
    private func zoomStart(_ recognizer: UIPinchGestureRecognizer) {
        guard let view = embeddingView,
            let previewLayer = previewLayer
            else { return }
        
        var allTouchesOnPreviewLayer = true
        let numTouch = recognizer.numberOfTouches
        
        for index in 0 ..< numTouch {
            let location = recognizer.location(ofTouch: index, in: view)
            let convertedTouch = previewLayer.convert(location, from: previewLayer.superlayer)
            if !previewLayer.contains(convertedTouch) {
                allTouchesOnPreviewLayer = false
                break
            }
        }
        if allTouchesOnPreviewLayer {
            zoom(recognizer.scale)
        }
    }
    
    private func zoom(_ scale: CGFloat) {
        let device: AVCaptureDevice?
        
        switch cameraDevice {
        case .back:
            device = backCameraDevice
        case .front:
            device = frontCameraDevice
        }
        
        do {
            let captureDevice = device
            try captureDevice?.lockForConfiguration()
            
            zoomScale = max(1.0, min(beginZoomScale * scale, maxZoomScale))
            
            captureDevice?.videoZoomFactor = zoomScale
            
            captureDevice?.unlockForConfiguration()
            
        } catch {
            Logger.e(error.localizedDescription)
        }
    }
    
    // MARK: - UIGestureRecognizerDelegate
    private lazy var focusGesture = UITapGestureRecognizer()
    
    private func attachFocus(_ view: UIView) {
        DispatchQueue.main.async { [unowned self] in
            self.focusGesture.addTarget(self, action: #selector(CameraManager._focusStart(_:)))
            view.addGestureRecognizer(self.focusGesture)
            self.focusGesture.delegate = self
        }
    }
    
    @objc private func _focusStart(_ recognizer: UITapGestureRecognizer) {
        
        let device: AVCaptureDevice?
        
        switch cameraDevice {
        case .back:
            device = backCameraDevice
        case .front:
            device = frontCameraDevice
        }
        
        if let validDevice = device {
            
            if let validPreviewLayer = previewLayer,
                let view = recognizer.view {
                let pointInPreviewLayer = view.layer.convert(recognizer.location(in: view), to: validPreviewLayer)
                let pointOfInterest = validPreviewLayer.captureDevicePointConverted(fromLayerPoint: pointInPreviewLayer)
                
                do {
                    try validDevice.lockForConfiguration()
                    
                    showFocusRectangleAtPoint(pointInPreviewLayer, inLayer: validPreviewLayer)
                    
                    if validDevice.isFocusPointOfInterestSupported {
                        validDevice.focusPointOfInterest = pointOfInterest
                    }
                    
                    if  validDevice.isExposurePointOfInterestSupported {
                        validDevice.exposurePointOfInterest = pointOfInterest
                    }
                    
                    if validDevice.isFocusModeSupported(focusMode) {
                        validDevice.focusMode = focusMode
                    }
                    
                    if validDevice.isExposureModeSupported(exposureMode) {
                        validDevice.exposureMode = exposureMode
                    }
                    
                    validDevice.unlockForConfiguration()
                } catch {
                    Logger.e(error.localizedDescription)
                }
            }
        }
    }
    
    private var lastFocusRectangle: CAShapeLayer?
    
    private func showFocusRectangleAtPoint(_ focusPoint: CGPoint, inLayer layer: CALayer) {
        
        if let lastFocusRectangle = lastFocusRectangle {
            
            lastFocusRectangle.removeFromSuperlayer()
            self.lastFocusRectangle = nil
        }
        
        let size = CGSize(width: 75, height: 75)
        let rect = CGRect(origin: CGPoint(x: focusPoint.x - size.width / 2.0, y: focusPoint.y - size.height / 2.0), size: size)
        
        let endPath = UIBezierPath(rect: rect)
        endPath.move(to: CGPoint(x: rect.minX + size.width / 2.0, y: rect.minY))
        endPath.addLine(to: CGPoint(x: rect.minX + size.width / 2.0, y: rect.minY + 5.0))
        endPath.move(to: CGPoint(x: rect.maxX, y: rect.minY + size.height / 2.0))
        endPath.addLine(to: CGPoint(x: rect.maxX - 5.0, y: rect.minY + size.height / 2.0))
        endPath.move(to: CGPoint(x: rect.minX + size.width / 2.0, y: rect.maxY))
        endPath.addLine(to: CGPoint(x: rect.minX + size.width / 2.0, y: rect.maxY - 5.0))
        endPath.move(to: CGPoint(x: rect.minX, y: rect.minY + size.height / 2.0))
        endPath.addLine(to: CGPoint(x: rect.minX + 5.0, y: rect.minY + size.height / 2.0))
        
        let startPath = UIBezierPath(cgPath: endPath.cgPath)
        let scaleAroundCenterTransform = CGAffineTransform(translationX: -focusPoint.x, y: -focusPoint.y)
            .concatenating(CGAffineTransform(scaleX: 2.0, y: 2.0)
                .concatenating(CGAffineTransform(translationX: focusPoint.x, y: focusPoint.y)))
        startPath.apply(scaleAroundCenterTransform)
        
        let shapeLayer = CAShapeLayer()
        shapeLayer.path = endPath.cgPath
        shapeLayer.fillColor = UIColor.clear.cgColor
        shapeLayer.strokeColor = UIColor(red: 1, green: 0.83, blue: 0, alpha: 0.95).cgColor
        shapeLayer.lineWidth = 1.0
        
        layer.addSublayer(shapeLayer)
        lastFocusRectangle = shapeLayer
        
        CATransaction.begin()
        
        CATransaction.setAnimationDuration(0.2)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeOut))
        
        CATransaction.setCompletionBlock { [weak self] in
            if shapeLayer.superlayer != nil {
                shapeLayer.removeFromSuperlayer()
                self?.lastFocusRectangle = nil
            }
        }
        
        let appearPathAnimation = CABasicAnimation(keyPath: "path")
        appearPathAnimation.fromValue = startPath.cgPath
        appearPathAnimation.toValue = endPath.cgPath
        shapeLayer.add(appearPathAnimation, forKey: "path")
        
        let appearOpacityAnimation = CABasicAnimation(keyPath: "opacity")
        appearOpacityAnimation.fromValue = 0.0
        appearOpacityAnimation.toValue = 1.0
        shapeLayer.add(appearOpacityAnimation, forKey: "opacity")
        
        let disappearOpacityAnimation = CABasicAnimation(keyPath: "opacity")
        disappearOpacityAnimation.fromValue = 1.0
        disappearOpacityAnimation.toValue = 0.0
        disappearOpacityAnimation.beginTime = CACurrentMediaTime() + 0.8
        disappearOpacityAnimation.fillMode = CAMediaTimingFillMode.forwards
        disappearOpacityAnimation.isRemovedOnCompletion = false
        shapeLayer.add(disappearOpacityAnimation, forKey: "opacity")
        
        CATransaction.commit()
    }
    
    // MARK: - CameraManager()
    
    private func executeVideoCompletionWithURL(_ url: URL?, error: NSError?) {
        if let validCompletion = videoCompletion {
            validCompletion(url, error)
            videoCompletion = nil
        }
    }
    
    private var fileMovieOutput: AVCaptureMovieFileOutput {
        if let movieOutput = movieOutput, let connection = movieOutput.connection(with: AVMediaType.video),
            connection.isActive {
            return movieOutput
        }
        let newMoviewOutput = AVCaptureMovieFileOutput()
        newMoviewOutput.movieFragmentInterval = CMTime.invalid
        movieOutput = newMoviewOutput
        if let captureSession = captureSession {
            if captureSession.canAddOutput(newMoviewOutput) {
                captureSession.beginConfiguration()
                captureSession.addOutput(newMoviewOutput)
                captureSession.commitConfiguration()
            }
        }
        return newMoviewOutput
    }
    
    private func getPhotoOutput() -> AVCapturePhotoOutput {
        if let photoOutput = photoOutput, let connection = photoOutput.connection(with: AVMediaType.video),
            connection.isActive {
            return photoOutput
        }
        let newPhotoOutput = AVCapturePhotoOutput()
        photoOutput = newPhotoOutput
        if let captureSession = captureSession {
            if captureSession.canAddOutput(newPhotoOutput) {
                captureSession.beginConfiguration()
                captureSession.addOutput(newPhotoOutput)
                captureSession.commitConfiguration()
            }
        }
        return newPhotoOutput
    }
    
    @objc private func orientationChanged() {
        //
        //    var currentConnection: AVCaptureConnection?
        //
        //    switch cameraOutputMode {
        //    case .stillImage:
        //      currentConnection = stillImageOutput?.connection(with: AVMediaType.video)
        //    case .videoOnly, .videoWithMic:
        //      currentConnection = _getMovieOutput().connection(with: AVMediaType.video)
        //      if let location = self.locationManager?.latestLocation {
        //        _setVideoWithGPS(forLocation: location)
        //      }
        //    }
        
        if let validPreviewLayer = previewLayer {
            if !shouldKeepViewAtOrientationChanges {
                if let validPreviewLayerConnection = validPreviewLayer.connection,
                    validPreviewLayerConnection.isVideoOrientationSupported {
                    validPreviewLayerConnection.videoOrientation = _currentPreviewVideoOrientation()
                }
            }
            if let validOutputLayerConnection = currentConnection,
                validOutputLayerConnection.isVideoOrientationSupported {
                
                validOutputLayerConnection.videoOrientation = _currentCaptureVideoOrientation()
            }
            if !shouldKeepViewAtOrientationChanges {
                DispatchQueue.main.async(execute: { () -> Void in
                    if let validEmbeddingView = self.embeddingView {
                        validPreviewLayer.frame = validEmbeddingView.bounds
                    }
                })
            }
        }
    }
    
    private var currentConnection: AVCaptureConnection? {
        switch cameraOutputMode {
        case .stillImage:
            return photoOutput?.connection(with: .video)
        case .videoOnly, .videoWithMic:
            return fileMovieOutput.connection(with: .video)
        case .rawData:
            return rawDataOutput?.connection(with: .video)
        }
    }
    
    private var canLoadCamera: Bool {
        return currentCameraState == .ready || (currentCameraState == .notDetermined && showAccessPermissionPopupAutomatically)
    }
    
    private func setupCamera(_ completion: @escaping () -> Void) {
        captureSession = AVCaptureSession()
        
        sessionQueue.async { [unowned self] in
            if let validCaptureSession = self.captureSession {
                validCaptureSession.beginConfiguration()
                validCaptureSession.sessionPreset = AVCaptureSession.Preset.high
                self.updateCameraDevice(self.cameraDevice)
                self.setupOutputs()
                self.setupOutputMode(self.cameraOutputMode, oldCameraOutputMode: nil)
                self.setupPreviewLayer()
                validCaptureSession.commitConfiguration()
                //        self._updateFlashMode(self.flashMode)
                self.updateCameraQualityMode(self.cameraOutputQuality)
                validCaptureSession.startRunning()
                self.startFollowingDeviceOrientation()
                self.cameraIsSetup = true
                self.orientationChanged()
                
                completion()
            }
        }
    }
    
    private func startFollowingDeviceOrientation() {
        if shouldRespondToOrientationChanges && !cameraIsObservingDeviceOrientation {
            coreMotionManager = CMMotionManager()
            coreMotionManager.accelerometerUpdateInterval = 0.005
            
            if coreMotionManager.isAccelerometerAvailable {
                coreMotionManager.startAccelerometerUpdates(to: OperationQueue(), withHandler: { data, _ in
                    guard let acceleration: CMAcceleration = data?.acceleration  else { return }
                    
                    let scaling: CGFloat = CGFloat(1) / CGFloat(( abs(acceleration.x) + abs(acceleration.y)))
                    
                    let xVal: CGFloat = CGFloat(acceleration.x) * scaling
                    let yVal: CGFloat = CGFloat(acceleration.y) * scaling
                    
                    if acceleration.z < Double(-0.75) {
                        self.deviceOrientation = .faceUp
                    } else if acceleration.z > Double(0.75) {
                        self.deviceOrientation = .faceDown
                    } else if xVal < CGFloat(-0.5) {
                        self.deviceOrientation = .landscapeLeft
                    } else if xVal > CGFloat(0.5) {
                        self.deviceOrientation = .landscapeRight
                    } else if yVal > CGFloat(0.5) {
                        self.deviceOrientation = .portraitUpsideDown
                    }
                    
                    self.orientationChanged()
                })
                
                cameraIsObservingDeviceOrientation = true
            } else {
                cameraIsObservingDeviceOrientation = false
            }
        }
    }
    
    fileprivate func updateDeviceOrientation(_ orientaion: UIDeviceOrientation) {
        self.deviceOrientation = orientaion
    }
    
    fileprivate func stopFollowingDeviceOrientation() {
        if cameraIsObservingDeviceOrientation {
            coreMotionManager.stopAccelerometerUpdates()
            cameraIsObservingDeviceOrientation = false
        }
    }
    
    private func addPreviewLayerToView(_ view: UIView) {
        embeddingView = view
        attachZoom(view)
        attachFocus(view)
        
        DispatchQueue.main.async { [weak self] in
            guard let previewLayer = self?.previewLayer else { return }
            previewLayer.frame = view.layer.bounds
            view.clipsToBounds = true
            view.layer.insertSublayer(previewLayer, below: nil)
            previewLayer.session?.startRunning()
        }
    }
    
    private func setupMaxZoomScale() {
        var maxZoom = CGFloat(1.0)
        beginZoomScale = CGFloat(1.0)
        
        if cameraDevice == .back, let backCameraDevice = backCameraDevice {
            maxZoom = backCameraDevice.activeFormat.videoMaxZoomFactor
        } else if cameraDevice == .front, let frontCameraDevice = frontCameraDevice {
            maxZoom = frontCameraDevice.activeFormat.videoMaxZoomFactor
        }
        
        maxZoomScale = maxZoom
    }
    
    private func setupOutputMode(_ newCameraOutputMode: CameraOutputMode,
                                 oldCameraOutputMode: CameraOutputMode?) {
        captureSession?.beginConfiguration()
        
        // remove current setting
        if let cameraOutputToRemove = oldCameraOutputMode {
            remove(cameraOutputToRemove)
        }
        
        // configure new devices
        configure(newCameraOutputMode)
        
        captureSession?.commitConfiguration()
        updateCameraQualityMode(cameraOutputQuality)
        orientationChanged()
    }
    private func remove( _ cameraOutputToRemove: CameraOutputMode) {
        switch cameraOutputToRemove {
        case .stillImage:
            if let validPhotoOutput = photoOutput {
                captureSession?.removeOutput(validPhotoOutput)
            }
        case .videoOnly, .videoWithMic:
            if let validMovieOutput = movieOutput {
                captureSession?.removeOutput(validMovieOutput)
            }
            if cameraOutputToRemove == .videoWithMic {
                removeMicInput()
            }
        case .rawData:
            if let validRawOutput = rawDataOutput {
                captureSession?.removeOutput(validRawOutput)
            }
        }
    }
    
    private func configure( _ newCameraOutputMode: CameraOutputMode) {
        switch newCameraOutputMode {
            
        case .stillImage:
            if photoOutput == nil {
                setupOutputs()
            }
            if let validPhotoOutput = photoOutput {
                if let captureSession = captureSession {
                    if captureSession.canAddOutput(validPhotoOutput) {
                        captureSession.addOutput(validPhotoOutput)
                    }
                }
            }
            
        case .videoOnly, .videoWithMic:
            
            let videoMovieOutput = fileMovieOutput
            if let captureSession = captureSession {
                if captureSession.canAddOutput(videoMovieOutput) {
                    captureSession.addOutput(videoMovieOutput)
                }
            }
            
            if newCameraOutputMode == .videoWithMic {
                if let validMic = deviceInput(from: mic) {
                    captureSession?.addInput(validMic)
                }
            }
            
        case .rawData:
            if rawDataOutput == nil {
                setupOutputs()
            }
            if let validRawOutput = rawDataOutput {
                if let captureSession = captureSession {
                    if captureSession.canAddOutput(validRawOutput) {
                        captureSession.addOutput(validRawOutput)
                    }
                }
            }
        }
    }
    
    private func setupOutputs() {
        if photoOutput == nil {
            photoOutput = AVCapturePhotoOutput()
        }
        if movieOutput == nil {
            movieOutput = AVCaptureMovieFileOutput()
            movieOutput?.movieFragmentInterval = CMTime.invalid
        }
        if library == nil {
            library = PHPhotoLibrary.shared()
        }
        if rawDataOutput == nil {
            rawDataOutput = AVCaptureVideoDataOutput()
            rawDataOutput?.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String:
                NSNumber(value: kCVPixelFormatType_32BGRA)]
            rawDataOutput?.alwaysDiscardsLateVideoFrames = true
            rawDataOutput?.setSampleBufferDelegate(self, queue: sessionQueue)
        }
    }
    
    private func setupPreviewLayer() {
        if let validCaptureSession = captureSession {
            previewLayer = AVCaptureVideoPreviewLayer(session: validCaptureSession)
            previewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
        }
    }
    
    /**
     Switches between the current and specified camera using a flip animation similar to the one used in the iOS stock camera app
     */
    
    private var cameraTransitionView: UIView?
    private var transitionAnimating = false
    
    func doFlipAnimation() {
        
        if transitionAnimating {
            return
        }
        
        if let validEmbeddingView = embeddingView {
            if let validPreviewLayer = previewLayer {
                
                var tempView = UIView()
                
                let blurEffect = UIBlurEffect(style: .light)
                tempView = UIVisualEffectView(effect: blurEffect)
                tempView.frame = validEmbeddingView.bounds
                
                validEmbeddingView.insertSubview(tempView, at: Int(validPreviewLayer.zPosition + 1))
                
                cameraTransitionView = validEmbeddingView.snapshotView(afterScreenUpdates: true)
                
                if let cameraTransitionView = cameraTransitionView {
                    validEmbeddingView.insertSubview(cameraTransitionView, at: Int(validEmbeddingView.layer.zPosition + 1))
                }
                tempView.removeFromSuperview()
                
                transitionAnimating = true
                
                validPreviewLayer.opacity = 0.0
                
                DispatchQueue.main.async { [weak self] in
                    self?.flipCameraTransitionView()
                }
            }
        }
    }
    
    private func flipCameraTransitionView() {
        
        if let cameraTransitionView = cameraTransitionView {
            
            UIView.transition(with: cameraTransitionView,
                              duration: 0.5,
                              options: UIView.AnimationOptions.transitionFlipFromLeft,
                              animations: nil,
                              completion: {[weak self] _ in
                                self?.removeCameraTransistionView()
            })
        }
    }
    
    private func removeCameraTransistionView() {
        
        if let cameraTransitionView = cameraTransitionView {
            if let validPreviewLayer = previewLayer {
                
                validPreviewLayer.opacity = 1.0
            }
            
            UIView.animate(withDuration: 0.5,
                           animations: { () -> Void in
                            
                            cameraTransitionView.alpha = 0.0
                            
            }, completion: { [weak self] finished in
                if !finished { return }
                self?.transitionAnimating = false
                cameraTransitionView.removeFromSuperview()
                self?.cameraTransitionView = nil
            })
        }
    }
    
    private func updateCameraDevice(_ deviceType: CameraDevice) {
        if let validCaptureSession = captureSession {
            validCaptureSession.beginConfiguration()
            defer { validCaptureSession.commitConfiguration() }
            let inputs: [AVCaptureInput] = validCaptureSession.inputs
            
            for input in inputs {
                if let deviceInput = input as? AVCaptureDeviceInput {
                    validCaptureSession.removeInput(deviceInput)
                }
            }
            
            switch cameraDevice {
            case .front:
                if hasFrontCamera {
                    if let validFrontDevice = deviceInput(from: frontCameraDevice) {
                        if !inputs.contains(validFrontDevice) {
                            validCaptureSession.addInput(validFrontDevice)
                        }
                    }
                }
            case .back:
                if let validBackDevice = deviceInput(from: backCameraDevice) {
                    if !inputs.contains(validBackDevice) {
                        validCaptureSession.addInput(validBackDevice)
                    }
                }
            }
        }
    }
    
    private func performShutterAnimation(_ completion: (() -> Void)?) {
        
        if let validPreviewLayer = previewLayer {
            
            DispatchQueue.main.async {
                
                let duration = 0.1
                
                CATransaction.begin()
                
                if let completion = completion {
                    
                    CATransaction.setCompletionBlock(completion)
                }
                
                let fadeOutAnimation = CABasicAnimation(keyPath: "opacity")
                fadeOutAnimation.fromValue = 1.0
                fadeOutAnimation.toValue = 0.0
                validPreviewLayer.add(fadeOutAnimation, forKey: "opacity")
                
                let fadeInAnimation = CABasicAnimation(keyPath: "opacity")
                fadeInAnimation.fromValue = 0.0
                fadeInAnimation.toValue = 1.0
                fadeInAnimation.beginTime = CACurrentMediaTime() + duration * 2.0
                validPreviewLayer.add(fadeInAnimation, forKey: "opacity")
                
                CATransaction.commit()
            }
        }
    }
    
    private func updateCameraQualityMode(_ newCameraOutputQuality: CameraOutputQuality) {
        if let validCaptureSession = captureSession {
            var sessionPreset = AVCaptureSession.Preset.low
            switch newCameraOutputQuality {
            case CameraOutputQuality.low:
                sessionPreset = AVCaptureSession.Preset.low
            case CameraOutputQuality.medium:
                sessionPreset = AVCaptureSession.Preset.medium
            case CameraOutputQuality.high:
                if cameraOutputMode == .stillImage {
                    sessionPreset = AVCaptureSession.Preset.photo
                } else {
                    sessionPreset = AVCaptureSession.Preset.high
                }
            }
            if validCaptureSession.canSetSessionPreset(sessionPreset) {
                validCaptureSession.beginConfiguration()
                validCaptureSession.sessionPreset = sessionPreset
                validCaptureSession.commitConfiguration()
            } else {
                _show(NSLocalizedString("Preset not supported", comment: ""),
                      message: NSLocalizedString("Camera preset not supported. Please try another one.",
                                                 comment: ""))
            }
        } else {
            _show(NSLocalizedString("Camera error", comment: ""),
                  message: NSLocalizedString("No valid capture session found, I can't take any pictures or videos.",
                                             comment: ""))
        }
    }
    
    private func removeMicInput() {
        guard let inputs = captureSession?.inputs else { return }
        
        for input in inputs {
            if let deviceInput = input as? AVCaptureDeviceInput {
                if deviceInput.device == mic {
                    captureSession?.removeInput(deviceInput)
                    break
                }
            }
        }
    }
    
    private func _show(_ title: String, message: String) {
        Logger.e("\(title): \(message)")
        //    if showErrorsToUsers {
        //      DispatchQueue.main.async(execute: { () -> Void in
        //        self.showErrorBlock(title, message)
        //      })
        //    }
    }
    
    private func deviceInput(from device: AVCaptureDevice?) -> AVCaptureDeviceInput? {
        guard let validDevice = device else { return nil }
        do {
            return try AVCaptureDeviceInput(device: validDevice)
        } catch let outError {
            _show(NSLocalizedString("Device setup error occured", comment: ""), message: "\(outError)")
            return nil
        }
    }
    
    deinit {
        Logger.d("Deinited")
        stopAndRemoveCaptureSession()
        stopFollowingDeviceOrientation()
    }
}
// MARK: - AVCapturePhotoCaptureDelegate extension
extension CameraManager: AVCapturePhotoCaptureDelegate {
    public func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            _show("Error", message: error.localizedDescription)
            imageCompletion?(nil, error as NSError?)
            return
        }
        guard let photoData = photo.fileDataRepresentation() else {
            _show("Error", message: "Can't extract data from captured phoo")
            imageCompletion?(nil, NSError())
            return
        }
        process(photoData)
    }
    
    private func process(_ imageData: Data) {
        guard let ciImage = CIImage(data: imageData) else { imageCompletion?(nil, NSError()); return }
        
        let image: UIImage
        if UIDevice.current.userInterfaceIdiom == .pad, cameraDevice == .front {
            
            switch _currentPreviewVideoOrientation() {
            case .landscapeLeft:
                image = UIImage(ciImage: ciImage, scale: 1.0, orientation: shouldFlipFrontCameraImage ? .upMirrored : .up)
            case .landscapeRight:
                image = UIImage(ciImage: ciImage, scale: 1.0, orientation: shouldFlipFrontCameraImage ? .downMirrored : .down)
            case .portraitUpsideDown:
                image = UIImage(ciImage: ciImage, scale: 1.0, orientation: shouldFlipFrontCameraImage ? .rightMirrored : .left)
            default:
                image = UIImage(ciImage: ciImage, scale: 1.0, orientation: shouldFlipFrontCameraImage ? .leftMirrored : .right)
            }
        } else if shouldFlipFrontCameraImage == true, cameraDevice == .front {
            let flippedImage = UIImage(ciImage: ciImage, scale: 1.0, orientation: .leftMirrored)
            image = flippedImage
        } else {
            let orientation = ciImage.properties["Orientation"] as? Int32
            image = UIImage(ciImage: ciImage.oriented(forExifOrientation: orientation.unsafelyUnwrapped))
        }
        
        if writeFilesToPhoneLibrary == true, let library = library {
            library.performChanges({ [weak self] in
                let request = PHAssetChangeRequest.creationRequestForAsset(from: image)
                request.creationDate = Date()
                
                if let location = self?.locationManager?.latestLocation {
                    request.location = location
                }
                }, completionHandler: { [weak self] _, error in
                    if let error = error {
                        DispatchQueue.main.async {
                            self?._show(NSLocalizedString("Error", comment: ""), message: error.localizedDescription)
                        }
                    }
            })
        }
        
        imageCompletion?(image, nil)
    }
}
// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate extension
extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let opaqueBuffer = Unmanaged<CVImageBuffer>.passUnretained(imageBuffer).toOpaque()
        let pixelBuffer = Unmanaged<CVPixelBuffer>.fromOpaque(opaqueBuffer).takeUnretainedValue()
        
        let sourceImage = CIImage(cvPixelBuffer: pixelBuffer, options: nil)
        
        guard let cgPropertyOrientation = CGImagePropertyOrientation
            .init(rawValue: UInt32(_currentPreviewVideoOrientation().rawValue)) else {
                Logger.e("Usupported orientation")
                return
        }
        captureRawCIImageFromCamera?(sourceImage, cgPropertyOrientation)
    }
}
