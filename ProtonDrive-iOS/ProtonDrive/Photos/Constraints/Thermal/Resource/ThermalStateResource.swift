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

enum ThermalState {
    case normal
    case warning
}

protocol ThermalStateResource {
    var state: AnyPublisher<ThermalState, Never> { get }
}

final class ProcessThermalStateResource: ThermalStateResource {
    private let subject = PassthroughSubject<ThermalState, Never>()

    var state: AnyPublisher<ThermalState, Never> {
        subject.eraseToAnyPublisher()
    }

    init() {
        NotificationCenter.default.addObserver(forName: ProcessInfo.thermalStateDidChangeNotification, object: nil, queue: nil) { [weak self] _ in
            self?.update()
        }
        update()
    }

    private func update() {
        let state = makeState(from: ProcessInfo.processInfo.thermalState)
        DispatchQueue.main.async { [weak self] in
            self?.subject.send(state)
        }
    }

    private func makeState(from state: ProcessInfo.ThermalState) -> ThermalState {
        switch state {
        case .nominal, .fair:
            return .normal
        case .serious, .critical:
            return .warning
        @unknown default:
            return .normal
        }
    }
}
