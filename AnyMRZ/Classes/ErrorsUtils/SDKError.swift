//
//  SDKError.swift
//  AnyMRZ
//
//  Created by Bohdan Mihiliev on 29.06.2019.
//  Copyright © 2019 Bohdan Mihiliev. All rights reserved.
//
public enum SDKError: Error {
  case emptyResultsIn(String, reason: String?)
  case canNotCreate(String, reason: String?)
  
  public var localizedDescription: String {
    switch self {
    case .emptyResultsIn(let destination, reason: let possibleReason):
      return "Empty results in \(destination), with: \(possibleReason ?? " ")"
    case .canNotCreate(let whoom, reason: let possibleReason):
      return "Can not craete \(whoom), with: \(possibleReason ?? " ")"
    }
  }
}
