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

protocol PhotosSettingsViewModelProtocol: ObservableObject {
    var backupTitle: String { get }
    var mobileDataTitle: String { get }
    var imageTitle: String { get }
    var videoTitle: String { get }
    var isEnabled: Bool { get }
    var isMobileDataEnabled: Bool { get }
    var isNotOlderThanEnabled: Bool { get }
    var notOlderThanTitle: String { get }
    var notOlderThan: Date { get }
    var diagnosticsTitle: String { get }
    func setEnabled(_ isEnabled: Bool)
    func setMobileDataEnabled(_ isEnabled: Bool)
    var isVideoEnabled: Bool { get }
    func setVideoEnabled(_ isEnabled: Bool)
    var isImageEnabled: Bool { get }
    func setImageEnabled(_ isEnabled: Bool)
    func setIsNotOlderThanEnabled(_ isEnabled: Bool)
    func setNotOlderThan(_ date: Date)
}

final class PhotosSettingsViewModel: PhotosSettingsViewModelProtocol {
    private let settingsController: PhotoBackupSettingsController
    private let startController: PhotosBackupStartController

    let backupTitle = "Photos backup"
    let mobileDataTitle = "Use mobile data to backup photos"
    let imageTitle = "Backup Images"
    let videoTitle = "Backup Videos"
    let notOlderThanTitle = "Items since"
    let diagnosticsTitle = "Open diagnostics"
    @Published var isEnabled = false
    @Published var isMobileDataEnabled = false
    @Published var isImageEnabled = false
    @Published var isVideoEnabled = false
    @Published var notOlderThan = Date.distantPast

    init(settingsController: PhotoBackupSettingsController, startController: PhotosBackupStartController) {
        self.settingsController = settingsController
        self.startController = startController
        subscribeToUpdates()
    }
    
    var isNotOlderThanEnabled: Bool {
        notOlderThan != .distantPast
    }

    private func subscribeToUpdates() {
        settingsController.isEnabled
            .assign(to: &$isEnabled)
        settingsController.isNetworkConstrained
            .map { !$0 }
            .assign(to: &$isMobileDataEnabled)
        settingsController.supportedMediaTypes
            .map { $0.contains(.image) }
            .assign(to: &$isImageEnabled)
        settingsController.supportedMediaTypes
            .compactMap { $0.contains(.video) }
            .assign(to: &$isVideoEnabled)
        settingsController.notOlderThan
            .assign(to: &$notOlderThan)
    }

    func setEnabled(_ isEnabled: Bool) {
        if isEnabled {
            startController.start()
        } else {
            settingsController.setEnabled(isEnabled)
        }
    }

    func setMobileDataEnabled(_ isEnabled: Bool) {
        let isConstrained = !isEnabled
        settingsController.setNetworkConnectionConstrained(isConstrained)
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
}
