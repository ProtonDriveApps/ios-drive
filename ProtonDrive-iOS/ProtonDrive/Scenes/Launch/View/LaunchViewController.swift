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

import UIKit
import PDCore
import Combine
import PMSideMenu
import PDUIComponents
import ProtonCoreUIFoundations
import ProtonCoreAccountRecovery
import ProtonCoreServices

final class LaunchViewController: UIViewController {
    private var cancellables = Set<AnyCancellable>()

    @StatusBarStyle var currentStatusBarStyle: UIStatusBarStyle 
    var viewModel: LaunchViewModel!
    var onViewDidLoad: (() -> Void)?
    var onPresentAlert: ((FailingAlert) -> Void)?
    var onPresentAccountRecovery: ((APIService) -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        $currentStatusBarStyle.delegate = self
        
        onViewDidLoad?()
        viewModel.onDriveLaunch()

        viewModel.alertPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] alert in
                self?.onPresentAlert?(alert)
            }
            .store(in: &cancellables)

        viewModel.bannerPublisher
            .filter { $0.delay == .immediate }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] alert in
                self?.presentBanner(alert)
            }
            .store(in: &cancellables)

        viewModel.bannerPublisher
            .filter { $0.delay == .delayed }
            .delay(for: 1, scheduler: DispatchQueue.main)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] alert in
                self?.presentBanner(alert)
            }
            .store(in: &cancellables)

        viewModel.accountRecoveryWrapper.publisher
            .sink { [weak self] _ in
                if let self {
                    self.onPresentAccountRecovery?(self.viewModel.accountRecoveryWrapper.apiService)
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.post(.didDismissAlert)
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        currentStatusBarStyle
    }

    func presentBanner(_ banner: BannerModel) {
        // Longer duration for UI test to prevent test failed due to banner dismiss too early 
        let duration: TimeInterval = Constants.isUITest ? 10 : 4
        let banner = PMBanner(message: banner.message, style: banner.style, dismissDuration: duration)
        banner.accessibilityIdentifier = "Banner.bannerShown"
        banner.show(at: .bottom, on: UIApplication.shared.topViewController()!)
    }

}

extension LaunchViewController: ContentHostingControllerProtocol {
    
    func changeStatusBarStyle(_ style: UIStatusBarStyle) {
        self.currentStatusBarStyle = style
    }

}
