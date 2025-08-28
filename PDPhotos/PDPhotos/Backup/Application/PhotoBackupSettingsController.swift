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
import Foundation

public enum PhotoLibraryMediaType {
    case image
    case video
    case audio
    case unknown
}

public protocol PhotoBackupSettingsController {
    var isEnabled: AnyPublisher<Bool, Never> { get }
    var isNetworkConstrained: AnyPublisher<Bool, Never> { get }
    var supportedMediaTypes: CurrentValueSubject<[PhotoLibraryMediaType], Never> { get }
    var notOlderThan: CurrentValueSubject<Date, Never> { get }
    var isTagsAnalysisDisabled: AnyPublisher<Bool, Never> { get }
    var isEXIFUploadingDisabled: AnyPublisher<Bool, Never> { get }
    func setEnabled(_ isEnabled: Bool)
    func setImageEnabled(_ isEnabled: Bool)
    func setVideoEnabled(_ isEnabled: Bool)
    func setNotOlderThan(_ date: Date)
    func setTagsAnalysisDisabled(_ isDisabled: Bool)
    func setIsEXIFUploadingDisabled(_ isDisabled: Bool)
    func setNetworkConnectionConstrained(_ isConstrained: Bool)
}
