// Copyright (c) 2025 Proton AG
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
import PDCoreIOS
import PDCore

protocol GalleryTagsControllerProtocol {
    var updatePublisher: AnyPublisher<Void, Never> { get }
    func getAvailableTags() -> [PhotoTag]
    func store(availableTags: [PhotoTag])
    func select(tag: PhotoTag?)
    func getSelectedTag() -> PhotoTag?
}

final class GalleryTagsController: GalleryTagsControllerProtocol {
    private let subject = PassthroughSubject<Void, Never>()
    private var tags = PhotoTag.defaultCases
    private var selectedTag: PhotoTag?
    private let featureFlagsController: FeatureFlagsControllerProtocol
    private let localSettings: LocalSettings
    private var cancellables = Set<AnyCancellable>()

    init(featureFlagsController: FeatureFlagsControllerProtocol, localSettings: LocalSettings) {
        self.featureFlagsController = featureFlagsController
        self.localSettings = localSettings
        subscribe()
    }

    var updatePublisher: AnyPublisher<Void, Never> {
        subject.eraseToAnyPublisher()
    }

    private func subscribe() {
        localSettings
            .publisher(for: \.tagsMigrationFinished)
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.subject.send()
            }
            .store(in: &cancellables)
    }

    func getAvailableTags() -> [PhotoTag] {
        if featureFlagsController.hasPhotosTagsMigration && localSettings.tagsMigrationFinished == true {
            return PhotoTag.iOSDefaultCases
        } else {
            return PhotoTag.defaultCases
        }
    }

    // Is this used for something?
    func store(availableTags: [PhotoTag]) {
        tags = availableTags
        if let selectedTag, !availableTags.contains(selectedTag) {
            self.selectedTag = nil
        }
        subject.send()
    }

    func select(tag: PhotoTag?) {
        selectedTag = tag
    }

    func getSelectedTag() -> PhotoTag? {
        selectedTag
    }
}
