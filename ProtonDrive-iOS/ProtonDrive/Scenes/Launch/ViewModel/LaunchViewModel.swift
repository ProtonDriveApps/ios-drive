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

import Combine
import PDCore
import UIKit
import PDLocalization

final class LaunchViewModel {
    private var cancellables = Set<AnyCancellable>()
    private let launcherConfigurator: LaunchConfigurator

    let alertPublisher: AnyPublisher<FailingAlert, Never>
    let bannerPublisher: AnyPublisher<BannerModel, Never>
    let accountRecoveryWrapper: AccountRecoveryWrapper

    init(
        alertPresenting: AnyPublisher<DriveCoreAlert, Never>,
        alertDismissing: AnyPublisher<Void, Never>,
        userPublisher: AnyPublisher<UserInfo, Never>,
        bannerPublisher: AnyPublisher<BannerModel, Never>,
        accountRecoveryWrapper: AccountRecoveryWrapper,
        configurator: LaunchConfigurator
    ) {
        launcherConfigurator = configurator
        self.bannerPublisher = bannerPublisher
        self.accountRecoveryWrapper = accountRecoveryWrapper

        alertPresenting
            .sink { alert in
                switch alert {
                case .logout:
                    NotificationCenter.default.post(.signOut)
                default:
                    break
                }
            }
            .store(in: &cancellables)

        let retryForceUpdatePublisher: AnyPublisher<DriveCoreAlert, Never> = NotificationCenter.default
            .publisher(for: Self.forceUpgrade, object: nil)
            .map { _ -> DriveCoreAlert in .forceUpgrade }
            .eraseToAnyPublisher()
        
        let userPublisher = userPublisher
            .map(\.isDelinquent)
            .filter { $0 } // proceed only when delinquent becomes true
            .map { _ -> DriveCoreAlert in .userGoneDelinquent }
            .eraseToAnyPublisher()

        let alertPublisher: AnyPublisher<DriveCoreAlert, Never> = Publishers
            .MergeMany(alertPresenting, retryForceUpdatePublisher, userPublisher)
            .eraseToAnyPublisher()

        self.alertPublisher = Publishers
            .Zip(
                alertPublisher, alertDismissing
            )
            .delay(for: 0.3, scheduler: DispatchQueue.main)
            .compactMap { (alert, _) -> FailingAlert? in
                switch alert {

                case .logout:
                    return FailingAlert(type: .logout, primaryAction: nil, secondaryAction: .ok)

                case .trustKitFailure:
                    let action = AlertAction(
                        title: Localization.launch_alert_title_disable_validation,
                        action: { NotificationCenter.default.post(name: PMAPIClient.downgradeTrustKit, object: nil) }
                    )

                    return FailingAlert(type: .trustKitFailure, primaryAction: action, secondaryAction: .cancel)

                case .trustKitHardFailure:
                    return FailingAlert(type: .trustKitHardFailure, primaryAction: nil, secondaryAction: .ok)

                case .forceUpgrade:
                    let primaryAction = AlertAction(
                        title: Localization.launch_alert_title_update,
                        action: {
                            let url = Constants.appStorePageURL
                            guard UIApplication.shared.canOpenURL(url) else {
                                return
                            }
                            UIApplication.shared.open(url, options: [:]) { _ in
                                NotificationCenter.default.post(name: Self.forceUpgrade, object: nil)
                            }
                        }
                    )

                    let secondaryAction = AlertAction(
                        title: Localization.general_learn_more,
                        action: {
                            let url = Constants.forceUpgradeLearnMoreURL
                            guard UIApplication.shared.canOpenURL(url) else {
                                return
                            }
                            UIApplication.shared.open(url, options: [:]) { _ in
                                NotificationCenter.default.post(name: Self.forceUpgrade, object: nil)
                            }
                        }
                    )
                    return FailingAlert(type: .forceUpgrade, primaryAction: primaryAction, secondaryAction: secondaryAction)
                    
                case .userGoneDelinquent:
                    return FailingAlert(type: .userGoneDelinquent, primaryAction: nil, secondaryAction: .ok)

                default:
                    return nil
                }
            }
            .eraseToAnyPublisher()
    }

    public func onDriveLaunch() {
        launcherConfigurator.onDriveLaunch()
    }
}

extension LaunchViewModel {
    static let forceUpgrade = Notification.Name("LaunchViewModel.forceUpgradeCoreNotification")
}

private extension AlertAction {
    static var ok: AlertAction {
        AlertAction(title: Localization.general_ok, action: {})
    }

    static var cancel: AlertAction {
        AlertAction(title: Localization.general_cancel, action: {})
    }
}
