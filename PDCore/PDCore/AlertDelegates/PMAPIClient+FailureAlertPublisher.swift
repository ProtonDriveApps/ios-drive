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

extension PMAPIClient {
    public var failureAlertPublisher: AnyPublisher<DriveCoreAlert, Never> {
        self.publisher(for: \.currentActivity)
            .compactMap { Self.mapToFailingAlert($0) }
            .eraseToAnyPublisher()
    }

    public static func mapToFailingAlert(_ activity: NSUserActivity?) -> DriveCoreAlert? {
        switch activity {
        case PMAPIClient.Activity.logout:
            return .logout

        case PMAPIClient.Activity.trustKitFailureHard:
            return .trustKitHardFailure

        case PMAPIClient.Activity.trustKitFailure:
            return .trustKitFailure

        case PMAPIClient.Activity.humanVerification:
            return .humanVerification

        case PMAPIClient.Activity.forceUpgrade:
            return .forceUpgrade

        default:
            return nil
        }
    }
}
