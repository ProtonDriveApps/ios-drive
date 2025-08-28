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
import PDCoreIOS

protocol PhotosGalleryPlaceholderViewModelProtocol: ObservableObject {
    var title: String { get }
    var tag: PhotoTag? { get }
    var tagTitle: String { get }
    var tagMessage: String { get }
    var tagIdentifier: String { get }

    func didAppear()
    func didDisappear()
}

final class PhotosGalleryPlaceholderViewModel: PhotosGalleryPlaceholderViewModelProtocol {
    let tag: PhotoTag?
    private let timerFactory: TimerFactory
    private var timerPublisher: AnyCancellable?
    private var flag = true

    @Published var title: String = ""

    init(timerFactory: TimerFactory, tag: PhotoTag?) {
        self.timerFactory = timerFactory
        self.tag = tag
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

    var tagTitle: String {
        switch tag {
        case .favorites:
            return Localization.empty_favorites_title
        case .screenshots:
            return Localization.empty_screenshots_title
        case .videos:
            return Localization.empty_videos_title
        case .livePhotos:
            return Localization.empty_live_photo_title
        case .motionPhotos:
            return "No Motion Photos" // We don't show motion
        case .selfies:
            return Localization.empty_selfie_title
        case .portraits:
            return Localization.empty_portraits_title
        case .bursts:
            return Localization.empty_bursts_title
        case .panoramas:
            return Localization.empty_panoramas_title
        case .raw:
            return Localization.empty_raw_title
        case nil:
            return Localization.empty_photos_title
        }
    }

    var tagMessage: String {
        switch tag {
        case .favorites:
            return Localization.empty_favorites_message
        case .screenshots:
            return Localization.empty_screenshots_message
        case .videos:
            return Localization.empty_videos_message
        case .livePhotos:
            return Localization.empty_live_photo_message
        case .motionPhotos:
            return "No Motion Photos" // We don't show motion
        case .selfies:
            return Localization.empty_selfie_message
        case .portraits:
            return Localization.empty_portraits_message
        case .bursts:
            return Localization.empty_bursts_message
        case .panoramas:
            return Localization.empty_panoramas_message
        case .raw:
            return Localization.empty_raw_message
        case nil:
            return ""
        }
    }

    var tagIdentifier: String {
        if let tag {
            let uiTag = PhotoUITag.existing(tag)
            return uiTag.identifier
        } else {
            return "all"
        }
    }
}
