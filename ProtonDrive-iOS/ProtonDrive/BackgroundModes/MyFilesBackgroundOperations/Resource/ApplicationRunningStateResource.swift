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
import UIKit

public enum ApplicationRunningState {
    case background
    case foreground
}

protocol ApplicationRunningStateResource {
    var state: AnyPublisher<ApplicationRunningState, Never> { get }
}

final class ApplicationRunningStateResourceImpl: ApplicationRunningStateResource {
    let state: AnyPublisher<ApplicationRunningState, Never>
    
    init() {
        let foregroundPublisher = NotificationCenter.default.publisher(
            for: UIApplication.willEnterForegroundNotification)
            .map { _ -> ApplicationRunningState in return .foreground }
        let backgroundPublisher = NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .map { _ -> ApplicationRunningState in return .background }
        let appStatePublisher = Publishers.Merge(foregroundPublisher, backgroundPublisher)
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
        self.state = appStatePublisher
    }
}
