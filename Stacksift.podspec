Pod::Spec.new do |s|
  s.name         = 'Stacksift'
  s.version      = '0.3.5'
  s.summary      = 'Capture and submit crashes to Stacksift'

  s.homepage     = 'https://github.com/stacksift/SDK'
  s.license      = { :type => 'BSD-3-Clause', :file => 'LICENSE' }
  s.author       = { 'Matt Massicotte' => 'support@chimehq.com' }
  s.social_media_url = 'https://twitter.com/chimehq'
  
  s.source        = { :git => 'https://github.com/stacksift/SDK.git', :tag => s.version }

  s.source_files  = 'Sources/**/*.swift'

  s.osx.deployment_target = '10.13'
  s.ios.deployment_target = '12.0'
  s.tvos.deployment_target = '12.0'

  s.cocoapods_version = '>= 1.4.0'
  s.swift_version = '5.0'
  
  s.dependency 'Wells', '~> 0.1.4'
  s.dependency 'Impact', '~> 0.3.8'
end
