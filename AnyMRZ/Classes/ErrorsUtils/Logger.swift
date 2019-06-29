//
//  Logger.swift
//  AnyMRZ
//
//  Created by Bohdan Mihiliev on 29.06.2019.
//  Copyright © 2019 Bohdan Mihiliev. All rights reserved.
//  swiftlint:disable function_parameter_count

import TesseractOCR

enum LoggerLevel: Int {
  case info = 1
  case debug
  case warning
  case error
  case none
  
  var name: String {
    switch self {
    case .info: return "I"
    case .debug: return "D"
    case .warning: return "W"
    case .error: return "E"
    case .none: return "N"
    }
  }
}

enum LoggerOutput: String {
  case debuggerConsole
  case deviceConsole
}

final class Logger {
  
  // MARK: - Properties
  static var tag: String?
  static var level: LoggerLevel = .info
  static var ouput: LoggerOutput = .debuggerConsole
  static var showThread: Bool = false
  
  private init() { }
  
  private static func log( _ level: LoggerLevel, message: String,
                           currentTime: Date, fileName: String,
                           functionName: String, lineNumber: Int, thread: Thread) {
    
    guard level.rawValue >= self.level.rawValue else { return }
    let fileNameToPrint = fileName.split(separator: "/")
    let text = "\(showThread ? thread.description : "")[\(fileNameToPrint.last ?? "?")#\(functionName)#\(lineNumber)]\(tag ?? "")-\(level.name): \(message)"
    if self.ouput == .deviceConsole {
      NSLog(text)
    } else {
      print("\(currentTime.iso8601) \(text)")
    }
  }
  
  static func tesseractVersion() {
    debugPrint("Tessercat version is \(String(describing: G8Tesseract.version))")
  }
  
  static func i(_ message: String, currentTime: Date = Date(),
                fileName: String = #file, functionName: String = #function,
                lineNumber: Int = #line, thread: Thread = Thread.current ) {
    log(.info, message: message, currentTime: currentTime, fileName: fileName,
        functionName: functionName, lineNumber: lineNumber, thread: thread)
  }
  
  static func d(_ message: String, currentTime: Date = Date(),
                fileName: String = #file, functionName: String = #function,
                lineNumber: Int = #line, thread: Thread = Thread.current ) {
    log(.debug, message: message, currentTime: currentTime, fileName: fileName,
        functionName: functionName, lineNumber: lineNumber, thread: thread)
  }
  
  static func w(_ message: String, currentTime: Date = Date(),
                fileName: String = #file, functionName: String = #function,
                lineNumber: Int = #line, thread: Thread = Thread.current ) {
    log(.warning, message: message, currentTime: currentTime, fileName: fileName,
        functionName: functionName, lineNumber: lineNumber, thread: thread)
  }
  
  static func e(_ message: String, currentTime: Date = Date(),
                fileName: String = #file, functionName: String = #function,
                lineNumber: Int = #line, thread: Thread = Thread.current ) {
    log(.error, message: message, currentTime: currentTime, fileName: fileName,
        functionName: functionName, lineNumber: lineNumber, thread: thread)
  }
}
