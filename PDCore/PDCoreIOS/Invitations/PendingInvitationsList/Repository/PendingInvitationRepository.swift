// Copyright (c) 2024 Proton AG
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

protocol PendingInvitationRepositoryProtocol {
    func fetchAllInvitations() async throws

    func getPendingInvitationsIds() -> AnyPublisher<[String], Never>
}

final class PendingInvitationRepository: PendingInvitationRepositoryProtocol {
    private let scanner: PendingInvitationsScannerProtocol
    private let observer: FetchedResultsControllerObserver<Invitation>

    public init(
        scanner: PendingInvitationsScannerProtocol,
        observer: FetchedResultsControllerObserver<Invitation>
    ) {
        self.scanner = scanner
        self.observer = observer
    }

    func fetchAllInvitations() async throws {
        try await scanner.scan()
    }

    func getPendingInvitationsIds() -> AnyPublisher<[String], Never> {
        observer.getPublisher()
            .map { $0.map(\.id) }
            .eraseToAnyPublisher()
    }
}
