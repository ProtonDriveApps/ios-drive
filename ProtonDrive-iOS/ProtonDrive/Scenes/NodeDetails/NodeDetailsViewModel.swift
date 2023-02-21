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

import Combine
import PDCore
import UniformTypeIdentifiers

class NodeDetailsViewModel: ObservableObject {
    struct NodeDetailViewModel: Identifiable {
        var id: String
        var value: String
    }
    
    var node: Node
    var tower: Tower
    
    internal init(tower: Tower, node: Node) {
        self.tower = tower
        self.node = node
    }
    
    static func subtitle(for node: Node, at date: Date = Date()) -> String? {
        switch node {
        case is File:
            let size = self.sizeFormatter.string(fromByteCount: Int64(node.size))
            let modified = node.modifiedDate
            if modified >= date {
                return "\(size) | Moments ago"
            } else {
                let lastModified = self.timeIntervalFormatter.localizedString(for: node.modifiedDate, relativeTo: date)
                return "\(size) | \(lastModified)"
            }
        case is Folder:
            return nil
        default:
            assert(false, "Undefined node type")
            return "Details"
        }
    }
    
    private static var timeIntervalFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()
    
    private static var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .short
        return formatter
    }()
    
    private static var sizeFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        formatter.formattingContext = .standalone
        formatter.allowsNonnumericFormatting = true
        formatter.zeroPadsFractionDigits = false
        formatter.includesUnit = true
        formatter.isAdaptive = false
        return formatter
    }()
    
    lazy var title: String = {
        switch self.node {
        case is File:   return "File details"
        case is Folder: return "Folder details"
        default:
            assert(false, "Undefined node type")
            return "Details"
        }
    }()
    
    lazy var details: [NodeDetailViewModel] = {
        switch self.node {
        case is File:   return self.detailsFile
        case is Folder: return self.detailsFolder
        default:
            assert(false, "Undefined node type")
            return []
        }
    }()
    
    lazy var detailsFile: [NodeDetailViewModel] = {
        var details = self.detailsFolder
        details.append(contentsOf: [
            .init(id: "Extension", value: self.fileExtension ?? "－"),
            .init(id: "Size", value: Self.sizeFormatter.string(fromByteCount: Int64(node.size))),
            .init(id: "Shared", value: self.node.isShared ? "Yes" : "No")
        ])
        return details
    }()
    
    lazy var detailsFolder: [NodeDetailViewModel] = [
        .init(id: "Name", value: node.decryptedName),
        .init(id: "Uploaded by", value: self.editorAddress),
        .init(id: "Location", value: self.path),
        .init(id: "Modified", value: Self.dateFormatter.string(from: node.modifiedDate))
    ]
    
    lazy var fileExtension: String? = { [unowned self] in
        guard let fileUTI = UTType(tag: self.node.mimeType, tagClass: .mimeType, conformingTo: nil) else { return nil }
        return fileUTI.preferredFilenameExtension
    }()
    
    lazy var editorAddress: String = {
        guard let address = self.tower.sessionVault.getAddress(for: node.signatureEmail) else { return "－" }
        if address.displayName.isEmpty {
            return "\(address.email)"
        } else {
            return "\(address.displayName)\n\(address.email)"
        }
    }()
    
    lazy var path: String = {
        var path = [node.parentLink?.decryptedName ?? ""]
        var parent = node.parentLink
        while let next = parent?.parentLink {
            path.append(next.decryptedName)
            parent = next
        }
        
        return "/" + path.reversed().dropFirst().joined(separator: "/")
    }()
}
