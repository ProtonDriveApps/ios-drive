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

import Foundation
import PDCore
import Combine
import PDSDKCoreiOS

@MainActor
final class SDKFilesDownloadOperationInteractor: @MainActor OperationInteractor {
    private let downloader: SDKFileDownloaderProtocol
    private var cancellables = Set<AnyCancellable>()
    private var subject = PassthroughSubject<Void, Never>()

    var updatePublisher: AnyPublisher<Void, Never> {
        subject.eraseToAnyPublisher()
    }

    var state: OperationInteractorState = .idle

    init(downloader: SDKFileDownloaderProtocol) {
        self.downloader = downloader
        subscribeToUpdates()
    }

    private func subscribeToUpdates() {
        downloader.isActivePublisher
            .sink { [weak self] isDownloading in
                self?.handle(isDownloading: isDownloading)
            }
            .store(in: &cancellables)
    }

    private func handle(isDownloading: Bool) {
        state = isDownloading ? .running : .idle
        subject.send()
    }

    func start() {
        // no-op. Would be used only is BG download would be enabled (it's not supported)
    }

    func cancel() {
        guard state == .running else {
            return
        }

        Log.info("Cancelling downloads since going to background", domain: .sdk)
        downloader.cancelAll() // TODO(SDK): replace by pause & resume when possible. For now we need to cancel to avoid crashes.
    }
}
