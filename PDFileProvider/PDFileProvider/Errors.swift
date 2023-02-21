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
import FileProvider
import PDCore

public enum Errors: Error, LocalizedError {
    case noMainShare
    case nodeNotFound
    case rootNotFound
    case revisionNotFound
    
    case parentNotFound
    case emptyUrlForFileUpload
    case noAddressInTower
    case couldNotProduceSyncAnchor
    
    case requestedItemForWorkingSet, requestedItemForTrash
    case failedToCreateModel
    
    public var errorDescription: String? {
        String(describing: self)
    }
}

extension Errors {
    public static func mapToFileProviderError(_ error: Error?) -> NSFileProviderError? {
        if let error = error {
            ConsoleLogger.shared?.fireWarning(error: error)
        }
        
        switch error {
        case .none: return nil
            
        case .some(Errors.rootNotFound),
             .some(Errors.noMainShare): return NSFileProviderError(.syncAnchorExpired)
            
        case .some(Errors.parentNotFound): return NSFileProviderError(.noSuchItem)
        case .some(Errors.nodeNotFound): return NSFileProviderError(.noSuchItem)
        case .some(Errors.requestedItemForWorkingSet): return NSFileProviderError(.noSuchItem)
        case .some(Errors.requestedItemForTrash): return NSFileProviderError(.noSuchItem)
        case .some(Errors.noAddressInTower): return NSFileProviderError(.notAuthenticated)
        case .some(Errors.emptyUrlForFileUpload): return NSFileProviderError(.noSuchItem)
        case .some(Errors.couldNotProduceSyncAnchor): return NSFileProviderError(.syncAnchorExpired)
        case .some(Errors.failedToCreateModel): return NSFileProviderError(.pageExpired)
            
        case let .some(networkingError as NSError) where networkingError.domain == NSURLErrorDomain:
            return NSFileProviderError(.serverUnreachable)
            
        default:
            return NSFileProviderError(.noSuchItem)
        }
    }
}
