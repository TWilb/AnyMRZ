//
//  CIIMage+.swift
//  AnyMRZ
//
//  Created by Bohdan Mihiliev on 29.06.2019.
//  Copyright © 2019 Bohdan Mihiliev. All rights reserved.
//
import UIKit

extension CIImage {
//  func convert(cImage:CIImage, size: CGSize) -> UIImage {
//    
//    let context:CIContext = CIContext.init(options: nil)
//    let cgImage:CGImage = context.createCGImage(cImage, from: cImage.extent)!
//    let image:UIImage = UIImage.init(cgImage: cgImage)
//    
//    func scaleUIImageToSize(image: UIImage, size: CGSize) -> UIImage {
//
//      let rect = CGRect(x: 0, y: 0, width: size.width, height: size.height)
//      let hasAlpha = false
//
//      // Actually do the resizing to the rect using the ImageContext stuff
//      UIGraphicsBeginImageContextWithOptions(size, hasAlpha, 1.0)
//      image.draw(in: rect)
//      let newImage = UIGraphicsGetImageFromCurrentImageContext()
//      UIGraphicsEndImageContext()
//
//      return newImage!
//    }
//    
//    return scaleUIImageToSize(image: image, size: size)
//  }

  var uiImage: UIImage? {
    let context = CIContext.init(options: nil)
    guard let cgImage = context.createCGImage(self, from: self.extent) else { return nil }
    return UIImage(cgImage: cgImage)
  }
}
