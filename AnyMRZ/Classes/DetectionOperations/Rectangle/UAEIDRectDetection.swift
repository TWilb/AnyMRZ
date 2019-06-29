//
//  UAEIDRectDetection.swift
//  AnyMRZ
//
//  Created by Bohdan Mihiliev on 29.06.2019.
//  Copyright © 2019 Bohdan Mihiliev. All rights reserved.
//
import Vision

final class UAEIDRectDetection: RectDetectionOperation, DocumentRectDemensions {
    
    // MARK: - Properties
    var width: Float = 85.725
    var height: Float = 53.975
    
    // MARK: - Computed properties
    var aspectRation: Float {
        return height/width
    }
    var delta: Float {
        return aspectRation * 0.10
    }
    override var recognitionRequest: VNDetectRectanglesRequest {
        
        let detectRectRequest = VNDetectRectanglesRequest(completionHandler: self.recognitionHandler)
        
        detectRectRequest.preferBackgroundProcessing = false
        detectRectRequest.maximumAspectRatio = aspectRation + delta
        detectRectRequest.minimumAspectRatio = aspectRation - delta
        detectRectRequest.maximumObservations = self.objectsCountToDetect
        
        return detectRectRequest
    }
}
