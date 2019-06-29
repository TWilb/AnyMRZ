//
//  RecognizedTextData.swift
//  AnyMRZ
//
//  Created by Bohdan Mihiliev on 29.06.2019.
//  Copyright © 2019 Bohdan Mihiliev. All rights reserved.
//
import UIKit

public struct RecognizedTextData {
  let imageBlock: UIImage
  let content: String
  let additionalInfo: [String: Any]?
}
