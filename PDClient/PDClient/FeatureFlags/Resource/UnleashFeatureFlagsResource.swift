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
import Foundation
import UnleashProxyClientSwift

public final class UnleashFeatureFlagsResource: ExternalFeatureFlagsResource {

    private let session: UnleashPollerSession
    private let configurationResolver: ExternalFeatureFlagConfigurationResolver
    private var poller: Poller?
    private var client: UnleashClient?
    private let updateSubject = PassthroughSubject<Void, Never>()
    private let refreshInterval: Int
    private var cancellables = Set<AnyCancellable>()

    public var updatePublisher: AnyPublisher<Void, Never> {
        updateSubject
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    public init(
        refreshInterval: Int,
        session: UnleashPollerSession,
        configurationResolver: ExternalFeatureFlagConfigurationResolver
    ) {
        self.refreshInterval = refreshInterval
        self.session = session
        self.configurationResolver = configurationResolver
    }

    public func start(completionHandler: @escaping (Error?) -> Void) {
        guard client == nil else {
            completionHandler(Errors.clientAlreadyStarted)
            return
        }

        guard let configuration = try? configurationResolver.makeConfiguration(refreshInterval: refreshInterval) else {
            logError?(Errors.unableToFetchConfiguration.localizedDescription)
            completionHandler(Errors.unableToFetchConfiguration)
            return
        }

        poller = Poller(refreshInterval: configuration.refreshInterval, unleashUrl: configuration.url, apiKey: configuration.apiKey, session: session, appName: "Proton Drive", connectionId: UUID())
        client = UnleashClient(unleashUrl: configuration.url.absoluteString, clientKey: configuration.apiKey, refreshInterval: configuration.refreshInterval, disableMetrics: true, environment: configuration.environment, poller: poller)

        startClient(completionHandler: completionHandler)
        subscribeToUpdates()
    }

    public func stop() {
        client?.unsubscribe(name: "update")
        client?.unsubscribe(name: "ready")
        client?.stop()
        client = nil
    }

    private func startClient(completionHandler: @escaping (Error?) -> Void) {
        // The client must be started from the main thread, because it sets up a timer and adds it
        // into the default run loop of the thread. If started from some short-living thread (like a one spun by
        // the Swift Concurrency executor for some detached Task), the timer won't repeat.
        DispatchQueue.main.async { [weak self] in
            self?.client?.start { error in
                completionHandler(error)
                if let error {
                    logError?(error.localizedDescription)
                } else {
                    logInfo?("Unleash started")
                }
            }
        }
    }

    private func subscribeToUpdates() {
        client?.subscribe(name: "update") { [weak self] in
            logInfo?("Unleash feature flags: updated")
            self?.updateSubject.send()
        }
        client?.subscribe(name: "ready") { [weak self] in
            logInfo?("Unleash feature flags: ready")
            self?.updateSubject.send()
        }
    }

    public func forceUpdate(on publisher: AnyPublisher<Void, Never>) {
        publisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let poller = self?.poller, let client = self?.client else { return }

                // Important: `start(context:)` should be called on main queue
                // because poller schedules timer on `RunLoop.current` under the hood
                poller.stop()
                poller.start(context: client.context)
            }
            .store(in: &cancellables)
    }

    public func isEnabled(flag: ExternalFeatureFlag) -> Bool {
        let name = flag.rawValue
        return client?.isEnabled(name: name) ?? false
    }

    enum Errors: String, LocalizedError {
        case clientAlreadyStarted = "Feature flag client already started"
        case unableToFetchConfiguration = "Unable to get refresh interval from the configuration"

        var errorDescription: String? { rawValue }
    }
}
