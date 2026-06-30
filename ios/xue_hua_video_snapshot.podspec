#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
#
Pod::Spec.new do |s|
  s.name             = 'xue_hua_video_snapshot'
  s.version          = '2.0.3'
  s.summary          = 'Extract cover candidate frames from video.'
  s.description      = <<-DESC
Extract non-black cover candidate frames from video files on iOS.
                       DESC
  s.homepage         = 'https://github.com/Matkurban/xue_hua_video_snapshot'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Matkurban' => 'matkurban@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files = [
    'xue_hua_video_snapshot/Sources/xue_hua_video_snapshot/XueHuaVideoSnapshotPlugin.swift',
    '../lib/shared/apple/**/*',
  ]
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
