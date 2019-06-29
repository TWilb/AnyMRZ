//
//  Array+Feature.swift
//  AnyMRZ
//
//  Created by Bohdan Mihiliev on 29.06.2019.
//  Copyright © 2019 Bohdan Mihiliev. All rights reserved.
//

public extension Array where Element == DocumentSegmentationParams.Feature {
    
    typealias DocumentSegmentationParamsFeatures = [String: [String: UInt32]]
    
    var dictFormat: DocumentSegmentationParamsFeatures {
        var dictionary = DocumentSegmentationParamsFeatures()
        
        self.forEach {
            dictionary[$0.title] = ["cX": $0.location.cX, "cY": $0.location.cY]
        }
        
        return dictionary
    }
}
