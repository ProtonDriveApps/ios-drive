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

import Foundation
import CoreData

public protocol SDKNodeOperationPerformer {
    func rename(nodeUid: AnyVolumeIdentifier, newName: String) async throws -> Node
    func createFolder(parentFolderID: AnyVolumeIdentifier, name: String) async throws -> CoreDataFolder

    // MARK: - Trash
    func trash(nodes: [AnyVolumeIdentifier]) -> AsyncThrowingStream<SDKNodeOperationStreamEvent, Error>
    func delete(nodes: [AnyVolumeIdentifier]) -> AsyncThrowingStream<SDKNodeOperationStreamEvent, Error>
    func restore(nodes: [AnyVolumeIdentifier]) -> AsyncThrowingStream<SDKNodeOperationStreamEvent, Error>
    func emptyTrash() async throws

    // MARK: - Device
    func renameDevice(identifier: DeviceIdentifier, newName: String) async throws
}
