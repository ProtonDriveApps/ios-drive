// Copyright (c) 2026 Proton AG
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

final class PhotosGridZoomController: ObservableObject {
    enum Command {
        case zoomIn
        case zoomOut
    }

    @Published private(set) var canZoomIn = true
    @Published private(set) var canZoomOut = true

    private(set) var columns: Int?

    private let commandSubject = PassthroughSubject<Command, Never>()
    var commands: AnyPublisher<Command, Never> { commandSubject.eraseToAnyPublisher() }

    func setColumns(_ columns: Int) {
        self.columns = columns
    }

    func zoomIn() {
        commandSubject.send(.zoomIn)
    }

    func zoomOut() {
        commandSubject.send(.zoomOut)
    }

    func setLimits(canZoomIn: Bool, canZoomOut: Bool) {
        if self.canZoomIn != canZoomIn {
            self.canZoomIn = canZoomIn
        }
        if self.canZoomOut != canZoomOut {
            self.canZoomOut = canZoomOut
        }
    }
}
