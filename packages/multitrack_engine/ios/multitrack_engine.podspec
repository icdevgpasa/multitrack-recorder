#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint multitrack_engine.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'multitrack_engine'
  s.version          = '0.0.1'
  s.summary          = 'Low-latency multi-track record/playback engine.'
  s.description      = <<-DESC
Low-latency multi-track record/playback engine.
                       DESC
  s.homepage         = 'https://github.com/icdevgpasa/multitrack-recorder'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'multitrack-recorder' => '' }
  s.source           = { :path => '.' }
  s.source_files = 'multitrack_engine/Sources/multitrack_engine/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '15.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'multitrack_engine_privacy' => ['multitrack_engine/Sources/multitrack_engine/PrivacyInfo.xcprivacy']}
end
