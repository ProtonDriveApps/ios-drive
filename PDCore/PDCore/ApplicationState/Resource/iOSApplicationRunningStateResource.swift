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

#if os(iOS)
import Combine
import UIKit

public final class iOSApplicationRunningStateResource: ApplicationRunningStateResource {
    public var state: AnyPublisher<ApplicationRunningState, Never> {
        makePublisher()
    }

    public init() {}

    public func getState() -> ApplicationRunningState {
        switch UIApplication.shared.applicationState {
        case .active:
            return .foreground
        case .background:
            return .background
        case .inactive:
            // Can happen due to race condition during transition or perhaps during extension BG mode.
            return .background
        @unknown default:
            Log.error("Unknown application state", error: nil, domain: .application)
            return .foreground
        }
    }

    private func makePublisher() -> AnyPublisher<ApplicationRunningState, Never> {
        let foregroundPublisher = NotificationCenter.default.publisher(
            for: UIApplication.willEnterForegroundNotification)
            .map { _ -> ApplicationRunningState in return .foreground }
        let backgroundPublisher = NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .map { _ -> ApplicationRunningState in return .background }
        return Publishers.Merge(foregroundPublisher, backgroundPublisher)
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
}
#endif
