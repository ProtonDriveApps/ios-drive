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
    case nodeIdentifierNotFound
    case nodeNotFound
    case rootNotFound
    case revisionNotFound
    
    case parentNotFound
    case childLimitReached
    case urlForUploadIsNil
    case urlForUploadHasNoSize
    case urlForUploadFailedCopying
    case noAddressInTower
    case couldNotProduceSyncAnchor
    
    case requestedItemForWorkingSet, requestedItemForTrash
    case failedToCreateModel

    case itemCannotBeCreated
    case itemDeleted
    case itemTrashed
    case conflictIdentified(reason: String)
    case deletionRejected(updatedItem: NSFileProviderItem)

    case invalidFilename(filename: String)

    case excludeFromSync

    public var errorDescription: String? {
        switch self {
        case .noMainShare: return "No main share"
        case .nodeIdentifierNotFound: return "Item identifier not found"
        case .nodeNotFound: return "Item not found"
        case .rootNotFound: return "Root not found for domain"
        case .revisionNotFound: return "Revision not found for item"
        case .parentNotFound: return "Parent not found for item"
        case .childLimitReached: return "Folder limit reached. Organize items into subfolders to continue syncing."
        case .urlForUploadIsNil: return "No URL for file upload"
        case .urlForUploadHasNoSize: return "File under URL for file upload has no size"
        case .urlForUploadFailedCopying: return "File under URL for file upload cannot be processed"
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
        case .invalidFilename(let filename):
            return "Invalid filename: \(filename)"
        case .excludeFromSync:
#if os(macOS)
            return "This item is excluded from sync"
#else
            return NSFileProviderError(.noSuchItem).localizedDescription // "The file doesn’t exist."
#endif
        }
    }
}

extension Errors {
    public static func mapToFileProviderError(_ error: Error?) -> Error? {
        
        guard let error else { return nil }
        
#if os(iOS)
        Log.fireWarning(error: error as NSError)
#endif
        Log.error(error: error, domain: .fileProvider, sendToSentryIfPossible: false)
        
        switch error {
            
        case let fileProviderError as NSFileProviderError: return fileProviderError
        case let cocoaError as CocoaError where cocoaError.code == .userCancelled: return cocoaError
            
        case Errors.rootNotFound, Errors.noMainShare:
            return NSFileProviderError.create(.syncAnchorExpired, from: error)
        case Errors.childLimitReached:
            return NSFileProviderError.create(.serverUnreachable, from: error)
        case Errors.parentNotFound,
            Errors.nodeIdentifierNotFound,
            Errors.nodeNotFound,
            Errors.requestedItemForWorkingSet,
            Errors.requestedItemForTrash:
            return NSFileProviderError.create(.noSuchItem, from: error)
        case Errors.noAddressInTower:
            #if os(macOS)
            return NSFileProviderError.create(.notAuthenticated, from: error)
            #else
            return CrossProcessErrorExchange.notAuthenticatedError
            #endif
        case Errors.urlForUploadIsNil, Errors.urlForUploadHasNoSize, Errors.urlForUploadFailedCopying:
#if os(macOS)
            return NSFileProviderError.create(.cannotSynchronize, from: error)
#else
            return NSFileProviderError(.noSuchItem)
#endif
        case Errors.failedToCreateModel:
            return NSFileProviderError.create(.pageExpired, from: error)
        case Errors.conflictIdentified:
            return NSFileProviderError.create(.serverUnreachable, from: error)
        case Errors.deletionRejected(updatedItem: let updatedItem):
            return NSFileProviderError(_nsError: NSError.fileProviderErrorForRejectedDeletion(of: updatedItem))
        case Errors.excludeFromSync:
#if os(macOS)
            if #available(macOS 13, *) {
                return NSFileProviderError.create(.excludedFromSync, from: error)
            } else {
                return NSFileProviderError.create(.cannotSynchronize, from: error)
            }
#else
            return NSFileProviderError(.noSuchItem)
#endif
            
        case let responseError as ResponseError
            where responseError.responseCode == APIErrorCodes.protonDocumentCannotBeCreatedFromMacOSAppErrorCode.rawValue:
            return NSFileProviderError.create(.excludedFromSync, from: error)
            
        case is ResponseError:
            return NSFileProviderError.create(.serverUnreachable, from: error)
            
        case is InvalidLinkIdError:
            return NSFileProviderError.create(.serverUnreachable, from: error)
            
        default:
#if os(macOS)
            return NSFileProviderError.create(.cannotSynchronize, from: error)
#else
            return NSFileProviderError(.noSuchItem)
#endif
        }
    }
}

public extension NSFileProviderError {
    static func create(_ status: NSFileProviderError.Code, from error: Swift.Error?) -> Self {
        guard let error else {
            return NSFileProviderError(status)
        }
        return NSFileProviderError(
            status,
            userInfo: [
                NSDebugDescriptionErrorKey: "FP error code: \(status). Original error: \(error.localizedDescription)",
                NSUnderlyingErrorKey: error
            ]
        )
    }
}
