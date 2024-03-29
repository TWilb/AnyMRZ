//
//  BaseDetectionProcessOperation.swift
//  AnyMRZ
//
//  Created by Bohdan Mihiliev on 29.06.2019.
//  Copyright © 2019 Bohdan Mihiliev. All rights reserved.
import Vision
import UIKit

// Base class for all detection operations.
class BaseDetectionProcessOperation<RequestType: VNRequest>: Operation {
  
  // MARK: - Properties
  final let inputImage: CIImage
  final let imageToProcess: UIImage
  final let vNImageRequestHandler: VNImageRequestHandler
  final let cGAffineTransform: CGAffineTransform
  final private (set) var objectsCountToDetect = defaultObjectsCount
  final var operationResult: [DetectionResult]?
  
  // MARK: - Computed variables
  var recognitionRequest: RequestType {
    return RequestType(completionHandler: self.recognitionHandler)
  }
  
  override var isConcurrent: Bool {
    return true
  }
  
  // MARK: - Initializers
  init?(input image: CIImage, objectsCountToDetect: Int = 0, orientation: CGImagePropertyOrientation = .up) {
    self.inputImage = image
    guard let inputUIImage = image.uiImage else { return nil }
    self.imageToProcess = inputUIImage
    self.cGAffineTransform = CGAffineTransform.identity
      .scaledBy(x: inputUIImage.size.width, y: -inputUIImage.size.height)
      .translatedBy(x: 0, y: -1)
    self.objectsCountToDetect = objectsCountToDetect
    self.vNImageRequestHandler = VNImageRequestHandler(ciImage: image, orientation: orientation)
  }
  
  convenience init?(input image: CGImage, objectsCountToDetect: Int = 0, orientation: CGImagePropertyOrientation = .up) {
    let image = CIImage(cgImage: image)
    self.init(input: image, objectsCountToDetect: objectsCountToDetect, orientation: orientation)
  }
  
  convenience init?(input image: UIImage, objectsCountToDetect: Int = 0, orientation: CGImagePropertyOrientation = .up) {
    guard let image = CIImage(image: image) ?? image.ciImage else { return nil }
    self.init(input: image, objectsCountToDetect: objectsCountToDetect, orientation: orientation)
  }
  
  // MARK: - Lifecycle events
  override func main() {
    super.main()
    if isCancelled { return }
    do {
      try vNImageRequestHandler.perform([recognitionRequest])
    } catch {
      Logger.e("Wrong Face Results count: \(error.localizedDescription)")
    }
  }
  
  // MARK: - Methods
  func recognitionHandler(request: VNRequest, error: Error?) { }

}
