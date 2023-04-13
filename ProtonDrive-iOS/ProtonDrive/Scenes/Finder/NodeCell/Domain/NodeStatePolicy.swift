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

protocol NodeStatePolicy {
    func isUploadWaiting(for node: Node) -> Bool
    func isUploadPaused(for node: Node) -> Bool
    func isUploadFailed(for node: Node, progressTracker: ProgressTracker?, areProgressesAvailable: Bool) -> Bool
}

final class FileNodeStatePolicy: NodeStatePolicy {
    func isUploadWaiting(for node: Node) -> Bool {
        return node.state == .cloudImpediment
    }

    func isUploadPaused(for node: Node) -> Bool {
        return [Node.State.paused, .interrupted].contains(node.state)
    }

    func isUploadFailed(for node: Node, progressTracker: ProgressTracker?, areProgressesAvailable: Bool) -> Bool {
        guard !isUploadPaused(for: node) && !isUploadWaiting(for: node) else {
            return false
        }

        guard node.state == .uploading || (node as? File)?.uploadID != nil else {
            return false
        }

        return progressTracker?.progress == nil && areProgressesAvailable
    }
}

final class DisabledNodeStatePolicy: NodeStatePolicy {
    func isUploadWaiting(for node: Node) -> Bool {
        return false
    }

    func isUploadPaused(for node: Node) -> Bool {
        return false
    }

    func isUploadFailed(for node: Node, progressTracker: ProgressTracker?, areProgressesAvailable: Bool) -> Bool {
        return false
    }
}
