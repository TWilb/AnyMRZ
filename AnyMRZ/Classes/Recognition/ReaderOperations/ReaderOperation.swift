//
//  SDKDocumentReaderOperation.swift
//  AnyMRZ
//
//  Created by Bohdan Mihiliev on 29.06.2019.
//  Copyright © 2019 Bohdan Mihiliev. All rights reserved.
//
import UIKit

/// Main Reader class specialized on document reading
class ReaderOperation: AsyncOperation {
  
  // MARK: - Properties
  final let inputImage: UIImage
  final let orientation: CGImagePropertyOrientation
  final let operationQueue: OperationQueue
  final weak var delegate: RecognitionDelegate?
  
  // MARK: - Initializers
  init?(on inputImage: UIImage,
        orientation: CGImagePropertyOrientation = .up,
        delegate: RecognitionDelegate? = nil) {
    self.operationQueue = OperationQueue()
    self.inputImage = inputImage
    self.orientation = orientation
    self.delegate = delegate
  }
  
  // MARK: - Operation overrided methods
  override func main() {
    super.main()
    if isCancelled { return }
    delegate?.recognitionDidBegin(self)
  }
}
