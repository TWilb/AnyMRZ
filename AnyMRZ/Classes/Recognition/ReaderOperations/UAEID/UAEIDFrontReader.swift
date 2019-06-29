//
//  UAEIDFrontReader.swift
//  AnyMRZ
//
//  Created by Bohdan Mihiliev on 29.06.2019.
//  Copyright © 2019 Bohdan Mihiliev. All rights reserved.
//
import UIKit

final class UAEIDFrontReader: ReaderOperation {
  
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
    scanFrontSide()
  }
  
  // MARK: - Private methdos
  private func scanFrontSide() {
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
      // Inting TextDetectionOperation
      guard let textDetectionOperation = TextDetectionOperation(input: detectedRectangleData.image) else {
        let error = SDKError.canNotCreate("Text Detection Operation", reason: nil)
        self.delegate?.recognitionDidFail(self, with: error)
        self.state = .finished
        return
      }
      textDetectionOperation.documentSegmentationParams = DocumentsSegmentationSettings.shared?.idCardFront
      
      var recognizedTextData = [RecognizedTextData]()

      // Creating final operation
      let finishOperation = BlockOperation {
        // Checking results from textDetectionOperation
        guard let textDetectionOperationResults = textDetectionOperation.operationResult,
          !textDetectionOperationResults.isEmpty else {
            let error = SDKError.emptyResultsIn("Text detection operation", reason: nil)
            self.delegate?.recognitionDidFail(self, with: error)
            self.state = .finished
            return
        }
        
        // Processing results from operations
        let recognizedTextData = recognizedTextData
          .map { DetectionResult(image: $0.imageBlock,
                                 rect: .zero, payLoad: ["translation": $0.content,
                                                        "additionalData": $0.additionalInfo ?? [:]]) }
        let readerResults = textDetectionOperationResults + recognizedTextData + [detectedRectangleData]
        
        let recognizedData = RecognizedData(detectionResults: readerResults,
                                            originalImage: self.inputImage,
                                            recognizedimage: detectedRectangleData.image)
        self.delegate?.willRecognizeNextPage(self, with: recognizedData)
        self.state = .finished
      }
            
      textDetectionOperation.documentSegmentationParams = DocumentsSegmentationSettings.shared?.idCardFront
      var textRecognitionOperations = [TextReaderOperation]()
      textDetectionOperation.completionBlock = {
        textDetectionOperation.operationResult?.enumerated().forEach { _, textDetectionResult in
          let operation = TextReaderOperation(for: "eng", from: textDetectionResult.image, additionalInfo: textDetectionResult.payLoad)
          operation.completionBlock = {
            guard let detectedText = operation.results else { return }
            DispatchQueue.main.async { recognizedTextData.append(detectedText) }
          }
          textRecognitionOperations.append(operation)
          finishOperation.addDependency(operation)
        }
        self.operationQueue.addOperations(textRecognitionOperations + [finishOperation], waitUntilFinished: false)
      }
      
      self.operationQueue.addOperations([textDetectionOperation], waitUntilFinished: false)
    }
    operationQueue.addOperation(rectDetectionOperation)
    
  }
}
