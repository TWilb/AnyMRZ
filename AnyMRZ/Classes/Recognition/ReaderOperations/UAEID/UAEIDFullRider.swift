//
//  UAEIDFullRider.swift
//  AnyMRZ
//
//  Created by Bohdan Mihiliev on 29.06.2019.
//  Copyright © 2019 Bohdan Mihiliev. All rights reserved.
//
import UIKit

final class UAEIDFullRider: ReaderOperation {
  
  // MARK: - Properties
  private let frontReader: UAEIDFrontReader
  private var frontIdNumber = ""
  var backReader: UAEIDBackReader?
  var backSideImage: UIImage? {
    didSet {
      guard let image = backSideImage,
        operationQueue.operations.isEmpty
        else { return }
      self.backReader = UAEIDBackReader(on: image, orientation: .up, delegate: self)
      if backReader != nil {
        operationQueue.addOperation(backReader.unsafelyUnwrapped)
      }
    }
  }
  
  // MARK: - Initializers
  override init?(on inputImage: UIImage,
                 orientation: CGImagePropertyOrientation = .up,
                 delegate: RecognitionDelegate? = nil) {
     guard let frontReader = UAEIDFrontReader(on: inputImage,
                                   orientation: orientation,
                                   delegate: nil) else {
                                    Logger.e("UAEIDFrontReader is nil")
                                    return nil
    }
    self.frontReader = frontReader
    super.init(on: inputImage, orientation: orientation, delegate: delegate)
    self.frontReader.delegate = self
  }
  
  // MARK: - overrided methods
  override func main() {
    super.main()
    operationQueue.addOperation(frontReader)
  }

}
extension UAEIDFullRider: RecognitionDelegate {
  func willRecognizeNextPage(_ sender: ReaderOperation, with currentPageData: RecognizedData) {
    self.delegate?.willRecognizeNextPage(sender, with: currentPageData)
  }
  
  func recognitionDidBegin(_ sender: ReaderOperation) {
    self.delegate?.recognitionDidBegin(sender)
  }
  
  func recognitionDidFinish(_ sender: ReaderOperation, with data: RecognizedData) {
    self.delegate?.recognitionDidFinish(sender, with: data)
    self.state = .finished
  }
  
  func recognitionDidFail(_ sender: ReaderOperation, with error: SDKError) {
    self.delegate?.recognitionDidFail(sender, with: error)
    if backReader == nil {
      self.state = .finished
    }
  }
  
}
