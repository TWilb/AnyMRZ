//
//  MrzPassportDetectionOperation.swift
//  AnyMRZ
//
//  Created by Bohdan Mihiliev on 29.06.2019.
//  Copyright © 2019 Bohdan Mihiliev. All rights reserved.
//  swiftlint:disable function_body_length cyclomatic_complexity

final class MrzPassportDetectionOperation: MrzDetectionOperation {
  
  // MARK: - Properties
  override var mrzCharactersCount: Int {
    return 44
  }
  
  // MARK: - Public methods
  override func extractMRZText(from detectionResults: [DetectionResult]) -> [String] {
    tesseract.charWhitelist = "ABCDEFGHIJKLMNOPQRSTUVWXYZ<"
    tesseract.image = detectionResults[0].image
    tesseract.recognize()
    let firstLineText = tesseract.recognizedText
    
    tesseract.charWhitelist = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789<"
    tesseract.image = detectionResults[1].image
    tesseract.recognize()
    let secondLineText = tesseract.recognizedText
    
    return [firstLineText, secondLineText].compactMap { $0 }
  }
  
  override func extractMRZData(from mrzLines: [String]) -> [String: String]? {
    var mrzExtractedData = [String: String]()
    
    if mrzLines.count < passportMRZLinesCount {
      Logger.e("MRZ should have 2 lines")
      return nil
    }
    
    let firstLine = String(mrzLines[0]).trimmingCharacters(in: .whitespacesAndNewlines)
    let secondLine = String(mrzLines[1]).trimmingCharacters(in: .whitespacesAndNewlines)
    
    mrzExtractedData["rawText"] = [firstLine, secondLine].joined(separator: "\n")
    
    if firstLine.count != secondLine.count {
      Logger.e("MRZ lines should have same length")
      return nil
    }
    
    if firstLine.count != mrzCharactersCount {
      Logger.e("MRZ line should have 44 characters")
      return nil
    }
    
    if firstLine[0] != "P" {
      Logger.e("MRZ first line should start with 'P'")
      return nil
    }
    
    if let countryName = countryCodes[firstLine[2...4].split(separator: "<").joined()] {
      mrzExtractedData["countryCode"] = firstLine[2...4].split(separator: "<").joined()
      mrzExtractedData["countryName"] = countryName
    } else {
      Logger.e("MRZ country code not valid")
      return nil
    }
    
    let surnameEndIndex = firstLine[5...43].index(of: "<<").unsafelyUnwrapped.encodedOffset + 4
    
    mrzExtractedData["lastName"] = firstLine[5...surnameEndIndex]
    mrzExtractedData["givenName"] = firstLine[surnameEndIndex + 1...43].split(separator: "<").joined(separator: " ")
    
    if countMRZCheckDigit(string: secondLine[0...8]) != Int(secondLine[9]) {
      Logger.e("MRZ wrong 1-9 check digit 10")
      return nil
    }
    
    if countMRZCheckDigit(string: secondLine[13...18]) != Int(secondLine[19]) {
      Logger.e("MRZ wrong 14-19 check digit 20")
      return nil
    }
    
    if countMRZCheckDigit(string: secondLine[21...26]) != Int(secondLine[27]) {
      Logger.e("MRZ wrong 22–27 check digit 28")
      return nil
    }
    
    if countMRZCheckDigit(string: secondLine[28...41]) != Int(secondLine[42]) && secondLine[42] != "<" {
      Logger.e("MRZ wrong 29–42 check digit 43")
      return nil
    }
    
    if countMRZCheckDigit(string: secondLine[0...9] + secondLine[13...19] + secondLine[21...42]) != Int(secondLine[43]) {
      Logger.e("MRZ wrong 1–10, 14–20, 22–43 check digit 44")
      return nil
    }
    
    mrzExtractedData["passportNumber"] = secondLine[0...8].split(separator: "<").joined()
    
    if let nationalityName = countryCodes[secondLine[10...12].split(separator: "<").joined()] {
      mrzExtractedData["nationalityCode"] = secondLine[10...12].split(separator: "<").joined()
      mrzExtractedData["nationalityName"] = nationalityName
    } else {
      Logger.e("MRZ nationality code not valid")
      return nil
    }
    mrzExtractedData["dateOfBirth"] = secondLine[13...18].readableDate
    
    mrzExtractedData["gender"] = secondLine[20]
    if let genderValue = mrzExtractedData["gender"], "MF<".index(of: genderValue) == nil {
      Logger.e("MRZ gender should be M, F of <")
      return nil
    }
    
    mrzExtractedData["dateOfExpiration"] = secondLine[21...26].readableDate
    
    return mrzExtractedData
  }
}
