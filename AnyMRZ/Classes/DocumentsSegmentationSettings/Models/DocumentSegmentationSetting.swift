//
//  DocumentSegmentationSetting.swift
//  AnyMRZ
//
//  Created by Bohdan Mihiliev on 29.06.2019.
//  Copyright © 2019 Bohdan Mihiliev. All rights reserved.
//

public struct DocumentSegmentationSetting: Decodable {
  let documentName: String
  let pages: [DocumentSegmentationParams]
}
