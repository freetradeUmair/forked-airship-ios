workspace 'Airship'
use_frameworks!

target 'AirshipTests' do
  platform :ios, '11.0'
  project 'Airship/Airship.xcodeproj'
  pod 'OCMock', '~> 3.7.1'
  pod 'XcodeEdit', '~> 2.7'
end

target 'AirshipAccengageTests' do
  platform :ios, '11.0'
  project 'Airship/Airship.xcodeproj'
  pod 'OCMock', '~> 3.7.1'
end

target 'AirshipNotificationServiceExtensionTests' do
  platform :ios, '11.0'
  project 'AirshipExtensions/AirshipExtensions.xcodeproj'
  pod 'OCMock', '~> 3.7.1'
end

target 'AirshipNotificationContentExtensionTests' do
  platform :ios, '11.0'
  project 'AirshipExtensions/AirshipExtensions.xcodeproj'
  pod 'OCMock', '~> 3.7.1'
end


post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '11.0'
    end
  end
end