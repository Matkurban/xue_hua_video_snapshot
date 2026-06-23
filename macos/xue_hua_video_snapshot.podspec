#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
#
Pod::Spec.new do |s|
  s.name             = 'xue_hua_video_snapshot'
  s.version          = '1.0.0'
  s.summary          = 'Extract cover candidate frames from video.'
  s.description      = <<-DESC
Extract non-black cover candidate frames from video files on macOS.
                       DESC
  s.homepage         = 'https://jsontodart.cn'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'kurban' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'xue_hua_video_snapshot/Sources/xue_hua_video_snapshot/**/*'
  s.dependency 'FlutterMacOS'
  s.platform = :osx, '10.15'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end
