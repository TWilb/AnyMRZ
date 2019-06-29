//
//  DocumentsSegmentationSettings.swift
//  AnyMRZ
//
//  Created by Bohdan Mihiliev on 29.06.2019.
//  Copyright © 2019 Bohdan Mihiliev. All rights reserved.
//

final class DocumentsSegmentationSettings {
  
  // MARK: - Properties
  static let shared = DocumentsSegmentationSettings()
  private let bundle = Bundle(for: DocumentsSegmentationSettings.self)
  private let decoder = JSONDecoder()
  private var settings = [DocumentSegmentationSetting]()
  
  // MARK: - Initialisers
  private init?() {
    if let path = bundle.url(forResource: "DocumentsSegmentationSettings", withExtension: "json") {
      do {
        let data = try Data(contentsOf: path, options: .mappedIfSafe)
        self.settings = try decoder.decode([DocumentSegmentationSetting].self, from: data)
      } catch {
        Logger.e(error.localizedDescription)
        return nil
      }
    }
  }
  
  // MARK: - Computed properties
  var idCardFront: DocumentSegmentationParams? {
    return settings.filter { $0.documentName == "UAEIDCard" }.first?.pages.first
  }
  
  var idCardBack: DocumentSegmentationParams? {
    return settings.filter { $0.documentName == "UAEIDCard" }.first?.pages[1]
  }
  
  var dewaBill: DocumentSegmentationParams? {
    return settings.filter { $0.documentName == "DewaBill" }.first?.pages.first
  }
}
