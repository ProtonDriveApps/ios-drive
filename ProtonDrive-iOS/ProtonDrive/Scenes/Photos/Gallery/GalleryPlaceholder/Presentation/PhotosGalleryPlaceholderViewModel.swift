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
import PDLocalization

protocol PhotosGalleryPlaceholderViewModelProtocol: ObservableObject {
    var title: String { get }
    func didAppear()
    func didDisappear()
}

final class PhotosGalleryPlaceholderViewModel: PhotosGalleryPlaceholderViewModelProtocol {
    private let timerFactory: TimerFactory
    private var timerPublisher: AnyCancellable?
    private var flag = true

    @Published var title: String = ""

    init(timerFactory: TimerFactory) {
        self.timerFactory = timerFactory
        updateTitle()
    }

    func didAppear() {
        timerPublisher = timerFactory.makeTimer(interval: 5)
            .sink { [weak self] in
                self?.flag.toggle()
                self?.updateTitle()
            }
    }

    func didDisappear() {
        timerPublisher?.cancel()
    }

    private func updateTitle() {
        title = flag ? Localization.photo_backup_banner_title_e2ee : Localization.photo_backup_banner_in_progress
    }
}
