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
import PDCore

final class AsynchronousPhotoVolumeMigrationUpdateFacade: PhotoVolumeMigrationUpdateFacade {
    private let interactor: PhotoVolumeMigrationStatusInteractorProtocol
    private let subject = PassthroughSubject<PhotoVolumeMigrationUpdateResult, Never>()
    private var task: Task<Void, Never>?

    var result: AnyPublisher<PhotoVolumeMigrationUpdateResult, Never> {
        subject.eraseToAnyPublisher()
    }

    init(interactor: PhotoVolumeMigrationStatusInteractorProtocol) {
        self.interactor = interactor
    }

    deinit {
        task?.cancel()
    }

    func startObserving() {
        task = Task { [weak self] in
            await self?.getStatus()
        }
    }

    private func getStatus(attempt: Int = 0) async {
        guard !Task.isCancelled else {
            return
        }

        do {
            let status = try await interactor.getStatus()
            switch status {
            case .inProgress:
                Log.info("Photo share migration still in progress", domain: .albums)
                try await Task.sleep(for: .seconds(10))
                await getStatus()
            case .finished, .noPhotoVolume:
                Log.info("Photo share migration finished: \(status)", domain: .albums)
                await notifyResult(.success)
            }
        } catch {
            Log.error(error: error, domain: .albums)
            try? await Task.sleep(for: .seconds(10 + ExponentialBackoffWithJitter.getDelay(attempt: attempt)))
            await getStatus(attempt: attempt + 1)
        }
    }

    @MainActor
    private func notifyResult(_ result: PhotoVolumeMigrationUpdateResult) {
        subject.send(result)
    }
}
