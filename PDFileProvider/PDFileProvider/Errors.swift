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
import PDClient
import PDCore
import ProtonCoreNetworking

public enum Errors: Error, LocalizedError {
    case noMainShare
    case nodeNotFound
    case rootNotFound
    case revisionNotFound
    
    case parentNotFound
    case childLimitReached
    case emptyUrlForFileUpload
    case noAddressInTower
    case couldNotProduceSyncAnchor
    
    case requestedItemForWorkingSet, requestedItemForTrash
    case failedToCreateModel

    case itemCannotBeCreated
    case itemDeleted
    case itemTrashed
    case conflictIdentified(reason: String)
    case deletionRejected(updatedItem: NSFileProviderItem)

    case excludeFromSync
    
    public var errorDescription: String? {
        switch self {
        case .noMainShare: return "No main share"
        case .nodeNotFound: return "Item not found"
        case .rootNotFound: return "Root not found for domain"
        case .revisionNotFound: return "Revision not found for item"
        case .parentNotFound: return "Parent not found for item"
        case .childLimitReached: return "Folder limit reached. Organize items into subfolders to continue syncing."
        case .emptyUrlForFileUpload: return "Empty URL for file upload"
        case .couldNotProduceSyncAnchor: return "Could not produce sync anchor"
        case .requestedItemForWorkingSet: return "Requesting item for WorkingSet failed"
        case .requestedItemForTrash: return "Requesting item for Trash failed"
        case .itemCannotBeCreated: return "Node found but failed to create it"
        case .itemDeleted: return "Deleted Item"
        case .itemTrashed: return "Trashed Item"
        case .conflictIdentified(reason: let reason): return "Conflict identified with following reason: \(reason)"
        case let .deletionRejected(updatedItem): // "The item cannot be deleted."
            return NSFileProviderError(_nsError: NSError.fileProviderErrorForRejectedDeletion(of: updatedItem)).localizedDescription
        case .noAddressInTower: // You need to authenticate before accessing this item.
            return NSFileProviderError(.notAuthenticated).localizedDescription
        case .failedToCreateModel:
            return "Failed to create model"
        case .excludeFromSync:
            #if os(macOS)
            return "This item is excluded from sync"
            #else
            return NSFileProviderError(.noSuchItem).localizedDescription // "The file doesn’t exist."
            #endif
        }
    }
}

// swiftlint:disable cyclomatic_complexity
extension Errors {
    public static func mapToFileProviderError(_ error: Error?) -> Error? {

        guard let error else { return nil }

        #if os(iOS)
        Log.fireWarning(error: error as NSError)
        #endif
        Log.error(error, domain: .fileProvider)

        switch error {
        
        case let fileProviderError as NSFileProviderError: return fileProviderError
        case let cocoaError as CocoaError where cocoaError.code == .userCancelled: return cocoaError
        
        case Errors.rootNotFound, Errors.noMainShare:
            return NSFileProviderError(.syncAnchorExpired)
        case Errors.parentNotFound: 
            return NSFileProviderError(.noSuchItem)
        case Errors.childLimitReached: 
            return NSFileProviderError(.serverUnreachable)
        case Errors.nodeNotFound: 
            return NSFileProviderError(.noSuchItem)
        case Errors.requestedItemForWorkingSet: 
            return NSFileProviderError(.noSuchItem)
        case Errors.requestedItemForTrash: 
            return NSFileProviderError(.noSuchItem)
        case Errors.noAddressInTower: 
            return NSFileProviderError(.notAuthenticated)
        case Errors.emptyUrlForFileUpload: 
            return NSFileProviderError(.noSuchItem)
        case Errors.failedToCreateModel: 
            return NSFileProviderError(.pageExpired)
        case Errors.conflictIdentified: 
            return NSFileProviderError(.serverUnreachable)
        case Errors.deletionRejected(updatedItem: let updatedItem):
            return NSFileProviderError(_nsError: NSError.fileProviderErrorForRejectedDeletion(of: updatedItem))
        case Errors.excludeFromSync:
            #if os(macOS)
            if #available(macOS 13, *) {
                return NSFileProviderError(.excludedFromSync)
            } else {
                return NSFileProviderError(.cannotSynchronize)
            }
            #else
            return NSFileProviderError(.noSuchItem)
            #endif
            
        case let responseError as ResponseError where responseError.responseCode == 200701:
            #if os(macOS)
            return NSFileProviderError(.excludedFromSync)
            #else
            if #available(iOS 16.0, *) {
                return NSFileProviderError(.excludedFromSync)
            } else {
                return NSFileProviderError(.noSuchItem)
            }
            #endif
            
        case is ResponseError:
            return NSFileProviderError(.serverUnreachable)
            
        case is InvalidLinkIdError:
            return NSFileProviderError(.serverUnreachable)
            
        default:
            #if os(macOS)
            return NSFileProviderError(.cannotSynchronize)
            #else
            return NSFileProviderError(.noSuchItem)
            #endif
        }
    }
}
// swiftlint:enable cyclomatic_complexity
