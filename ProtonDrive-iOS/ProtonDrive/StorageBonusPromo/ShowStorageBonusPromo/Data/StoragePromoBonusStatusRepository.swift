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

import Foundation
import Combine
import PDCore
import PDClient

final class StoragePromoBonusStatusRepository: StorageBonusPromoStatusRepositoryProtocol {
    private let localSettings: LocalSettings
    private let remoteDataSource: DriveChecklistDataSource
    private let dateResource: DateResource

    private var cancellables = Set<AnyCancellable>()
    private let storageStatusSubject = CurrentValueSubject<StorageBonusPromoStatus, Never>(.notAvailable)

    init(remoteDataSource: DriveChecklistDataSource, localSettings: LocalSettings, dateResource: DateResource) {
        self.remoteDataSource = remoteDataSource
        self.localSettings = localSettings
        self.dateResource = dateResource
        observeChecklistData()
        updateStatus(from: localSettings.driveChecklistStatusData)
    }

    var status: StorageBonusPromoStatus {
        storageStatusSubject.value
    }

    var publisher: AnyPublisher<StorageBonusPromoStatus, Never> {
        storageStatusSubject
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    public func fetchStoragePromoStatus() async throws {
        let response = try await remoteDataSource.getDriveChecklist()
        let data = try JSONEncoder().encode(response)
        localSettings.driveChecklistStatusData = data
    }

    private func observeChecklistData() {
        localSettings
            .publisher(for: \.driveChecklistStatusData)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] data in
                self?.updateStatus(from: data)
            }
            .store(in: &cancellables)
    }

    private func updateStatus(from data: Data) {
        if data.isEmpty {
            Log.info("Checklist data is empty", domain: .application)
            storageStatusSubject.send(.notAvailable)
            return
        }

        do {
            let checklist = try JSONDecoder().decode(DriveChecklistStatusResponse.self, from: data)
            storageStatusSubject.send(StorageBonusPromoStatus(checklist: checklist))
        } catch {
            let dataString = String(data: data, encoding: .utf8) ?? "Response data can't be parsed"
            Log.error(dataString, error: error, domain: .application)
            storageStatusSubject.send(.notAvailable)
        }
    }
}

extension StorageBonusPromoStatus {
    init(checklist: DriveChecklistStatusResponse) {
        expirationDate = checklist.expiresAt
        didReceiveBonus = checklist.userWasRewarded || checklist.completed
        fulfilledSteps = checklist.items
    }
}
