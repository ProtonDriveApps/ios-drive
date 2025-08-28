// Copyright (c) 2025 Proton AG
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
import PDCore
import PDLocalization

public struct NodeSubtitleFactory {
    private static var timeIntervalFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()

    public init() {}

    public func makeSubtitle(for node: Node, at date: Date = Date()) -> String? {
        switch node {
        case is File:
            let size = ByteCountFormatter.storageSizeString(forByteCount: Int64(node.size))
            let modified = node.modifiedDate
            if modified >= date {
                return Localization.file_detail_subtitle_moments_ago(size: size)
            } else {
                let lastModified = NodeSubtitleFactory.timeIntervalFormatter.localizedString(for: node.modifiedDate, relativeTo: date)
                return "\(size) | \(lastModified)"
            }
        case is Folder:
            return nil
        default:
            assert(false, "Undefined node type")
            return Localization.file_detail_general_title
        }
    }
}
