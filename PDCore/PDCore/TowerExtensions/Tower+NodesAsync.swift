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
import CoreData

// MARK: - Async functions
extension Tower {

    public func createFolder(named name: String, under parent: Folder, moc: NSManagedObjectContext) async throws -> Folder {
        return try await withCheckedThrowingContinuation { continuation in
            createFolder(named: name, under: parent, moc: moc) { result in
                switch result {
                case .success(let folder):
                    continuation.resume(returning: folder)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    public func rename(node: NodeIdentifier, cleartextName newName: String, mimeType: String? = nil, moc: NSManagedObjectContext) async throws -> Node {
        return try await withCheckedThrowingContinuation { continuation in
            rename(node: node, cleartextName: newName, mimeType: mimeType, moc: moc) { result in
                switch result {
                case .success(let node):
                    continuation.resume(returning: node)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    public func move(nodeID nodeIdentifier: NodeIdentifier, under newParent: Folder, withNewName newName: String? = nil, moc: NSManagedObjectContext) async throws -> Node {
        return try await withCheckedThrowingContinuation { continuation in
            move(nodeID: nodeIdentifier, under: newParent, with: newName, moc: moc) { result in
                switch result {
                case .success(let node):
                    return continuation.resume(returning: node)
                case .failure(let error):
                    return continuation.resume(throwing: error)
                }
            }
        }
    }
    
    public func delete(nodeID nodeIdentifier: NodeIdentifier, moc: NSManagedObjectContext) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            delete([nodeIdentifier], moc: moc) { result in
                switch result {
                case .success:
                    return continuation.resume(with: .success)
                case .failure(let error):
                    return continuation.resume(with: .failure(error))
                }
            }
        } as Void
    }
}
