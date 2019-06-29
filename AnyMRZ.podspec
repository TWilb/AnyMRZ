#
# Be sure to run `pod lib lint AnyMRZ.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'AnyMRZ'
  s.version          = '0.5.1'
  s.summary          = 'A short description of AnyMRZ.'
  s.requires_arc     = true
  s.static_framework = true
  s.swift_version    = '5.0'
  s.description      = <<-DESC
  AnyMRZ is an simple libray for iOS to recognize any MRZ code you want. AnyMRZ works on top of TesseractOCR and Apple Vision libraries.
  DESC

  s.homepage         = 'https://github.com/Bohdan/AnyMRZ'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Bohdan' => 'bohdanrose1@gmail.com' }
  s.source           = { :git => 'https://github.com/Bohdan/AnyMRZ.git', :tag => s.version.to_s }

  s.ios.deployment_target = '11.0'
  s.source_files = 'AnyMRZ/Classes/**/*'
  s.preserve_paths = 'AnyMRZ/TesseractOCR.framework'
  s.xcconfig = { 'OTHER_LDFLAGS' => '-framework TesseractOCR' }
  s.vendored_frameworks = 'AnyMRZ/TesseractOCR.framework'
end
