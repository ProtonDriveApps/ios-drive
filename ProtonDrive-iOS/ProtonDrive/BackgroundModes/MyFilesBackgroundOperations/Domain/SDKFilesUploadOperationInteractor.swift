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
import PDCoreIOS
import Combine

@MainActor
final class SDKFilesUploadOperationInteractor: @MainActor OperationInteractor {
    private let uploader: SDKFileUploaderProtocol
    private var cancellables = Set<AnyCancellable>()
    private var subject = PassthroughSubject<Void, Never>()

    var updatePublisher: AnyPublisher<Void, Never> {
        subject.eraseToAnyPublisher()
    }

    var state: OperationInteractorState = .idle

    init(uploader: SDKFileUploaderProtocol) {
        self.uploader = uploader
        subscribeToUpdates()
    }

    private func subscribeToUpdates() {
        cancellables.removeAll()
        uploader.progresses
            .sink(receiveCompletion: { [weak self] _ in
                self?.subscribeToUpdates()
            }, receiveValue: { [weak self] progresses in
                self?.handle(isUploading: !progresses.isEmpty)
            })
            .store(in: &cancellables)
    }

    private func handle(isUploading: Bool) {
        let newState: OperationInteractorState = isUploading ? .running : .idle
        guard state != newState else {
            return
        }
        state = newState
        subject.send()
    }

    func start() {
        // no-op. Would be used only is BG download would be enabled (it's not supported)
        // Resume after app is foregrounded is already wired up in `InterruptedUploadsInteractor`
    }

    func cancel() {
        guard state == .running else {
            return
        }

        Log.info("Pausing uploads since going to background", domain: .sdk)
        Task { @MainActor in
            await uploader.pauseAll()
        }
    }
}
