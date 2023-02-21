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

// MARK: - TrashViewModel plus state definition
extension TrashViewModel {
    enum State: Equatable {
        case initial
        case empty
        case populated(ListState)

        var isEmpty: Bool {
            guard case self = State.empty else { return false }
            return true
        }

        var nextOnError: State? {
            switch self {
            case .initial, .empty:
                return .empty
            default:
                return nil
            }
        }
    }

    enum ListState: Equatable {
        case active
        case selecting
        
        var isSelecting: Bool {
            self == .selecting
        }

        var isMultipleSelectionEnabled: Bool {
            guard case .selecting = self else {
                return false
            }
            return true
        }

        mutating func togle() {
            switch self {
            case .active:
                self = .selecting
            case .selecting:
                self = .active
            }
        }
    }
}
