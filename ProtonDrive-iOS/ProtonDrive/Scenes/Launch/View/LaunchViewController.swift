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
import PDCoreIOS
import Combine
import PMSideMenu
import PDUIComponents
import ProtonCoreUIFoundations
import ProtonCoreAccountRecovery
import ProtonCoreServices
import PDPhotos

final class LaunchViewController: UIViewController {
    private var cancellables = Set<AnyCancellable>()

    @StatusBarStyle var currentStatusBarStyle: UIStatusBarStyle 
    var viewModel: LaunchViewModel!
    var onViewDidLoad: (() -> Void)?
    var onPresentAlert: ((FailingAlert) -> Void)?
    var onPresentAccountRecovery: ((APIService) -> Void)?
    var onShake: (() -> Void)?
    private var swiftUIActionBarIsVisible: Bool = false

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

        NotificationCenter.default.publisher(for: .actionBarVisibilityIsChanged)
            .sink { [weak self] notification in
                let isVisible = notification.userInfo?["isVisible"] as? Bool ?? false
                self?.swiftUIActionBarIsVisible = isVisible
            }
            .store(in: &cancellables)

        NotificationCenter.default.post(.didDismissAlert)
    }

    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            onShake?()
        }
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        currentStatusBarStyle
    }

    func presentBanner(_ banner: BannerModel) {
        // Longer duration for UI test to prevent test failed due to banner dismiss too early
        let duration: TimeInterval = Constants.isUITest ? 10 : 4
        let banner = PMBanner(message: banner.message, style: banner.style, dismissDuration: duration)
        banner.accessibilityIdentifier = "Banner.bannerShown"
        let topVC = UIApplication.shared.topViewController()
        let topView = topVC!.view!
        let toolbarHeight = toolbarHeight(view: topView)
        banner.show(
            at: .bottomCustom(UIEdgeInsets(top: CGFloat.infinity, left: 8, bottom: toolbarHeight, right: 8)),
            on: topVC!
        )
    }

    private func toolbarHeight(view: UIView) -> CGFloat {
        let padding: CGFloat = 8

        if swiftUIActionBarIsVisible {
            return 48 + padding
        }

        var subViews: [UIView] = [view]
        while !subViews.isEmpty {
            let currentView = subViews.removeFirst()
            subViews.append(contentsOf: currentView.subviews)
            if currentView is UIToolbar, !currentView.isHidden {
                return currentView.frame.height + padding
            } else if currentView is UITabBar {
                return 48 + padding
            }
        }
        return padding
    }
}

extension LaunchViewController: ContentHostingControllerProtocol {
    
    func changeStatusBarStyle(_ style: UIStatusBarStyle) {
        self.currentStatusBarStyle = style
    }

}
