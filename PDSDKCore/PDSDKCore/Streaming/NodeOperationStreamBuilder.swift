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

import CoreData
import Foundation
import ProtonDriveSDK

protocol NodeBatchOperationPerforming {
    func trash(
        nodes: [SDKNodeUid],
        cancellationToken: UUID,
        onNodeResult: @escaping NodeResultCallback
    ) async throws

    func restore(
        nodes: [SDKNodeUid],
        cancellationToken: UUID,
        onNodeResult: @escaping NodeResultCallback
    ) async throws

    func delete(
        nodes: [SDKNodeUid],
        cancellationToken: UUID,
        onNodeResult: @escaping NodeResultCallback
    ) async throws
}

extension ProtonDriveClient: NodeBatchOperationPerforming {}
extension ProtonPhotosClient: NodeBatchOperationPerforming {}

struct NodeOperationStreamBuilder {
    static func makeNodeOperationStream(
        metadataUpdater: MetadataUpdaterProtocol,
        client: some NodeBatchOperationPerforming,
        operation: NodeBatchOperation,
        nodes: [SDKNodeUid],
        cancellationToken: UUID,
        moc: NSManagedObjectContext
    ) -> AsyncThrowingStream<NodeOperationStreamEvent, Error> {
        NodeOperationStreamEngine(metadataUpdater: metadataUpdater).stream(
            operation: operation,
            nodes: nodes,
            cancellationToken: cancellationToken,
            moc: moc,
            invoke: { token, onNodeResult in
                switch operation {
                case .trash:
                    try await client.trash(nodes: nodes, cancellationToken: token, onNodeResult: onNodeResult)
                case .restore:
                    try await client.restore(nodes: nodes, cancellationToken: token, onNodeResult: onNodeResult)
                case .delete:
                    try await client.delete(nodes: nodes, cancellationToken: token, onNodeResult: onNodeResult)
                }
            }
        )
    }
}
