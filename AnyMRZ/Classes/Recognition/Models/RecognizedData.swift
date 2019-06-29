//
//  RecognizedData.swift
//  AnyMRZ
//
//  Created by Bohdan Mihiliev on 29.06.2019.
//  Copyright © 2019 Bohdan Mihiliev. All rights reserved.
//
import UIKit
/**
 This struct stends for storing all recognized & detected data from processes.
 */
public struct RecognizedData {
  /// The data from detection operation.
  public let detectionResults: [DetectionResult]
  
  /// The original image that was sent to classifier.
  public let originalImage: UIImage?
  
  /// The recognized image.
  public let recognizedimage: UIImage?
}
