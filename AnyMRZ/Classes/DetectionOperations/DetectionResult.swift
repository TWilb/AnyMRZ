//
//  TestableMethods.swift
//  AnyMRZ
//
//  Created by Bohdan Mihiliev on 29.06.2019.
//  Copyright © 2019 Bohdan Mihiliev. All rights reserved.
//
import UIKit
/**
 This struct stends for storing detection operations results.
 */
public struct DetectionResult {
  
  // MARK: - Properties
  
  /// The detected object image.
  public let image: UIImage
  /// The detected object rectangle.
  public let rect: CGRect
  /// Additionnal information provided by operation.
  public let payLoad: [String: Any]?
  
  // MARK: - Initializers
  init(image: UIImage, rect: CGRect, payLoad: [String: Any]? = nil) {
    self.image = image
    self.rect = rect
    self.payLoad = payLoad
  }

  init?(from dictionary: [AnyHashable: Any]) {
    guard let image = dictionary["image"] as? UIImage,
      let rect =  CGRect(from: dictionary) else {
        return nil
    }
    self.image = image
    self.rect = rect
    self.payLoad = nil
  }  
}
