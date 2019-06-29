//
//  DocumentSegmentationProperties.swift
//  AnyMRZ
//
//  Created by Bohdan Mihiliev on 29.06.2019.
//  Copyright © 2019 Bohdan Mihiliev. All rights reserved.
//  swiftlint:disable identifier_name nesting

public struct DocumentSegmentationParams: Decodable {
  
  let resizeWidth: UInt32
  let resizeHeight: UInt32
  let kernelWidth: UInt32
  let kernelHeight: UInt32
  
  public struct Feature: Decodable {
    let title: String
    
    struct Location: Decodable {
      let cX: UInt32
      let cY: UInt32
    }
    
    let location: Location
    
  }
  
  let features: [Feature]
}
