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
import PDCore

protocol PhotoBackupSettingsController {
    var isEnabled: AnyPublisher<Bool, Never> { get }
    var isNetworkConstrained: AnyPublisher<Bool, Never> { get }
    var supportedMediaTypes: CurrentValueSubject<[PhotoLibraryMediaType], Never> { get }
    var notOlderThan: CurrentValueSubject<Date, Never> { get }
    func setEnabled(_ isEnabled: Bool)
    func setImageEnabled(_ isEnabled: Bool)
    func setVideoEnabled(_ isEnabled: Bool)
    func setNotOlderThan(_ date: Date)
}

final class LocalPhotoBackupSettingsController: PhotoBackupSettingsController {
    
    private let localSettings: LocalSettings
    private let isEnabledSubject: CurrentValueSubject<Bool, Never>
    private let isConstrainedSubject: CurrentValueSubject<Bool, Never>
    private let supportedMediaTypesSubject: CurrentValueSubject<[PhotoLibraryMediaType], Never>
    private let notOlderThanSubject: CurrentValueSubject<Date, Never>
    private var cancellables = Set<AnyCancellable>()

    var isEnabled: AnyPublisher<Bool, Never> {
        isEnabledSubject.eraseToAnyPublisher()
    }

    var isNetworkConstrained: AnyPublisher<Bool, Never> {
        isConstrainedSubject.eraseToAnyPublisher()
    }
    
    var supportedMediaTypes: CurrentValueSubject<[PhotoLibraryMediaType], Never> {
        supportedMediaTypesSubject
    }
    
    var notOlderThan: CurrentValueSubject<Date, Never> {
        notOlderThanSubject
    }

    init(localSettings: LocalSettings) {
        self.localSettings = localSettings
        isEnabledSubject = .init(localSettings.isPhotosBackupEnabled)
        isConstrainedSubject = .init(localSettings.isPhotosBackupConnectionConstrained)
        supportedMediaTypesSubject = .init(Self.map(imageSupported: localSettings.isPhotosMediaTypeImageSupported, videoSupported: localSettings.isPhotosMediaTypeVideoSupported))
        notOlderThanSubject = .init(.distantPast)
        subscribeToUpdates()
    }

    private func subscribeToUpdates() {
        localSettings.publisher(for: \.isPhotosBackupEnabled)
            .sink { [weak self] value in
                self?.isEnabledSubject.send(value)
            }
            .store(in: &cancellables)
        localSettings.publisher(for: \.isPhotosBackupConnectionConstrained)
            .sink { [weak self] value in
                self?.isConstrainedSubject.send(value)
            }
            .store(in: &cancellables)
        localSettings.publisher(for: \.isPhotosMediaTypeImageSupported)
            .combineLatest(localSettings.publisher(for: \.isPhotosMediaTypeVideoSupported))
            .compactMap(Self.map(imageSupported:videoSupported:))
            .sink { [weak self] value in
                self?.supportedMediaTypesSubject.send(value)
            }
            .store(in: &cancellables)
        localSettings.publisher(for: \.photosBackupNotOlderThan)
            .sink { [weak self] value in
                self?.notOlderThanSubject.send(value)
            }
            .store(in: &cancellables)
    }
    
    private static func map(imageSupported: Bool, videoSupported: Bool) -> [PhotoLibraryMediaType] {
        var supported = [PhotoLibraryMediaType]()
        if imageSupported {
            supported.append(.image)
        }
        if videoSupported {
            supported.append(.video)
        }
        return supported
    }

    func setEnabled(_ isEnabled: Bool) {
        localSettings.isPhotosBackupEnabled = isEnabled
    }
    
    func setImageEnabled(_ isEnabled: Bool) {
        localSettings.isPhotosMediaTypeImageSupported = isEnabled
    }
    
    func setVideoEnabled(_ isEnabled: Bool) {
        localSettings.isPhotosMediaTypeVideoSupported = isEnabled
    }
    
    func setNotOlderThan(_ date: Date) {
        localSettings.photosBackupNotOlderThan = date
    }
}
