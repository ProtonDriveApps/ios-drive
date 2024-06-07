
Pod::Spec.new do |s|

    s.name             = 'PMSettings'
    s.version          = '2.0.0'

    s.summary      = "Settings + Lock/Unlock"
    s.description  = "Building blocks of configurable Settings user flow for Proton iOS applications"
    s.homepage     = "https://gitlab.protontech.ch/apple/shared/pmsettings"
    s.license      = "ProtonDrive"
    s.author       = "Aaron Huánuco Ramos"

    s.ios.deployment_target = "14.0"
    s.swift_version = "5.5"

    s.dependency 'ProtonCore-UIFoundations'

    s.source       = { :path => "Sources/" }
    s.source_files = 'Sources/**/*.swift'
    s.resource_bundles = {
        'Resources-PMSettings' => ['Sources/Resources/*.lproj/*.strings' ]
    }
    s.pod_target_xcconfig = { 'APPLICATION_EXTENSION_API_ONLY' => 'NO' }
    s.test_spec 'Tests' do |settings_tests|
        settings_tests.dependency "ProtonCore-TestingToolkit/UnitTests/Core"
        settings_tests.source_files = 'Tests/**/*.swift'
    end
end
