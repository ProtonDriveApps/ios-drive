// Copyright (c) 2026 Proton AG
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
import PDCore

protocol ProgressTrackersControllerProtocol {
    func getPublisher(for ids: [String]) -> AnyPublisher<ProgressTracker?, Never>
    func getDownloadsPublisher() -> AnyPublisher<Void, Never>
    func getUploadProgress(for uploadId: String) -> ProgressTracker?
    func setDownloads(progresses: ProgressTrackers)
    func setUploads(progresses: ProgressTrackers)
    func hasUploads() -> Bool
}

final class ProgressTrackersController: ProgressTrackersControllerProtocol {
    private var downloads = CurrentValueSubject<ProgressTrackers, Never>([:])
    private var uploads = CurrentValueSubject<ProgressTrackers, Never>([:])

    func getPublisher(for ids: [String]) -> AnyPublisher<ProgressTracker?, Never> {
        downloads.combineLatest(uploads)
            .map { downloads, uploads in
                downloads.first(where: { ids.contains($0.key) })?.value ??
                uploads.first(where: { ids.contains($0.key) })?.value
            }
            .removeDuplicates(by: {
                // Only publish when different instance is pushed (or when nil becomes nonnil and vice versa)
                ($0 == nil && $1 == nil) || ($0?.progress === $1?.progress)
            })
            .eraseToAnyPublisher()
    }

    func getDownloadsPublisher() -> AnyPublisher<Void, Never> {
        downloads
            .map { _ in Void() }
            .eraseToAnyPublisher()
    }

    func getUploadProgress(for uploadId: String) -> ProgressTracker? {
        uploads.value.first(where: { $0.key == uploadId })?.value
    }

    func setDownloads(progresses: ProgressTrackers) {
        downloads.send(progresses)
    }

    func setUploads(progresses: ProgressTrackers) {
        uploads.send(progresses)
    }

    func hasUploads() -> Bool {
        !uploads.value.isEmpty
    }
}
