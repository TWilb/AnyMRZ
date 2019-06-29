//
//  CameraViewController.swift
//  AnyMRZ
//
//  Created by Bohdan Mihiliev on 29.06.2019.
//  Copyright © 2019 Bohdan Mihiliev. All rights reserved.
//
import TesseractOCR
import UIKit

open class CameraViewController: UIViewController, RecognitionDelegate {
    
    // MARK: - Outlets
    @IBOutlet weak var cameraButton: UIButton!
    
    // MARK: - Properties
    private let cameraManager = CameraManager()
    private var reader: ReaderOperation?
    private var shouldStopReaders = false
    private var isNextPage = false
    public weak var delegate: ScanControollerDelegate?
    
    // MARK: - Computed variables
    open var documentType: DocumentType {
        return .selfie
    }
    open var mode: CameraOutputMode {
        return .rawData
    }
    
    // MARK: - Lifecycle events
    override open func viewDidLoad() {
        super.viewDidLoad()
        
        prepareCameraManager()
        
        prepareImageComplition()
        
        prepareRawDataComplition()
        
        handleCameraState()
    }
    
    override open func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        cameraManager.resumeCaptureSession()
    }
    
    override open func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        cameraManager.stopCaptureSession()
    }
    
    deinit {
        Logger.d("Deinited")
    }
    
    // MARK: - Open methods
    open func handleCameraState() {
        switch cameraManager.currentCameraState {
        case .accessDenied:
            Logger.e("Camera access denied")
        case .noDeviceFound:
            Logger.e("There are any camera devices")
        case .notDetermined:
            Logger.e("State does not determined")
        case .ready:
            cameraManager.addPreviewLayerToView(view)
        }
    }
    open func changeCamera() {
        cameraManager.cameraDevice = cameraManager.cameraDevice == CameraDevice.front ? CameraDevice.back : CameraDevice.front
    }
    // MARK: - RecognitionDelegate
    func recognitionDidFinish(_ sender: ReaderOperation, with data: RecognizedData) {
        shouldStopReaders = true
        isNextPage = false
        delegate?.recognitionDidFinish(self, with: data)
    }
    
    func recognitionDidFail(_ sender: ReaderOperation, with error: SDKError) {
        shouldStopReaders = false
        delegate?.recognitionDidFail(self, with: error)
    }
    
    func recognitionDidBegin(_ sender: ReaderOperation) {
        shouldStopReaders = false
        delegate?.recognitionDidBegin(self)
    }
    
    func willRecognizeNextPage(_ sender: ReaderOperation, with currentPageData: RecognizedData) {
        //    shouldStopReaders = true
        isNextPage = true
        delegate?.willRecognizeNextPage(self, with: currentPageData)
    }
    
    // MARK: - Actions
    @IBAction func recordButtonTapped(_ sender: UIButton) {
        
        switch cameraManager.cameraOutputMode {
        case .stillImage:
            cameraManager.capturePicture()
        case .videoWithMic, .videoOnly:
            if sender.isSelected {
                cameraManager.startRecordingVideo()
            } else {
                cameraManager.stopVideoRecording { (videoURL, error) -> Void in
                    Logger.i(videoURL?.absoluteString ?? "")
                    if let errorOccured = error {
                        Logger.e(errorOccured.localizedDescription)
                    }
                }
            }
        default:
            return
        }
    }
    
    // MARK: - Private methods
    private func prepareCameraManager() {
        cameraManager.cameraDevice = .back
        cameraManager.cameraOutputMode = mode
    }
    
    private func prepareImageComplition() {
        cameraManager.imageCompletion = { [weak self] photo, error in
            guard let `self` =  self else {
                Logger.e("self is nil")
                return
            }
            if let error = error?.localizedDescription {
                Logger.e(error)
                return
            }
            guard let image = photo else {
                Logger.e("Captured photo is missing")
                return
            }
            switch self.documentType {
            case .selfie:
                break
            case .passport:
                self.reader = PassportReader(on: image)
            case .visa:
                break
            case .dewaBill:
                break
            default:
                Logger.e("This type - \(self.documentType) does not support raw capturing")
            }
            self.reader?.delegate = self
            DispatchQueue.global(qos: .background).async {
                self.reader?.start()
            }
        }
    }
    
    private func prepareRawDataComplition() {
        cameraManager.captureRawCIImageFromCamera = { [weak self]  image, orientation in
            guard let `self` =  self else {
                Logger.e("self is nil")
                return
            }
            if !self.isAbleToStartRecognition() { return }
            switch self.documentType {
            case .emiratesID:
                if self.isNextPage {
                    (self.reader as? UAEIDFullRider)?.backSideImage = UIImage(ciImage: image)
                } else {
                    self.reader = UAEIDFullRider(on: UIImage(ciImage: image))
                }
            case .passport:
                self.reader = PassportReader(on: UIImage(ciImage: image))
            case .visa:
                break
            default:
                Logger.e("This type - \(self.documentType) does not support raw capturing")
            }
            
            self.reader?.delegate = self
            if self.isNextPage { return }
            DispatchQueue.global(qos: .background).async {
                self.reader?.start()
            }
        }
    }
    private func isAbleToStartRecognition() -> Bool {
        if let reader = self.reader {
            if reader.isCancelled {
                reader.operationQueue.cancelAllOperations()
            } else if !reader.isFinished && !self.isNextPage {
                return false
            }
        }
        if self.shouldStopReaders { return false }
        return true
    }
}
