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
import PDLocalization

class NodeDetailsViewModel: ObservableObject {
    struct NodeDetailViewModel: Identifiable {
        let id: String
        let value: String
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
            let size = ByteCountFormatter.storageSizeString(forByteCount: Int64(node.size))
            let modified = node.modifiedDate
            if modified >= date {
                return Localization.file_detail_subtitle_moments_ago(size: size)
            } else {
                let lastModified = self.timeIntervalFormatter.localizedString(for: node.modifiedDate, relativeTo: date)
                return "\(size) | \(lastModified)"
            }
        case is Folder:
            return nil
        default:
            assert(false, "Undefined node type")
            return Localization.file_detail_general_title
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
    
    lazy var title: String = {
        switch self.node {
        case is File:   return Localization.file_detail_title
        case is Folder: return Localization.folder_detail_title
        default:
            assert(false, "Undefined node type")
            return Localization.file_detail_general_title
        }
    }()
    
    lazy var details: [NodeDetailViewModel] = {
        if let file = node as? File {
            return makeFileDetails(with: file)
        } else if node is Folder {
            return detailsFolder
        } else {
            assert(false, "Undefined node type")
            return []
        }
    }()
    
    private func makeFileDetails(with file: File) -> [NodeDetailViewModel] {
        var details = self.detailsFolder
        details.append(contentsOf: [
            .init(id: Localization.file_detail_extension, value: self.fileExtension ?? "－")
        ])
        if !file.isProtonDocument {
            details.append(contentsOf: [
                .init(id: Localization.file_detail_size, value: ByteCountFormatter.storageSizeString(forByteCount: Int64(file.size)))
            ])
        }
        let shareStatus: String
        if file.isNodeShared() {
            shareStatus = Localization.file_detail_share_yes
        } else {
            shareStatus = Localization.file_detail_share_no
        }
        details.append(contentsOf: [
            .init(id: Localization.file_detail_shared, value: shareStatus)
        ])
        return details
    }
    
    lazy var detailsFolder: [NodeDetailViewModel] = [
        .init(id: Localization.file_detail_name, value: node.decryptedName),
        .init(id: Localization.file_detail_uploaded_by, value: self.editorAddress),
        .init(id: Localization.file_detail_location, value: self.path),
        .init(id: Localization.file_detail_modified, value: Self.dateFormatter.string(from: node.modifiedDate))
    ]

    lazy var fileExtension: String? = { [unowned self] in
        guard let fileUTI = UTType(tag: self.node.mimeType, tagClass: .mimeType, conformingTo: nil) else { return nil }
        return fileUTI.preferredFilenameExtension
    }()
    
    lazy var editorAddress: String = {
        guard 
            let signatureEmail = node.signatureEmail,
            let address = self.tower.sessionVault.getAddress(for: signatureEmail) else {
            return Localization.file_detail_uploaded_by_anonymous
        }
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
