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
import PDCore

protocol MetadataControllerProtocol {
    var readyIDs: AnyPublisher<Set<AnyVolumeIdentifier>, Never> { get }
    var failedIDs: AnyPublisher<Set<AnyVolumeIdentifier>, Never> { get }

    func loadOpportunistically(_ identifiers: [AnyVolumeIdentifier])
    func loadImmediatelly(_ identifiers: [AnyVolumeIdentifier], forceToRefresh: Bool)
    func cancel(identifier: AnyVolumeIdentifier)
}

final class MetadataController: MetadataControllerProtocol {
    @Published private var identifiers: [AnyVolumeIdentifier] = []
    private let debounceResource: CombineDebounceResource
    private let readySubject = PassthroughSubject<Set<AnyVolumeIdentifier>, Never>()
    private let failedIDsSubject = PassthroughSubject<Set<AnyVolumeIdentifier>, Never>()
    private let repository: RemoteMetadataFetchRepositoryProtocol
    private var cancellables = Set<AnyCancellable>()

    var readyIDs: AnyPublisher<PhotoIdsSet, Never> {
        readySubject.receive(on: DispatchQueue.main).eraseToAnyPublisher()
    }

    var failedIDs: AnyPublisher<PhotoIdsSet, Never> {
        failedIDsSubject.eraseToAnyPublisher()
    }

    init(
        debounceResource: CombineDebounceResource,
        repository: RemoteMetadataFetchRepositoryProtocol
    ) {
        self.debounceResource = debounceResource
        self.repository = repository
        subscribeForUpdates()
    }

    /// Load metadata if it doesn't exist in cache
    /// Call when view appear
    func loadOpportunistically(_ identifiers: [AnyVolumeIdentifier]) {
        identifiers.forEach(append)
    }

    private func append(identifier: AnyVolumeIdentifier) {
        // Handle scrolling from top to bottom and back to top.
        if let idx = identifiers.firstIndex(of: identifier) {
            // Eliminate duplicate elements in the set
            identifiers.remove(at: idx)
        }
        // Add the most recently viewed item to the set.
        identifiers.append(identifier)
    }

    func loadImmediatelly(_ identifiers: [AnyVolumeIdentifier], forceToRefresh: Bool) {
        fetchMetadata(for: identifiers, forceToRefresh: forceToRefresh)
    }

    /// Call when view disappear
    func cancel(identifier: AnyVolumeIdentifier) {
        if let idx = identifiers.firstIndex(of: identifier) {
            identifiers.remove(at: idx)
        }
    }

    private func subscribeForUpdates() {
        debounceResource
            .debounce(
                publisher: $identifiers.eraseToAnyPublisher(),
                for: .milliseconds(100),
                scheduler: DispatchQueue.main
            )
            .filter { !$0.isEmpty }
            .sink(receiveValue: { [weak self] identifiers in
                self?.identifiers = []
                self?.fetchMetadata(for: identifiers, forceToRefresh: false)
            })
            .store(in: &cancellables)
    }

    private func fetchMetadata(for identifiers: [AnyVolumeIdentifier], forceToRefresh: Bool) {
        Task { [weak self] in
            await self?.fetchMetadata(for: identifiers, shouldRetry: true, forceToRefresh: forceToRefresh)
        }
    }

    private func fetchMetadata(for identifiers: [AnyVolumeIdentifier], shouldRetry: Bool, forceToRefresh: Bool) async {
        Log.info("Fetch metadata for: \(identifiers)", domain: .metadata)
        do {
            let linkIDs = try await repository.fetch(identifiers: identifiers, forceToRefresh: forceToRefresh)
            readySubject.send(Set(linkIDs))
        } catch {
            Log.error(error: error, domain: .metadata)
            if shouldRetry {
                await fetchMetadata(for: identifiers, shouldRetry: false, forceToRefresh: forceToRefresh)
            } else {
                await MainActor.run { [weak self] in
                    self?.failedIDsSubject.send(Set(identifiers))
                }
            }
        }
    }
}
