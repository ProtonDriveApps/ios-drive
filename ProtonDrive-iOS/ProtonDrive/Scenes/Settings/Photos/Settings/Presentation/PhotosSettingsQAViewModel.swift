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

import Foundation
import Combine
import PDCore
import PDLocalization
import PDPhotos

protocol PhotosSettingsQAViewModelProtocol: ObservableObject {
    var diagnosticsTitle: String { get }

    var imageTitle: String { get }
    var videoTitle: String { get }
    var notOlderThanTitle: String { get }

    var isImageEnabled: Bool { get }
    var isVideoEnabled: Bool { get }
    var isNotOlderThanEnabled: Bool { get }
    var notOlderThan: Date { get }

    var isEnabled: Bool { get }
    var isPhotoFeatureDisabled: Bool { get }

    func setImageEnabled(_ isEnabled: Bool)
    func setVideoEnabled(_ isEnabled: Bool)
    func setIsNotOlderThanEnabled(_ isEnabled: Bool)
    func setNotOlderThan(_ date: Date)

    var isTagsAnalysisDisabledTitle: String { get }
    var tagsAnalysisDescription: String { get }
    var isTagsAnalysisDisabled: Bool { get }
    func setIsTagsAnalysisDisabled(_ isDisabled: Bool)

    var isEXIFUploadingDisabledTitle: String { get }
    var exifUploadingDescription: String { get }
    var isEXIFUploadingDisabled: Bool { get }
    func setIsEXIFUploadingDisabled(_ isDisabled: Bool)
}

final class PhotosSettingsQAViewModel: PhotosSettingsQAViewModelProtocol {
    private let settingsController: PhotoBackupSettingsController
    private var cancellables = Set<AnyCancellable>()

    let imageTitle = "Backup Images"
    let videoTitle = "Backup Videos"
    let notOlderThanTitle = "Items since"
    let isTagsAnalysisDisabledTitle = "Disable tags analysis"
    let tagsAnalysisDescription = "Set this ON if you don't want tags to be sent during backup. (Note: it also affects tags-migration process)"
    let isEXIFUploadingDisabledTitle = "Disable exif uploading"
    let exifUploadingDescription = "Set this ON if you don't want EXIF to be sent during backup. (Note: relaunch app is needed after updating this value"
    let diagnosticsTitle = "Open diagnostics"

    @Published var isImageEnabled = false
    @Published var isVideoEnabled = false
    @Published var notOlderThan: Date = .distantPast
    @Published var isEnabled: Bool = false
    @Published var isPhotoFeatureDisabled: Bool = false
    @Published var isTagsAnalysisDisabled: Bool = false
    @Published var isEXIFUploadingDisabled: Bool = false

    init(
        settingsController: PhotoBackupSettingsController
    ) {
        self.settingsController = settingsController
        subscribe(settingsController: settingsController)
    }

    private func subscribe(
        settingsController: PhotoBackupSettingsController
    ) {
        settingsController.isEnabled
            .assign(to: &$isEnabled)
        settingsController.supportedMediaTypes
            .map { $0.contains(.image) }
            .assign(to: &$isImageEnabled)
        settingsController.supportedMediaTypes
            .map { $0.contains(.video) }
            .assign(to: &$isVideoEnabled)
        settingsController.notOlderThan
            .assign(to: &$notOlderThan)
        settingsController.isTagsAnalysisDisabled
            .assign(to: &$isTagsAnalysisDisabled)
        settingsController.isEXIFUploadingDisabled
            .assign(to: &$isEXIFUploadingDisabled)
    }

    var isNotOlderThanEnabled: Bool {
        notOlderThan != .distantPast
    }

    func setImageEnabled(_ isEnabled: Bool) {
        settingsController.setImageEnabled(isEnabled)
    }

    func setVideoEnabled(_ isEnabled: Bool) {
        settingsController.setVideoEnabled(isEnabled)
    }

    func setIsNotOlderThanEnabled(_ isEnabled: Bool) {
        settingsController.setNotOlderThan(isEnabled ? .now : .distantPast)
    }

    func setNotOlderThan(_ date: Date) {
        settingsController.setNotOlderThan(date)
    }

    func setIsTagsAnalysisDisabled(_ isDisabled: Bool) {
        settingsController.setTagsAnalysisDisabled(isDisabled)
    }

    func setIsEXIFUploadingDisabled(_ isDisabled: Bool) {
        settingsController.setIsEXIFUploadingDisabled(isDisabled)
    }
}
