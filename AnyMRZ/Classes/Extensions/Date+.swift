//
//  Date+.swift
//  AnyMRZ
//
//  Created by Bohdan Mihiliev on 29.06.2019.
//  Copyright © 2019 Bohdan Mihiliev. All rights reserved.
//
import Foundation
extension Date {
  var millisecondsSince1970: Int {
    return Int((self.timeIntervalSince1970 * 1000.0).rounded())
  }
  
  var secondsSince1970: Int {
    return Int((self.timeIntervalSince1970).rounded())
  }
  
  init(milliseconds: Int) {
    self = Date(timeIntervalSince1970: TimeInterval(milliseconds / 1000))
  }
  
  func getCurrentTimeString(_ format: String = "yyyy-MM-dd HH:mm:ss") -> String {
    let nowDate = Date()
    let formatter = DateFormatter()
    formatter.dateFormat = format
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = Foundation.TimeZone(identifier: "UTC")
    return formatter.string(from: nowDate)
  }
  
  var iso8601: String {
    return Formatter.iso8601.string(from: self)
  }
}
