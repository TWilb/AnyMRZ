//
//  RectDetectionOperation.swift
//  AnyMRZ
//
//  Created by Bohdan Mihiliev on 29.06.2019.
//  Copyright © 2019 Bohdan Mihiliev. All rights reserved.
//
import Vision

protocol DocumentRectDemensions: class {
  /// Document width in millimeters
  var width: Float { get }
  /// Document height in millimeters
  var height: Float { get }
  /// Document aspect ratio
  var aspectRation: Float { get }
  /// Percent of deviation allowed
  var delta: Float { get }
}

class RectDetectionOperation: BaseDetectionProcessOperation<VNDetectRectanglesRequest> {
  
  // MARK: - Properties
  override var recognitionRequest: VNDetectRectanglesRequest {
    
    let detectRectRequest = VNDetectRectanglesRequest(completionHandler: self.recognitionHandler)
    
    detectRectRequest.preferBackgroundProcessing = false
    detectRectRequest.maximumObservations = self.objectsCountToDetect
    
    return detectRectRequest
  }
  
  // MARK: - BaseDetectionProcessOperation methods
  override func recognitionHandler(request: VNRequest, error: Error?) {
    if let error = error {
      Logger.e("\(error.localizedDescription)")
      return
    }
    
    guard let results = request.results as? [VNRectangleObservation] else {
      fatalError("Unexpected result type from VNDetectRectanglesRequest")
    }
    // Need check results only if objectsCountToDetect isn't default
    if objectsCountToDetect != defaultObjectsCount {
      guard results.count == objectsCountToDetect else {
        Logger.e("Wrong Rectangulars Results count: Founded - \(results.count) | Required - \(objectsCountToDetect)")
        return
      }
    }
    
    if isCancelled { return }
    
    self.operationResult = results.compactMap { detectedRectangle in
      let transform = CGAffineTransform.identity
        .scaledBy(x: inputImage.extent.width, y: inputImage.extent.height)
      
      let topLeft = detectedRectangle.topLeft.applying(transform)
      let topRight = detectedRectangle.topRight.applying(transform)
      let bottomLeft = detectedRectangle.bottomLeft.applying(transform)
      let bottomRight = detectedRectangle.bottomRight.applying(transform)
      
      var correctedImage = inputImage
        .applyingFilter("CIPerspectiveCorrection", parameters: [
          "inputTopLeft": CIVector(cgPoint: topLeft),
          "inputTopRight": CIVector(cgPoint: topRight),
          "inputBottomLeft": CIVector(cgPoint: bottomLeft),
          "inputBottomRight": CIVector(cgPoint: bottomRight)
          ])
      
     /* Detect image width to height ratio
      * Rotate right or down if need
      * Does not work with fliped document
      */
      if correctedImage.extent.width / correctedImage.extent.height < 1 {
        correctedImage = correctedImage.oriented(CGImagePropertyOrientation.right)
      }
      guard let cuttedImage = correctedImage.uiImage else {
        return nil
      }
      let boundingBox = detectedRectangle.boundingBox.applying(transform)
      return DetectionResult(image: cuttedImage, rect: boundingBox)
      
    }
  }
  
}
