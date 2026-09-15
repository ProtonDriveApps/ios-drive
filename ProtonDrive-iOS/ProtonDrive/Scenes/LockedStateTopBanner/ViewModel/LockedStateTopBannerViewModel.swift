// Copyright (c) 2024 Proton AG
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
import PDLocalization
import PDUIComponents
import SwiftUI
import ProtonCoreDataModel

protocol LockedStateTopBannerViewModelProtocol: ObservableObject {
    var data: LockedStateTopBannerViewData { get }
    var showsDismissButton: Bool { get }
    func openUrl()
    func performSecondaryAction()
    func dismiss()
}

struct LockedStateTopBannerViewData: Equatable {
    let severance: WarningBadgeSeverance
    let title: String?
    let description: String?
    let actionButton: String?
    let secondaryActionButton: String?
    let buttonUrl: String?

    init(
        severance: WarningBadgeSeverance,
        title: String?,
        description: String?,
        actionButton: String?,
        secondaryActionButton: String? = nil,
        buttonUrl: String?
    ) {
        self.severance = severance
        self.title = title
        self.description = description
        self.actionButton = actionButton
        self.secondaryActionButton = secondaryActionButton
        self.buttonUrl = buttonUrl
    }
}

final class LockedStateTopBannerViewModel: LockedStateTopBannerViewModelProtocol {

    @Published var data: LockedStateTopBannerViewData
    let showsDismissButton: Bool

    private var onPrimaryAction: (() -> Void)?
    private var onSecondaryAction: (() -> Void)?
    private var onDismissAction: (() -> Void)?

    init(
        data: LockedStateTopBannerViewData,
        showsDismissButton: Bool = false,
        onPrimaryAction: (() -> Void)? = nil,
        onSecondaryAction: (() -> Void)? = nil,
        onDismissAction: (() -> Void)? = nil
    ) {
        self.data = data
        self.showsDismissButton = showsDismissButton
        self.onPrimaryAction = onPrimaryAction
        self.onSecondaryAction = onSecondaryAction
        self.onDismissAction = onDismissAction
    }

    convenience init(lockedStateBannerVisibility: LockedStateAlertVisibility) {
        let data = LockedStateTopBannerViewData(
            severance: .error,
            title: lockedStateBannerVisibility.bannerTitle,
            description: lockedStateBannerVisibility.bannerDescription,
            actionButton: lockedStateBannerVisibility.bannerButtonTitle,
            buttonUrl: lockedStateBannerVisibility.bannerButtonUrl
        )
        self.init(data: data)
    }

    func openUrl() {
        if let onPrimaryAction {
            onPrimaryAction()
            return
        }
        guard let urlString = self.data.buttonUrl, let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }

    func performSecondaryAction() {
        onSecondaryAction?()
    }

    func dismiss() {
        onDismissAction?()
    }
}
