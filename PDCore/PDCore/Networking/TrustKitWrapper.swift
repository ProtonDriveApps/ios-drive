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

import Foundation
import TrustKit
import Combine
import ProtonCoreEnvironment
import ProtonCoreServices

public final class TrustKitFactory {
    public typealias Delegate = TrustKitDelegate
    public typealias Configuration = [String: Any]

    @discardableResult
    public static func make(isHardfail: Bool, delegate: TrustKitDelegate) -> TrustKit? {
        let configuration = makeConfiguration(isHardfail: isHardfail)
        let trustKit = make(configuration: configuration, delegate: delegate)
        PMAPIService.trustKit = trustKit
        PMAPIService.noTrustKit = trustKit == nil
        return trustKit
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
        TrustKit.setLoggerBlock { TrustKitLogger.shared.collect($0) }
        let trustKit = TrustKitWrapper.current
        return trustKit
    }
}

/// Prevent TrustKit from sending duplicate logs in a short period of time
private final class TrustKitLogger {
    static let shared = TrustKitLogger()

    private let subject = PassthroughSubject<String, Never>()
    private var cancellable: AnyCancellable?

    private init() {
        cancellable = subject
            .collect(.byTime(DispatchQueue.main, .seconds(0.2)), options: nil)
            .scan((last: Optional<String>.none, current: "")) { state, snapshot in
                var logs: [String] = []
                for log in snapshot {
                    if logs.contains(log) { continue }
                    logs.append(log)
                }
                return (last: state.current, current: logs.joined(separator: "\n"))
            }
            .sink { pair in
                if pair.last == pair.current {
                    Log.info("Same trustKit output as last time", domain: .trustKit)
                } else {
                    Log.info("\(pair.current)", domain: .trustKit)
                }
            }
    }

    func collect(_ line: String) {
        subject.send(line)
    }
}

extension String {
    fileprivate func contains(check s: String) -> Bool {
        self.range(of: s, options: NSString.CompareOptions.caseInsensitive) != nil ? true : false
    }
}
