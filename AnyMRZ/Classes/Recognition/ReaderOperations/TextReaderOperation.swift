//
//  TextReaderOperation.swift
//  AnyMRZ
//
//  Created by Bohdan Mihiliev on 29.06.2019.
//  Copyright © 2019 Bohdan Mihiliev. All rights reserved.
//

import TesseractOCR
import UIKit

final class TextReaderOperation: Operation {
  
  // MARK: - Properties
  var results: RecognizedTextData?
  private let textImage: UIImage
  private let language: String
  private let additionalInfo: [String: Any]?
  private let whiteList: String?
  private let blackList: String?

  // MARK: - Initializers
  init(for language: String,
       from image: UIImage,
       additionalInfo: [String: Any]? = nil,
       whiteList: String? = nil,
       blackList: String? = nil) {
    self.textImage = image
    self.additionalInfo = additionalInfo
    self.language = language
    self.whiteList = whiteList
    self.blackList = blackList
  }
  
  // MARK: - Operation methods
  override func main() {
    super.main()
    let tesseract = loadTesseract()
    if isCancelled { return }
    if !tesseract.recognize() {
      Logger.e("Tesseract can not finish recognition")
      return
    }
    guard let recognizedText = tesseract.recognizedText else {
      Logger.e("Tesseract failed on recognizedText operation")
      return
    }
    results = RecognizedTextData(imageBlock: textImage,
                                 content: recognizedText,
                                 additionalInfo: additionalInfo)
  }
  
  private func loadTesseract() -> G8Tesseract {
    guard let tesseract = G8Tesseract(language: language, configDictionary: [:],
                                      configFileNames: [], absoluteDataPath: Bundle(for: TextReaderOperation.self).bundlePath,
                                      engineMode: .cubeOnly)
      else {
        fatalError("Can't instantiate tesseract in MRZ")
    }
    tesseract.pageSegmentationMode = .singleLine
    tesseract.image = textImage
    if let whiteList = whiteList {
      tesseract.charWhitelist = whiteList
    }
    if let blackList = blackList {
      tesseract.charBlacklist = blackList
    }
    return tesseract
  }
}
