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
import Combine

public class PhotosUploadingScreenLockInteractor: ScreenLockInteractor {
    private let isVisibleSubject = CurrentValueSubject<Bool, Never>(false)
    private var cancellables = Set<AnyCancellable>()
    private let controller: ScreenLockingResourceController

    public let isLockingDisabledPublisher: AnyPublisher<Bool, Never>

    public init(isUploading: AnyPublisher<Bool, Never>, controller: ScreenLockingResourceController) {
        self.controller = controller

        isLockingDisabledPublisher = isUploading.combineLatest(isVisibleSubject)
            .map { $0 && $1 }
            .removeDuplicates()
            .eraseToAnyPublisher()

        isLockingDisabledPublisher
            .sink { $0 ? controller.disableLock() : controller.enableLock() }
            .store(in: &cancellables)
    }

    public func setVisible(_ isVisible: Bool) {
        isVisibleSubject.send(isVisible)
    }

    deinit {
        controller.enableLock()
    }
}
