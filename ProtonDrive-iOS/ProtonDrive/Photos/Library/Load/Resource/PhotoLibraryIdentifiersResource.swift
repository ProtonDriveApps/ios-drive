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

import PDCore
import Combine

enum PhotoLibraryLoadUpdate: Equatable {
    case fullLoad(PhotoIdentifiers)
    case update(PhotoIdentifiers)
    case loading

    var identifiers: PhotoIdentifiers {
        switch self {
        case .fullLoad(let identifiers):
            return identifiers
        case .update(let identifiers):
            return identifiers
        case .loading:
            return []
        }
    }
}

protocol PhotoLibraryIdentifiersResource {
    var updatePublisher: AnyPublisher<PhotoLibraryLoadUpdate, Never> { get }
    func execute()
    func cancel()
    func suspend()
    func resume()
}
