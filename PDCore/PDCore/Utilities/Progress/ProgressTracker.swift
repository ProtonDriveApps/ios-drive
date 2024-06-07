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
import Combine

public class ProgressTracker {
    public enum Direction { case upstream, downstream }
    
    public private(set) var progress: Progress?
    public let direction: Direction
    
    internal init(operation: OperationWithProgress, direction: Direction) {
        self.progress = operation.progress
        self.direction = direction
    }

    public init(progress: Progress, direction: Direction) {
        self.progress = progress
        self.direction = direction
    }
    
    // this publisher is used by NodeCells in iOS application. Cells can not unsubscribe when progress disappears, so we can not make reference to progress weak because of that
    public func progressPublisher() -> AnyPublisher<Double, Never>? {
        self.progress?.publisher(for: \.fractionCompleted)
            .eraseToAnyPublisher()
    }
}

public extension ProgressTracker {
    func matches(_ uploadID: URL?) -> Bool {
        self.id == uploadID?.path && uploadID != nil
    }
    
    func matches(_ downloadID: String?) -> Bool {
        self.id == downloadID && downloadID != nil
    }
    
    var id: String? {
        return self.progress?.fileURL?.path
    }
}

extension ProgressTracker: Hashable, Equatable {
    public static func == (lhs: ProgressTracker, rhs: ProgressTracker) -> Bool {
        lhs.progress == rhs.progress
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.id)
    }
}
