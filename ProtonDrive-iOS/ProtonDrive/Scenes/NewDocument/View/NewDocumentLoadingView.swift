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
import ProtonCoreUIFoundations
import PDCore
import UIKit

final class NewDocumentLoadingView {
    private let viewModel: NewDocumentViewModelProtocol
    private var banner: PMBanner?
    private var cancellables = Set<AnyCancellable>()

    init(viewModel: NewDocumentViewModelProtocol) {
        self.viewModel = viewModel
        subscribeToUpdates()
    }

    func start(with parentIdentifier: NodeIdentifier) {
        viewModel.start(parentIdentifier: parentIdentifier)
    }

    private func subscribeToUpdates() {
        viewModel.loading
            .sink { [weak self] text in
                self?.handleUpdate(text)
            }
            .store(in: &cancellables)
    }

    private func handleUpdate(_ text: String?) {
        if let text {
            showBanner(with: text)
        } else {
            banner?.dismiss()
            banner = nil
        }
    }

    private func showBanner(with text: String) {
        guard let viewController = UIApplication.shared.topViewController() else {
            return
        }

        let banner = PMBanner(message: text, style: PMBannerNewStyle.info)
        banner.show(at: .bottom, on: viewController)
        self.banner = banner
    }
}
