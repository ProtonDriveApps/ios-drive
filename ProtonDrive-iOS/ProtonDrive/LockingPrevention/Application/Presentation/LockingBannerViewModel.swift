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
import Foundation

public protocol LockingBannerViewModelProtocol: ObservableObject {
    var viewData: LockingBannerViewData { get }

    func closeBannerDisclaimer()
    func onAppear()
    func onDissapear()
}

public final class LockingBannerViewModel: LockingBannerViewModelProtocol {
    private let interactor: ScreenLockInteractor
    private let repository: ScreenLockingBannerRepository
    private var cancellables = Set<AnyCancellable>()

    @Published public var viewData: LockingBannerViewData

    public init(interactor: ScreenLockInteractor, repository: ScreenLockingBannerRepository) {
        self.interactor = interactor
        self.repository = repository
        viewData = .hiddenBanner

        interactor.isLockingDisabledPublisher.combineLatest(repository.isLockBannerEnabled)
            .sink { [weak self] in
                guard let self else { return }
                self.viewData = ($0 && $1) ? .shownBanner : .hiddenBanner
            }
            .store(in: &cancellables)
    }

    public func closeBannerDisclaimer() {
        viewData = LockingBannerViewData(message: nil)
        repository.disableLockBanner()
    }

    public func onAppear() {
        interactor.setVisible(true)
    }

    public func onDissapear() {
        interactor.setVisible(false)
    }
}
