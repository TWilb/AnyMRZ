//
//  CGRect.swift
//  AnyMRZ
//
//  Created by Bohdan Mihiliev on 29.06.2019.
//  Copyright © 2019 Bohdan Mihiliev. All rights reserved.
//
import UIKit
extension CGRect {
  func extend(to fraction: CGFloat) -> CGRect {
    return self.insetBy(dx: self.width * fraction, dy: self.height * fraction)
  }
  
  func extend(by pixels: CGFloat) -> CGRect {
    return self.insetBy(dx: pixels, dy: pixels)
  }
  
  func includes(x xCoord: Int, y yCoord: Int) -> Bool {
    return xCoord >= Int(self.minX) && xCoord <= Int(self.maxX) && yCoord >= Int(self.minY) && yCoord <= Int(self.maxY)
  }
  
  init?(from dictionary: [AnyHashable: Any]) {
    guard let rectX = dictionary["x"] as? Double,
      let rectY = dictionary["y"] as? Double,
      let width = dictionary["width"] as? Double,
      let height = dictionary["height"] as? Double
      else {
        return nil
    }
    
    self.init(x: rectX, y: rectY, width: width, height: height)
  }
}
