//
//  MRZDetectionOperation.swift
//  AnyMRZ
//
//  Created by Bohdan Mihiliev on 29.06.2019.
//  Copyright © 2019 Bohdan Mihiliev. All rights reserved.

import TesseractOCR
import Vision

protocol MRZDecoder {
  var mrzCharactersCount: Int { get }
  
  func extractMRZText(from detectionResults: [DetectionResult]) -> [String]
  func extractMRZData(from mrzLines: [String]) -> [String: String]?
}

class MrzDetectionOperation: BaseDetectionProcessOperation<VNDetectTextRectanglesRequest>, MRZDecoder {
  
  // MARK: - Properties
  var mrzCharactersCount: Int {
    return 0
  }
  lazy var tesseract: G8Tesseract = {
    guard let tesseract = G8Tesseract(language: "ocrb", configDictionary: [:],
                                      configFileNames: [], absoluteDataPath: Bundle(for: MrzDetectionOperation.self).bundlePath,
                                      engineMode: .tesseractOnly)
      else {
        fatalError("Can't instantiate tesseract in MRZ")
    }
    tesseract.pageSegmentationMode = .singleLine
    
    return tesseract
  }()
  
  // MARK: - BaseDetectionProcessOperation methods
  override func recognitionHandler(request: VNRequest, error: Error?) {
    if let error = error {
      print(error.localizedDescription)
    }
    guard let results = request.results as? [VNTextObservation] else {
      fatalError("Unexpected result type from VNDetectRectanglesRequest")
    }
    
    let rectangles = results
      .lazy
      .map { [unowned self] in $0.boundingBox.applying(self.cGAffineTransform).extend(by: -10) }
      .filter { [unowned self] (rect: CGRect) -> Bool in
        return rect.width > self.imageToProcess.size.width * 0.80 &&  // Filter lines that take at least 80% of document width
          rect.origin.y > self.imageToProcess.size.height * 0.5  // Filter lines that are in the bottom part of document
      }.sorted(by: { $1.origin.y > $0.origin.y }) // Order from top to bottom
    
    if rectangles.count != objectsCountToDetect { return }
    
    let mrzLines = rectangles.compactMap { rect -> DetectionResult? in
      guard let croppedImage = imageToProcess.transformedForMRZ.crop(to: rect) else { return nil }
      return DetectionResult(image: croppedImage, rect: rect)
    }
    
    let maxLineWidth = rectangles.map { $0.width }.max().unsafelyUnwrapped
    let firstLineRectangle = rectangles.first.unsafelyUnwrapped
    let lastLineRectangle = rectangles.last.unsafelyUnwrapped
    
    let mrzFullRect = CGRect(
      x: firstLineRectangle.origin.x,
      y: firstLineRectangle.origin.y,
      width: maxLineWidth,
      height: lastLineRectangle.origin.y + lastLineRectangle.height - firstLineRectangle.origin.y)
    
    guard let croppedMainImage = imageToProcess.transformedForMRZ.crop(to: mrzFullRect) else {
      Logger.e("Can not crop passed image to founded rect")
      return
    }
    guard let mrzExtractedData = extractMRZData(from: extractMRZText(from: mrzLines)) else {
      Logger.e("Can not extract mrz data")
      return
    }
    
    let fullMRZDetectionResult = DetectionResult(image: croppedMainImage,
                                                 rect: mrzFullRect,
                                                 payLoad: ["mrzLines": mrzLines,
                                                           "decodedData": mrzExtractedData])
    
    operationResult = [fullMRZDetectionResult]
  }
  
  // MARK: - Public methods
  func countMRZCheckDigit(string: String) -> Int {
    let weightPattern = "731"
    var sum = 0
    for index in 0...string.count - 1 {
      let character = string[index]
      let weight = Int(weightPattern[index % weightPattern.count]).unsafelyUnwrapped
      let value = Int(character, radix: 36) ?? 0
      sum = (sum + weight * value) % 10
    }
    return sum
  }
  
  func extractMRZText(from detectionResults: [DetectionResult]) -> [String] { return [] }
  func extractMRZData(from mrzLines: [String]) -> [String: String]? { return nil }
}
