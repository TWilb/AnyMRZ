//
//  Models.swift
//  AnyMRZ
//
//  Created by Bohdan Mihiliev on 29.06.2019.
//  Copyright © 2019 Bohdan Mihiliev. All rights reserved.
//
/// Stands for type of available documents for scanning
public enum DocumentType {
  case selfie, emiratesID, passport, visa, dewaBill
}
/// Stands for available camera states
public enum CameraState {
  case ready, accessDenied, noDeviceFound, notDetermined
}

/// Stands for available type of camera devices
public enum CameraDevice {
  case front, back
}

/// Stands for available camera's flash modes
public enum CameraFlashMode: Int {
  case off, on, auto
}

/// Stands for available camera's output modes
public enum CameraOutputMode {
  case stillImage, videoWithMic, videoOnly, rawData
}

/// Stands for available camera's quaility mode
public enum CameraOutputQuality: Int {
  case low, medium, high
}
