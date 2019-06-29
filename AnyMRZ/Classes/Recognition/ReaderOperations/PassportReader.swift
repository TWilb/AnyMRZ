//
//  PassportReader.swift
//  AnyMRZ
//
//  Created by Bohdan Mihiliev on 29.06.2019.
//  Copyright © 2019 Bohdan Mihiliev. All rights reserved.
//
import UIKit
/// Passport reader class
final class PassportReader: ReaderOperation {
  
  let rectDetectionOperation: RectDetectionOperation
  
  // MARK: - Initializers
  override init?(on inputImage: UIImage,
                 orientation: CGImagePropertyOrientation = .up,
                 delegate: RecognitionDelegate? = nil) {
    guard let rectDetectionOperation = PassportRectDetection(input: inputImage) else {
      return nil
    }
    self.rectDetectionOperation = rectDetectionOperation
    super.init(on: inputImage, orientation: orientation, delegate: delegate)
  }
  
  // MARK: - overrided methods
  override func main() {
    super.main()
    rectDetectionOperation.completionBlock = { [weak self] in
      guard let `self` =  self else {
        Logger.e("self is nil")
        return
      }      // Extracting rect detection operation results
      guard let detectedRectangleData = self.rectDetectionOperation.operationResult?.first else {
        let error = SDKError.emptyResultsIn("Rect Detection Operation", reason: nil)
        self.delegate?.recognitionDidFail(self, with: error)
        self.state = .finished
        return
      }
      
      // Initing MrzPassportDetectionOperation
      guard let mrzDetectionOperation = MrzPassportDetectionOperation(input: detectedRectangleData.image, objectsCountToDetect: passportMRZLinesCount) else {
        let error = SDKError.canNotCreate("MRZ Detection Operation", reason: nil)
        self.delegate?.recognitionDidFail(self, with: error)
        self.state = .finished
        return
      }
      
      // Creating final operation block
      let finishOperation = BlockOperation {
        
        // Checking results from mrzDetectionOperation
        guard let mrzOperationResults = mrzDetectionOperation.operationResult,
          !mrzOperationResults.isEmpty else {
            let error = SDKError.emptyResultsIn("MRZ detection operation", reason: nil)
            self.delegate?.recognitionDidFail(self, with: error)
            self.state = .finished
            return
        }
        // Processing results from operations
        let readerResults = mrzOperationResults + [detectedRectangleData]
        let recognizedData = RecognizedData(detectionResults: readerResults,
                                            originalImage: self.inputImage,
                                            recognizedimage: detectedRectangleData.image)
        
        DispatchQueue.main.async {
          self.delegate?.recognitionDidFinish(self, with: recognizedData)
        }
        self.state = .finished
      }
      
      // Adding operations and dependencies
      finishOperation.addDependency(mrzDetectionOperation)
      
      self.operationQueue.addOperations([mrzDetectionOperation,
                                          finishOperation], waitUntilFinished: false)
    }
    operationQueue.addOperation(rectDetectionOperation)
  }
  
  deinit {
    Logger.i("Deinited")
  }
}
