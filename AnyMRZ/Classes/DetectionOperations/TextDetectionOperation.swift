//
//  TextDetection.swift
//  AnyMRZ
//
//  Created by Bohdan Mihiliev on 29.06.2019.
//  Copyright © 2019 Bohdan Mihiliev. All rights reserved.
//
import Vision

final class TextDetectionOperation: BaseDetectionProcessOperation<VNDetectTextRectanglesRequest> {
  
  var documentSegmentationParams: DocumentSegmentationParams?
  
  // MARK: - BaseDetectionProcessOperation methods
  override func recognitionHandler(request: VNRequest, error: Error?) {
    if let error = error {
      Logger.e("\(error.localizedDescription)")
      return
    }
    
    guard let results = request.results as? [VNTextObservation] else {
      fatalError("Unexpected result type from VNTextObservation")
    }
    
    // Need check results only if objectsCountToDetect isn't default
    if objectsCountToDetect != defaultObjectsCount {
      guard results.count == objectsCountToDetect else {
        Logger.e("Wrong Texts Results count: Founded - \(results.count) | Required - \(objectsCountToDetect)")
        return
      }
    }
    
    if isCancelled { return }
    
    let processingImageWidth = Int(imageToProcess.size.width)
    let processingImageHeight = Int(imageToProcess.size.height)
    let documentSize = (width: Int(documentSegmentationParams?.resizeWidth ?? 0),
                        height: Int(documentSegmentationParams?.resizeHeight ?? 0))
    let detectedText = results
      .lazy
      .map { [unowned self] in $0.boundingBox.applying(self.cGAffineTransform) }
      .compactMap { [unowned self] rect -> DetectionResult? in
        // cropping image to needed text rect
        guard let detectedRectImage = self.imageToProcess
          .cgImage?
          .cropping(to: rect.extend(to: -0.1)) else { return nil }
        // if features exists filter by feture
        if let neededFields = self.documentSegmentationParams?.features {
          guard let featureIndex = neededFields
            .firstIndex(where: { rect.includes(x: (processingImageWidth * Int($0.location.cX))/documentSize.width,
                                          y: (processingImageHeight * Int($0.location.cY))/documentSize.height) })
            else { return nil }
          let relatedFeature = neededFields[featureIndex]
          return DetectionResult(image: UIImage(cgImage: detectedRectImage),
                                 rect: rect, payLoad: ["relatedFeature": relatedFeature])
        } else {
          return DetectionResult(image: UIImage(cgImage: detectedRectImage),
                                 rect: rect)
        }
    }
    
    if let neededFeatures = self.documentSegmentationParams?.features,
      detectedText.count != neededFeatures.count {
      return
    }
    
    operationResult = Array(detectedText)
  }
}
