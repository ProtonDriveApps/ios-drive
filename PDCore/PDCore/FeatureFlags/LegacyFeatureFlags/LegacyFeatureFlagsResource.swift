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

import Combine
import Foundation
import PDClient
import class ProtonCoreUtilities.Atomic

// Feature flags we used before migrating to Unleash
// These legacy FFs are more akin to user settings
final class LegacyFeatureFlagsResource: ExternalFeatureFlagsResource {
    private let updateSubject = PassthroughSubject<Void, Never>()
    private let configuration: APIService.Configuration
    private let networking: CoreAPIService
    private let refreshInterval: TimeInterval
    private var timer: Timer?
    private lazy var decoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .driveImplementationOfDecapitaliseFirstLetter
        return decoder
    }()
    private var ratingIOSDrive = Atomic<Bool>(false)

    var updatePublisher: AnyPublisher<Void, Never> {
        updateSubject
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    init(
        configuration: APIService.Configuration,
        networking: CoreAPIService,
        refreshInterval: TimeInterval
    ) {
        self.configuration = configuration
        self.networking = networking
        self.refreshInterval = refreshInterval
    }
    
    func start(completionHandler: @escaping ((any Error)?) -> Void) {
        timer?.invalidate()
        let timer = Timer(timeInterval: refreshInterval, repeats: true) { [weak self] _ in
            self?.getLegacyFF()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        getLegacyFF()
        completionHandler(nil)
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
    }
    
    func isEnabled(flag: PDClient.ExternalFeatureFlag) -> Bool {
        if flag != .ratingIOSDrive {
            assert(false, "Unrecognized legacy FF")
        }
        return ratingIOSDrive.value
    }
}

extension LegacyFeatureFlagsResource {
    @objc
    private func getLegacyFF() {
        let request = GetLegacyRatingIOSEndpoint()
        networking.perform(request: request, callCompletionBlockUsing: .immediateExecutor) { [weak self] _, result in
            guard let self else { return }
            switch result {
            case .success(let responseDict):
                guard
                    let responseData = try? JSONSerialization.data(
                        withJSONObject: responseDict,
                        options: .prettyPrinted
                    ),
                    let response = try? decoder.decode(GetLegacyRatingIOSResponse.self, from: responseData)
                else { return }
                self.ratingIOSDrive.mutate { $0 = response.feature.value }
                updateSubject.send()
            case .failure(let failure):
                updateSubject.send()
                Log.error("Fetch legacy FF failed", error: failure, domain: .featureFlags)
            }
        }
    }
}
