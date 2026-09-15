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
import Combine
import PDClient

public protocol DriveFeatureFlagsProvider: ExternalFeatureFlagsResource {
    var updatePublisher: AnyPublisher<Void, Never> { get }
    func startAsync() async throws

    #if DEBUG
    func enable(flag: ExternalFeatureFlag)
    func disable(flag: ExternalFeatureFlag)
    #endif
}

final class DefaultDriveFeatureFlagsProvider: DriveFeatureFlagsProvider {
    private let externalResource: ExternalFeatureFlagsResource
    private let legacyResource: ExternalFeatureFlagsResource
    private let cache: FeatureFlagCache
    private var cancellables = Set<AnyCancellable>()
    private var firstUpdateCancellable: AnyCancellable?
    private var subject = PassthroughSubject<Void, Never>()

    var updatePublisher: AnyPublisher<Void, Never> {
        subject.eraseToAnyPublisher()
    }

    init(
        externalResource: ExternalFeatureFlagsResource,
        legacyResource: ExternalFeatureFlagsResource,
        cache: FeatureFlagCache
    ) {
        self.externalResource = externalResource
        self.cache = cache
        self.legacyResource = legacyResource

        setupStoreUpdates()
    }

    func setupStoreUpdates() {
        externalResource.updatePublisher
            .combineLatest(legacyResource.updatePublisher)
            .sink { [weak self] _, _ in
                self?.handleUpdate()
            }
            .store(in: &cancellables)
    }

    private func handleUpdate() {
        var messages: [String] = ["⛳️ FeatureFlag updated"]
        for externalFlag in ExternalFeatureFlag.allCases {
            let isEnabled = isRemoteEnabled(flag: externalFlag)
            var payload: String?
            if externalFlag.hasPayload {
                payload = getVariantPayload(for: externalFlag)
            }
            messages.append("Flag: \(externalFlag) value: \(isEnabled), payload: \(payload ?? "empty")")
            cache.setFeatureValue(externalFlag, value: isEnabled, payload: payload)
        }
        Log.info(messages.joined(separator: "\n"), domain: .featureFlags)
        subject.send()
    }

    func isEnabled(flag: ExternalFeatureFlag) -> Bool {
        cache.isFeatureEnabled(flag)
    }

    private func isRemoteEnabled(flag: ExternalFeatureFlag) -> Bool {
        if flag == .ratingIOSDrive {
            return legacyResource.isEnabled(flag: flag)
        } else {
            return externalResource.isEnabled(flag: flag)
        }
    }

    func startAsync() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            // We need to handle just first callback (either error or update) and make sure not to call
            // continuation multiple times.
            // The `completionBlock` from `externalResource` can be called multiple times, it's design of 3rd party
            // library.
            var continuation: CheckedContinuation<Void, any Error>? = continuation
            firstUpdateCancellable = updatePublisher
                .first()
                .sink(receiveValue: { _ in
                    continuation?.resume()
                    continuation = nil
                })

            start { error in
                if let error {
                    self.firstUpdateCancellable = nil
                    continuation?.resume(throwing: error)
                    continuation = nil
                }
            }
        }
    }

    func start(completionHandler: @escaping (Error?) -> Void) {
        let group = DispatchGroup()
        var observedError: Error?
        group.enter()
        legacyResource.start { error in
            if let error {
                observedError = error
            }
            group.leave()
        }

        group.enter()
        externalResource.start { error in
            if let error {
                observedError = error
            }
            group.leave()
        }

        group.notify(queue: DispatchQueue.global()) {
            completionHandler(observedError)
        }
    }

    func stop() {
        externalResource.stop()
        legacyResource.stop()
    }

    func getVariantPayload(for flag: ExternalFeatureFlag) -> String? {
        externalResource.getVariantPayload(for: flag)
    }
}

#if DEBUG
extension DefaultDriveFeatureFlagsProvider {
    func enable(flag: ExternalFeatureFlag) {
        cache.setFeatureValue(flag, value: true, payload: nil)
    }

    func disable(flag: ExternalFeatureFlag) {
        cache.setFeatureValue(flag, value: false, payload: nil)
    }
}
#endif
