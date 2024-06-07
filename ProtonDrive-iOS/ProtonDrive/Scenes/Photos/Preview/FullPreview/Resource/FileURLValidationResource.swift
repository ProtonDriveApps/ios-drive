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

import AVFoundation
import Foundation
import PDCore
import UIKit

protocol FileURLValidationResource {
    func validate(file: File, url: URL) async throws
}

enum FileURLValidationResourceError: Error {
    case invalidURL
}

final class PhotoURLValidationResource: FileURLValidationResource {
    func validate(file: File, url: URL) async throws {
        guard let moc = file.moc else {
            throw File.noMOC()
        }

        let mimeType = moc.performAndWait { file.mimeType }
        if MimeType(value: mimeType).isVideo {
            try await validateVideo(url: url)
        } else {
            try await validateImage(url: url)
        }
    }

    private func validateVideo(url: URL) async throws {
        let isPlayable = try await AVAsset(url: url).load(.isPlayable)
        if !isPlayable {
            throw FileURLValidationResourceError.invalidURL
        }
    }

    private func validateImage(url: URL) async throws {
        let data = try Data(contentsOf: url)
        if UIImage(data: data) == nil {
            throw FileURLValidationResourceError.invalidURL
        }
    }
}
