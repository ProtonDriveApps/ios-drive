// Copyright (c) 2023 Proton AG
//
// This file is part of Proton Drive.
//
// Proton Drive is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Proton Drive is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Proton Drive. If not, see https://www.gnu.org/licenses/.

import TrustKit
import ProtonCoreEnvironment
import ProtonCoreServices
import PDLoadTesting

public final class TrustKitFactory {
    public typealias Delegate = TrustKitDelegate
    public typealias Configuration = [String: Any]

    @discardableResult
    public static func make(isHardfail: Bool, delegate: TrustKitDelegate) -> TrustKit? {
        let configuration = makeConfiguration(isHardfail: isHardfail)
        let trustKit = make(configuration: configuration, delegate: delegate)
        PMAPIService.trustKit = trustKit
        PMAPIService.noTrustKit = trustKit == nil
        if LoadTesting.isEnabled {
            return nil
        } else {
            return trustKit
        }
    }

    private static func makeConfiguration(isHardfail: Bool) -> [String: Any] {
        if Constants.buildType.isQaOrBelow {
            return TrustKitWrapper.configuration(hardfail: isHardfail, ignoreMacUserDefinedTrustAnchors: true)
        } else {
            return TrustKitWrapper.configuration(hardfail: isHardfail)
        }
    }

    private static func make(configuration: Configuration, delegate: TrustKitDelegate) -> TrustKit? {
        TrustKitWrapper.setUp(delegate: delegate,
                              customConfiguration: configuration,
                              sharedContainerIdentifier: Constants.runningInExtension ? Constants.appGroup : nil)
        TrustKit.setLoggerBlock { Log.info($0, domain: .trustKit) }
        let trustKit = TrustKitWrapper.current
        return trustKit
    }
}

extension String {
    fileprivate func contains(check s: String) -> Bool {
        self.range(of: s, options: NSString.CompareOptions.caseInsensitive) != nil ? true : false
    }
}
