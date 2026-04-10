Pod::Spec.new do |spec|
  spec.name = 'BrotherPrintSDK'
  spec.version = '4.13.0'
  spec.summary = 'Brother Print SDK binary wrapper for iOS.'
  spec.description = 'Local podspec that exposes the Brother BRLMPrinterKit XCFramework to the Flutter iOS host app.'
  spec.homepage = 'https://support.brother.com/g/s/es/dev/en/mobilesdk/download/index.html'
  spec.license = { :type => 'Commercial', :text => 'See Brother SDK EULA bundled with the SDK download.' }
  spec.author = { 'Brother' => 'support.brother.com' }
  spec.platform = :ios, '13.0'
  spec.source = { :path => '.' }
  spec.vendored_frameworks = 'Vendor/BrotherSDK/BRLMPrinterKit.xcframework'
  spec.frameworks = 'CoreBluetooth', 'ExternalAccessory', 'SystemConfiguration', 'CFNetwork', 'WebKit'
  spec.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES'
  }
end
