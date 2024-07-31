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
import PDCore

enum BootstrapStatus {
    case photosRootNotReady
    case bootstrapping
    case bootstrapped
    case bootstrapError
}

final class MonitoringBootstrapController: PhotosBootstrapController {

    private let interactor: PhotosBootstrapInteractor
    private let repository: PhotosBootstrapRepository
    private var status: BootstrapStatus = .photosRootNotReady
    private let errorSubject = PassthroughSubject<Error, Never>()

    private var cancellable: AnyCancellable?

    init(
        interactor: PhotosBootstrapInteractor,
        repository: PhotosBootstrapRepository
    ) {
        self.interactor = interactor
        self.repository = repository
    }

    var isReady: AnyPublisher<Bool, Never> {
        repository.isPhotosRootReady
    }
    
    var errorPublisher: AnyPublisher<Error, Never> {
        errorSubject.eraseToAnyPublisher()
    }

    func bootstrap() {
        guard cancellable == nil else {
            switch status {
            case .bootstrapError:
                bootstrapPhotos()
            default:
                break
            }
            return
        }
        cancellable = repository.isPhotosRootReady
            .removeDuplicates()
            .sink { [weak self] isReady in
                guard !isReady else { return }
                self?.status = .bootstrapping
                self?.bootstrapPhotos()
            }
    }

    private func bootstrapPhotos() {
        Task {
            do {
                try await interactor.bootstrap()
                await MainActor.run {
                    status = .bootstrapped
                }
                
            } catch {
                await MainActor.run {
                    errorSubject.send(error)
                    status = .bootstrapError
                }
                // Unify errors to be displayed to the user
                Log.error("Bootstrap photos experienced error: \(error.localizedDescription)", domain: .photosProcessing)
            }
        }
    }

}
