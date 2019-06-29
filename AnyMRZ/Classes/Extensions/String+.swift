//
//  String+.swift
//  AnyMRZ
//
//  Created by Bohdan Mihiliev on 29.06.2019.
//  Copyright © 2019 Bohdan Mihiliev. All rights reserved.
//
import Foundation

extension String {
  
  // MARK: - Properties
  var dateFromISO8601: Date? {
    return Formatter.iso8601.date(from: self)   // "Mar 22, 2017, 10:22 AM"
  }
  
  var readableDate: String? {
//    DateFormatter.formatter.dateFormat =  "yyMMdd"
//    let date = DateFormatter.formatter.date(from: self)
//    DateFormatter.formatter.dateFormat = "dd/MM/yyyy"
//    if let date = date {
//      return DateFormatter.formatter.string(from: date)
//    }
    if let date = self.dateFromISO8601 {
      return Formatter.iso8601.string(from: date)
    }
    return nil
  }
  
  var length: Int {
    return self.count
  }
  
  subscript(index: Int) -> String {
    return self[index..<index + 1]
  }
  
  subscript(range: Range<Int>) -> String {
    let range = Range(uncheckedBounds: (lower: max(0, min(length, range.lowerBound)),
                                        upper: min(length, max(0, range.upperBound))))
    let start = index(startIndex, offsetBy: range.lowerBound)
    let end = index(start, offsetBy: range.upperBound - range.lowerBound)
    return String(self[start..<end])
  }
  
  subscript (bounds: CountableClosedRange<Int>) -> String {
    let start = index(startIndex, offsetBy: bounds.lowerBound)
    let end = index(startIndex, offsetBy: bounds.upperBound)
    return String(self[start...end])
  }

  func substring(fromIndex: Int) -> String {
    return self[min(fromIndex, length)..<length]
  }
  
  func substring(toIndex: Int) -> String {
    return self[0..<max(0, toIndex)]
  }
  
  func index(of string: String, options: CompareOptions = .literal) -> Index? {
    return range(of: string, options: options)?.lowerBound
  }
  
  func endIndex(of string: String, options: CompareOptions = .literal) -> Index? {
    return range(of: string, options: options)?.upperBound
  }
  
  func indexes(of string: String, options: CompareOptions = .literal) -> [Index] {
    var result: [Index] = []
    var start = startIndex
    while let range = range(of: string, options: options, range: start..<endIndex) {
      result.append(range.lowerBound)
      start = range.lowerBound < range.upperBound ? range.upperBound : index(range.lowerBound, offsetBy: 1, limitedBy: endIndex) ?? endIndex
    }
    return result
  }
  
  func ranges(of string: String, options: CompareOptions = .literal) -> [Range<Index>] {
    var result: [Range<Index>] = []
    var start = startIndex
    while let range = range(of: string, options: options, range: start..<endIndex) {
      result.append(range)
      start = range.lowerBound < range.upperBound ? range.upperBound : index(range.lowerBound, offsetBy: 1, limitedBy: endIndex) ?? endIndex
    }
    return result
  }
  
  func replace(target: String, withString: String) -> String {
    return self.replacingOccurrences(of: target, with: withString, options: NSString.CompareOptions.literal, range: nil)
  }
  
//  func regExReplace(pattern: String, with replaceString: String = "") -> String? {
//    do {
//      let regex = try NSRegularExpression(pattern: pattern, options: NSRegularExpression.Options.caseInsensitive)
//      let range = NSMakeRange(0, self.count)
//      return regex.stringByReplacingMatches(in: self, options: [], range: range, withTemplate: replaceString)
//    } catch {
//      return nil
//    }
//  }

}
