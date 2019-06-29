//
//  UAEIDMRZDetectionOperation.swift
//  AnyMRZ
//
//  Created by Bohdan Mihiliev on 29.06.2019.
//  Copyright © 2019 Bohdan Mihiliev. All rights reserved.
//  swiftlint:disable cyclomatic_complexity function_body_length

final class MrzUAEIDDetectionOperation: MrzDetectionOperation {
  
  // MARK: - Properties
  override var mrzCharactersCount: Int {
    return 30
  }

  // MARK: - Public methods
  override func extractMRZText(from detectionResults: [DetectionResult]) -> [String] {
    tesseract.charWhitelist = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789<"
    tesseract.image = detectionResults[0].image
    tesseract.recognize()
    let firstLineText = tesseract.recognizedText
    
    tesseract.image = detectionResults[1].image
    tesseract.recognize()
    let secondLineText = tesseract.recognizedText
    
    tesseract.charWhitelist = "ABCDEFGHIJKLMNOPQRSTUVWXYZ<"
    tesseract.image = detectionResults[2].image
    tesseract.recognize()
    let thirdLineText = tesseract.recognizedText
    
    return [firstLineText, secondLineText, thirdLineText].compactMap { $0 }
  }
  
  override func extractMRZData(from mrzLines: [String]) -> [String: String]? {
    var mrzExtractedData = [String: String]()
    
    if mrzLines.count < uaeIDCardMRZLinesCount {
      Logger.e("MRZ should have 3 lines")
      return nil
    }
    
    let firstLine = String(mrzLines[0]).trimmingCharacters(in: .whitespacesAndNewlines)
    let secondLine = String(mrzLines[1]).trimmingCharacters(in: .whitespacesAndNewlines)
    let thirdLine = String(mrzLines[2]).trimmingCharacters(in: .whitespacesAndNewlines)
    
    mrzExtractedData["rawText"] = [firstLine, secondLine, thirdLine].joined(separator: "\n")
    
    if firstLine.count != secondLine.count || firstLine.count != thirdLine.count {
      Logger.e("MRZ lines should have same length")
      return nil
    }
    
    if firstLine.count != mrzCharactersCount {
      Logger.e("MRZ line should have 30 characters")
      return nil
    }
    
    if "IAC".index(of: firstLine[0]) == nil {
      Logger.e("MRZ first line should start with I, A or C")
      return nil
    }
    
    if countMRZCheckDigit(string: firstLine[5...13]) != Int(firstLine[14]) {
      Logger.e("MRZ wrong 6-14 check digit 15")
      return nil
    }
    
    if countMRZCheckDigit(string: firstLine[5...13]) != Int(firstLine[14]) {
      Logger.e("MRZ wrong 6-14 check digit 15")
      return nil
    }
    
    if countMRZCheckDigit(string: secondLine[0...5]) != Int(secondLine[6]) {
      Logger.e("MRZ wrong 1-6 check digit 7")
      return nil
    }
    
    if countMRZCheckDigit(string: secondLine[8...13]) != Int(secondLine[14]) {
      Logger.e("MRZ wrong 9-14 check digit 15")
      return nil
    }
    
    var checkString = firstLine[5...29] + secondLine[0...6]
    checkString += secondLine[8...14] + secondLine[18...28]
    if countMRZCheckDigit(string: checkString) != Int(secondLine[29]) {
      Logger.e("MRZ wrong 6–30 (upper line), 1–7, 9–15, 19–29 (middle line) check digit 30")
      return nil
    }
    
    if let countryName = countryCodes[firstLine[2...4].split(separator: "<").joined()] {
      mrzExtractedData["issuingCountryCode"] = firstLine[2...4].split(separator: "<").joined()
      mrzExtractedData["issuingCountryName"] = countryName
    } else {
      Logger.e("MRZ issuing country code not valid")
      return nil
    }
    
    mrzExtractedData["documentNumber"] = firstLine[5...13].split(separator: "<").joined()
    mrzExtractedData["firstRowOptional"] = firstLine[15...29]
    mrzExtractedData["secondRowOptional"] = secondLine[18...28]
    mrzExtractedData["dateOfBirth"] = secondLine[0...5].readableDate
    mrzExtractedData["dateOfExpiration"] = secondLine[8...13].readableDate
    mrzExtractedData["gender"] = secondLine[7]
    
    if let gender = mrzExtractedData["gender"], "MF<".index(of: gender) == nil {
      Logger.e("MRZ gender should be M, F of <")
      return nil
    }
    
    if let nationalityName = countryCodes[secondLine[15...17].split(separator: "<").joined()] {
      mrzExtractedData["nationalityCode"] = secondLine[15...17].split(separator: "<").joined()
      mrzExtractedData["nationalityName"] = nationalityName
    } else {
      Logger.e("MRZ nationality code not valid")
      return nil
    }
    
    let surnameEndIndex = thirdLine.index(of: "<<").unsafelyUnwrapped.encodedOffset - 1
    mrzExtractedData["lastName"] = thirdLine[0...surnameEndIndex]
    mrzExtractedData["givenName"] = thirdLine[surnameEndIndex + 1...29].split(separator: "<").joined(separator: " ")
    return mrzExtractedData
  }

}
