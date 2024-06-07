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
import PDClient
import Combine

class URLSessionContentUploader: NSObject, ContentUploader, URLSessionTaskDelegate {
    typealias Service = APIService

    let progressTracker: Progress

    var session: URLSession!
    var task: URLSessionUploadTask?

    private(set) var isCancelled = false
    private var cancellables = Set<AnyCancellable>()

    init(progressTracker: Progress) {
        self.progressTracker = progressTracker
        super.init()

        subscribeToProgressTrackerCancellation()
    }

    /// Override this property with the proper upload actions
    func upload(completion: @escaping Completion) {

    }

    func cancel() {
        guard !isCancelled else { return }
        isCancelled = true

        cleanSession()
    }

    func cleanSession() {
        cleanTask()
        session?.invalidateAndCancel()
        session = nil
    }

    private func cleanTask() {
        task?.progress.cancel()
        task?.cancel()
        task = nil
    }

    private func subscribeToProgressTrackerCancellation() {
        progressTracker.publisher(for: \.isCancelled)
            .sink { [weak self] isCancelled in
                guard isCancelled else { return }
                self?.cancel()
            }.store(in: &cancellables)
    }

    struct InvalidRepresentationError: LocalizedError {}
}
