//
//  UIImage+.swift
//  AnyMRZ
//
//  Created by Bohdan Mihiliev on 29.06.2019.
//  Copyright © 2019 Bohdan Mihiliev. All rights reserved.
//

import UIKit

extension UIImage {
  var cvPixelBuffer: CVPixelBuffer? {
    let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue, kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
    var pixelBuffer: CVPixelBuffer?
    let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(self.size.width), Int(self.size.height), kCVPixelFormatType_32ARGB, attrs, &pixelBuffer)
    guard status == kCVReturnSuccess else {
      return nil
    }
    if let unwrappedPixelBuffer = pixelBuffer {
      CVPixelBufferLockBaseAddress(unwrappedPixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
      let pixelData = CVPixelBufferGetBaseAddress(unwrappedPixelBuffer)
      
      let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
      let context = CGContext(data: pixelData,
                              width: Int(self.size.width),
                              height: Int(self.size.height),
                              bitsPerComponent: 8,
                              bytesPerRow: CVPixelBufferGetBytesPerRow(unwrappedPixelBuffer),
                              space: rgbColorSpace,
                              bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)
      
      context?.translateBy(x: 0, y: self.size.height)
      context?.scaleBy(x: 1.0, y: -1.0)
      if let unwrappedContext = context {
        UIGraphicsPushContext(unwrappedContext)
        self.draw(in: CGRect(x: 0, y: 0, width: self.size.width, height: self.size.height))
        UIGraphicsPopContext()
        CVPixelBufferUnlockBaseAddress(unwrappedPixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
        
        return pixelBuffer
      }
    }
    return nil
  }
  
  var transformedForMRZ: UIImage {
    let context = CIContext(options: nil)
    let luminance = self.averageLuminance //getAverageLuminance(image: image)
    
    let gamma = 0.8 * luminance / 256
    
    guard var ciImageToTransform = CIImage(image: self) else { return self }
    ciImageToTransform = ciImageToTransform.applyingFilter("CIGammaAdjust", parameters: ["inputPower": gamma])
    ciImageToTransform = ciImageToTransform.applyingFilter("CIColorControls", parameters: [
      "inputSaturation": 0,
      "inputContrast": 1.5
      ])
    if let transformedCIImage = context.createCGImage(ciImageToTransform, from: ciImageToTransform.extent) {
      let processedImage = UIImage(cgImage: transformedCIImage)
      return processedImage
    }
    return self
  }
  
  var averageLuminance: Double {
    guard let imageData = self.cgImage?.dataProvider?.data,
        let pixels = CFDataGetBytePtr(imageData) else {
      fatalError("averageLuminance can't be counted")
    }
    let length = CFDataGetLength(imageData)
    var averageLuminance: Double = 0
    
    for index in 0...length {
      let red = 0.213 * Double(pixels[index])
      let green = 0.715 * Double(pixels[index + 1])
      let blue = 0.072 * Double(pixels[index + 2])
      
      let luminance = red + green + blue
      averageLuminance += luminance / Double(length)
    }
    
    return averageLuminance
  }
  
  func crop(to rect: CGRect) -> UIImage? {
    guard let croppedCGImage = self.cgImage?.cropping(to: rect) else { return nil }
    return UIImage(cgImage: croppedCGImage)
  }
  
  func scaledImage(to size: CGSize) -> UIImage? {
    let rect = CGRect(x: 0, y: 0, width: size.width, height: size.height)
    let hasAlpha = false
    
    // Actually do the resizing to the rect using the ImageContext stuff
    UIGraphicsBeginImageContextWithOptions(size, hasAlpha, 1.0)
    self.draw(in: rect)
    let croppedImage = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    
    return croppedImage
  }
}
