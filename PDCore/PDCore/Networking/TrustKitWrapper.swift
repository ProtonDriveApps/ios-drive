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
import ProtonCore_Services

public protocol TrustKitFailureDelegate: AnyObject {
    func onTrustKitValidationError(_ error: TrustKitError)
}

public enum TrustKitError: Error {
    case failed
    case hardfailed
}

struct TrustKitConfiguration {
    let value: [String: Any]
}

extension TrustKitConfiguration {
    static let hardfail = make(withHardfail: true)
    static let fail = make(withHardfail: false)

    private static func make(withHardfail hardfail: Bool) -> TrustKitConfiguration {
        return TrustKitConfiguration(value: [
            kTSKSwizzleNetworkDelegates: false,
            kTSKPinnedDomains: [
                "protonmail.com": [
                    kTSKEnforcePinning: hardfail,
                    kTSKIncludeSubdomains: true,
                    kTSKDisableDefaultReportUri: true,
                    kTSKReportUris: [
                        "https://api.protonmail.ch/reports/tls"
                    ],
                    kTSKPublicKeyHashes: [
                        // verify.protonmail.com and verify-api.protonmail.com certificate
                        "8joiNBdqaYiQpKskgtkJsqRxF7zN0C0aqfi8DacknnI=", // Current
                        "JMI8yrbc6jB1FYGyyWRLFTmDNgIszrNEMGlgy972e7w=", // Hot backup
                        "Iu44zU84EOCZ9vx/vz67/MRVrxF1IO4i4NIa8ETwiIY=", // Cold backup
                    ]
                ],
                "protonmail.ch": [
                    kTSKEnforcePinning: hardfail,
                    kTSKIncludeSubdomains: true,
                    kTSKForceSubdomainMatch: true,
                    kTSKNoSSLValidation: true,
                    kTSKDisableDefaultReportUri: true,
                    kTSKReportUris: [
                        "https://api.protonmail.ch/reports/tls"
                    ],
                    kTSKPublicKeyHashes: [
                        // api.protonmail.ch certificate
                        "drtmcR2kFkM8qJClsuWgUzxgBkePfRCkRpqUesyDmeE=", // Current
                        "YRGlaY0jyJ4Jw2/4M8FIftwbDIQfh8Sdro96CeEel54=", // Hot backup
                        "AfMENBVvOS8MnISprtvyPsjKlPooqh8nMB/pvCrpJpw=", // Cold backup
                    ]
                ],
                "proton.me": [
                    kTSKEnforcePinning: hardfail,
                    kTSKIncludeSubdomains: true,
                    kTSKForceSubdomainMatch: true,
                    kTSKNoSSLValidation: true,
                    kTSKDisableDefaultReportUri: true,
                    kTSKReportUris: [
                        "https://api.protonmail.ch/reports/tls"
                    ],
                    kTSKPublicKeyHashes: [
                        // proton.me certificate
                        "CT56BhOTmj5ZIPgb/xD5mH8rY3BLo/MlhP7oPyJUEDo=", // Current
                        "35Dx28/uzN3LeltkCBQ8RHK0tlNSa2kCpCRGNp34Gxc=", // Hot backup
                        "qYIukVc63DEITct8sFT7ebIq5qsWmuscaIKeJx+5J5A=", // Cold backup
                    ]
                ],
                ".compute.amazonaws.com": [
                    kTSKEnforcePinning: true,
                    kTSKIncludeSubdomains: true,
                    kTSKForceSubdomainMatch: true,
                    kTSKNoSSLValidation: true,
                    kTSKDisableDefaultReportUri: true,
                    kTSKReportUris: [
                        "https://api.protonmail.ch/reports/tls"
                    ],
                    kTSKPublicKeyHashes: [
                        // api.protonmail.ch and api.protonvpn.ch proxy domains certificates
                        "EU6TS9MO0L/GsDHvVc9D5fChYLNy5JdGYpJw0ccgetM=", // Current
                        "iKPIHPnDNqdkvOnTClQ8zQAIKG0XavaPkcEo0LBAABA=", // Backup 1
                        "MSlVrBCdL0hKyczvgYVSRNm88RicyY04Q2y5qrBt0xA=", // Backup 2
                        "C2UxW0T1Ckl9s+8cXfjXxlEqwAfPM4HiW2y3UdtBeCw=", // Backup 3
                    ]
                ],
                kTSKCatchallPolicy: [
                    kTSKEnforcePinning: true,
                    kTSKNoSSLValidation: true,
                    kTSKNoHostnameValidation: true,
                    kTSKAllowIPsOnly: true,
                    kTSKDisableDefaultReportUri: true,
                    kTSKReportUris: [
                        "https://api.protonmail.ch/reports/tls"
                    ],
                    kTSKPublicKeyHashes: [
                        // api.protonmail.ch and api.protonvpn.ch proxy domains certificates
                        "EU6TS9MO0L/GsDHvVc9D5fChYLNy5JdGYpJw0ccgetM=", // Current
                        "iKPIHPnDNqdkvOnTClQ8zQAIKG0XavaPkcEo0LBAABA=", // Backup 1
                        "MSlVrBCdL0hKyczvgYVSRNm88RicyY04Q2y5qrBt0xA=", // Backup 2
                        "C2UxW0T1Ckl9s+8cXfjXxlEqwAfPM4HiW2y3UdtBeCw=", // Backup 3
                    ]
                ],
            ]
        ])
    }
}

public final class TrustKitFactory {
    public typealias Delegate = TrustKitFailureDelegate
    public typealias Configuration = [String: Any]

    @discardableResult
    public static func make(isHardfail: Bool, delegate: TrustKitFailureDelegate) -> TrustKit {
        let configuration: TrustKitConfiguration = isHardfail ? .hardfail : .fail
        let trustKit = make(configuration: configuration, delegate: delegate)

        PMAPIService.trustKit = trustKit
        return trustKit
    }

    private static func make(configuration: TrustKitConfiguration, delegate: TrustKitFailureDelegate) -> TrustKit {
        let trustKit = Constants.runningInExtension ? TrustKit(configuration: configuration.value, sharedContainerIdentifier: Constants.appGroup) : TrustKit(configuration: configuration.value)
        trustKit.pinningValidatorCallback = { [weak delegate] validatorResult, hostName, policy in

            guard validatorResult.evaluationResult != .success,
                  validatorResult.finalTrustDecision != .shouldAllowConnection else { return }

            if hostName.contains(check: ".compute.amazonaws.com") {
                delegate?.onTrustKitValidationError(.hardfailed)
            } else {
                delegate?.onTrustKitValidationError(.failed)
            }
        }

        return trustKit
    }
}

extension String {
    fileprivate func contains(check s: String) -> Bool {
        self.range(of: s, options: NSString.CompareOptions.caseInsensitive) != nil ? true : false
    }
}
