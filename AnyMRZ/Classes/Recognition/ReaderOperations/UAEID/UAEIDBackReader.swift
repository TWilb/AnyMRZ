//
//  UAEIDBackReader.swift
//  AnyMRZ
//
//  Created by Bohdan Mihiliev on 29.06.2019.
//  Copyright © 2019 Bohdan Mihiliev. All rights reserved.
//
import UIKit

final class UAEIDBackReader: ReaderOperation {
  
  // MARK: - Properties
  let rectDetectionOperation: RectDetectionOperation
  private var frontIdNumber = ""
  
  // MARK: - Initializers
  override init?(on inputImage: UIImage,
                 orientation: CGImagePropertyOrientation = .up,
                 delegate: RecognitionDelegate? = nil) {
    guard let rectDetectionOperation = UAEIDRectDetection(input: inputImage) else {
      return nil
    }
    self.rectDetectionOperation = rectDetectionOperation
    super.init(on: inputImage, orientation: orientation, delegate: delegate)
  }
  
  // MARK: - overrided methods
  override func main() {
    super.main()
    scanBackSide()
  }
  
  // MARK: - Private methdos
  private func scanBackSide() {
    rectDetectionOperation.completionBlock = { [weak self] in
      guard let `self` =  self else {
        Logger.e("self is nil")
        return
      }
      // Extracting rect detectio operation results
      guard let detectedRectangleData = self.rectDetectionOperation.operationResult?.first else {
        let error = SDKError.emptyResultsIn("Rect Detection Operation", reason: nil)
        self.delegate?.recognitionDidFail(self, with: error)
        self.state = .finished
        return
      }
      
      
      // Initing MrzPassportDetectionOperation
      guard let mrzDetectionOperation =
        MrzUAEIDDetectionOperation(input: detectedRectangleData.image,
                                      objectsCountToDetect: uaeIDCardMRZLinesCount) else {
                                        let error = SDKError.canNotCreate("MRZ Detection Operation", reason: nil)
                                        self.delegate?.recognitionDidFail(self, with: error)
                                        self.state = .finished
                                        return
      }
      
      // Creating final operation
      let finishOperation = BlockOperation {
        // Checking results from mrzDetectionOperation
        guard let mrzOperationResults = mrzDetectionOperation.operationResult,
          !mrzOperationResults.isEmpty else {
            let error = SDKError.emptyResultsIn("MRZ Detection operation", reason: nil)
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
      
      finishOperation.addDependency(mrzDetectionOperation)
      
      self.operationQueue.addOperations([mrzDetectionOperation,
                                          finishOperation],
                                         waitUntilFinished: false)
    }
    operationQueue.addOperation(rectDetectionOperation)
    
  }
}
