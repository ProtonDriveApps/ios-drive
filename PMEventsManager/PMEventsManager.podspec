#
#  Be sure to run `pod spec lint PMSideMenu.podspec' to ensure this is a
#  valid spec and to remove all comments including this before submitting the spec.
#
#  To learn more about Podspec attributes see https://guides.cocoapods.org/syntax/podspec.html
#  To see working Podspecs in the CocoaPods repo see https://github.com/CocoaPods/Specs/
#

Pod::Spec.new do |spec|

  spec.name         = "PMEventsManager"
  spec.version      = "2.0.1"
  spec.summary      = "BE events engine"
  spec.description  = "Events pulling engine with support of 1 general and multiple special loops"
  spec.homepage     = "https://gitlab.protontech.ch/apple/shared/pmeventsmanager"
  spec.license      = "ProtonDrive"
  spec.author       = "Anatoly Rosencrantz"

  spec.swift_version = "5.5"

  #  When using multiple platforms
  spec.ios.deployment_target = "15.0"
  spec.macos.deployment_target = "13.0"

  # ――― Source Location ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  #
  #  Specify the location from where the source should be retrieved.
  #  Supports git, hg, bzr, svn and HTTP.
  #

  # spec.source       = { :git => "git@gitlab.protontech.ch:apple/shared/pmeventsmanager.git", :tag => "#{spec.version}" }
  spec.source       = { :path => "Sources/" }
  spec.source_files  = "Sources/**/*"
  spec.dependency 'ProtonCore-DataModel'
  spec.dependency 'ProtonCore-Networking'
  spec.dependency 'ProtonCore-Services'
  spec.dependency 'ProtonCore-Payments'
  
  spec.test_spec 'Tests' do |test_spec|
    test_spec.ios.deployment_target = "15.0"
    test_spec.macos.deployment_target = "13.0"
    test_spec.source_files = 'Tests/**/*'
    test_spec.dependency 'ProtonCore-TestingToolkit/UnitTests/Core'
  end
  
end

