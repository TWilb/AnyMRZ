//
//  BarCodeDetectionOperation.swift
//  AnyMRZ
//
//  Created by Bohdan Mihiliev on 29.06.2019.
//  Copyright © 2019 Bohdan Mihiliev. All rights reserved.
//
import Vision

final class BarCodeDetectionOperation: BaseDetectionProcessOperation<VNDetectBarcodesRequest> {
  
  // MARK: - BaseDetectionProcessOperation methods
  override func recognitionHandler(request: VNRequest, error: Error?) {
    if let error = error {
      Logger.e("\(error.localizedDescription)")
      return
    }
    
    guard let results = request.results as? [VNBarcodeObservation] else {
      fatalError("Unexpected result type from VNDetectBarcodesRequest")
    }
    
    // Need check results only if objectsCountToDetect isn't default
    if objectsCountToDetect != defaultObjectsCount {
      guard results.count == objectsCountToDetect else {
        Logger.e("Wrong BarCode Results count: Founded - \(results.count) | Required - \(objectsCountToDetect)")
        return
      }
    }
    
    var detectionResults = [DetectionResult]()
    results.forEach {
      let rect = $0.boundingBox.applying(cGAffineTransform)
      guard let detectedBarCodeImage = imageToProcess.crop(to: rect) else {
        Logger.e("Can not crop to detectedBarCodeImage")
        return
      }
      var payLoad: [String: Any]?
      if let barCodeString = $0.payloadStringValue {
        payLoad = [barCodeStringPayLoadKey: barCodeString]
      }
      detectionResults.append(DetectionResult(image: detectedBarCodeImage,
                                              rect: rect,
                                              payLoad: payLoad))
    }
    if isCancelled { return }
    operationResult = detectionResults
  }
}
