#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint singbox_mm.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'singbox_mm'
  s.version          = '0.1.0'
  s.summary          = 'Flutter VPN plugin with sing-box bridge and routing builder.'
  s.description      = <<-DESC
Flutter VPN plugin that exposes a typed sing-box runtime API, config builder,
state events, and platform bridges for Android and iOS.
                       DESC
  s.homepage         = 'https://github.com/mmcoder/singbox_mm'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'MMCoder' => 'dev@mmcoder.dev' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386'
  }
  s.swift_version = '5.0'
end
