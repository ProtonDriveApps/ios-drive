#
#  Be sure to run `pod spec lint PMSideMenu.podspec' to ensure this is a
#  valid spec and to remove all comments including this before submitting the spec.
#
#  To learn more about Podspec attributes see https://guides.cocoapods.org/syntax/podspec.html
#  To see working Podspecs in the CocoaPods repo see https://github.com/CocoaPods/Specs/
#

Pod::Spec.new do |spec|

  spec.name         = "PMSideMenu"
  spec.version      = "0.0.1"
  spec.summary      = "Basic sliding behaviour of side menu in Proton iOS applications"
  spec.description  = "This package can be used as a base for future shared side menu UI elements. At the moment it's only a container view controller."
  spec.homepage     = "https://gitlab.protontech.ch/apple/shared/pmsidemenu"
  spec.license      = "ProtonDrive"
  spec.author       = "Anatoly Rosencrantz"

  spec.swift_version = "5.5"

  #  When using multiple platforms
  spec.ios.deployment_target = "13.0"


  # ――― Source Location ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  #
  #  Specify the location from where the source should be retrieved.
  #  Supports git, hg, bzr, svn and HTTP.
  #

  # spec.source       = { :git => "git@gitlab.protontech.ch:apple/shared/pmsidemenu.git", :tag => "#{spec.version}" }
  spec.source       = { :path => "Sources/" }
  spec.source_files  = "Sources/**/*"
  spec.dependency "SideMenuSwift"
  
end

