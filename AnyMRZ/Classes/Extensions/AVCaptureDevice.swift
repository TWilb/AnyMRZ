//
//  AVCaptureDevice.swift
//  AnyMRZ
//
//  Created by Bohdan Mihiliev on 29.06.2019.
//  Copyright © 2019 Bohdan Mihiliev. All rights reserved.
//

import AVFoundation

extension AVCaptureDevice {
  static var videoDevices: [AVCaptureDevice] {
    let devices = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video,
                                                   position: .unspecified).devices
    return devices
  }
}
