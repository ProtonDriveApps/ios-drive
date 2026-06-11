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

struct KeyValue: Identifiable {
    var id: String {
        key
    }

    let key: String
    let value: String

    init(key: String, value: String) {
        self.key = key
        self.value = value
    }

    init?(key: String, value: String?) {
        guard let value else {
            return nil
        }
        self.key = key
        self.value = value
    }
}

class NodeDetailsViewModel: ObservableObject {
    struct QADetails {
        let attributes: [KeyValue]
        let extendedAttributes: [KeyValue]
    }

    var node: Node
    var tower: Tower
    var qaDetails: QADetails?

    internal init(tower: Tower, node: Node) {
        self.tower = tower
        self.node = node
        initializeQaDetails()
    }
    
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
    
    lazy var details: [KeyValue] = {
        if let file = node as? File {
            return makeFileDetails(with: file)
        } else if node is Folder {
            return detailsFolder
        } else {
            assert(false, "Undefined node type")
            return []
        }
    }()

    private func makeFileDetails(with file: File) -> [KeyValue] {
        var details = self.detailsFolder
        details.append(contentsOf: [
            .init(key: Localization.file_detail_extension, value: self.fileExtension ?? "－")
        ])
        if !file.isProtonFile {
            details.append(contentsOf: [
                .init(key: Localization.file_detail_size, value: ByteCountFormatter.storageSizeString(forByteCount: Int64(file.size)))
            ])
        }
        let shareStatus: String
        if file.isNodeShared() {
            shareStatus = Localization.file_detail_share_yes
        } else {
            shareStatus = Localization.file_detail_share_no
        }
        details.append(contentsOf: [
            .init(key: Localization.file_detail_shared, value: shareStatus)
        ])
        return details
    }
    
    lazy var detailsFolder: [KeyValue] = [
        .init(key: Localization.file_detail_name, value: node.decryptedName),
        .init(key: Localization.file_detail_uploaded_by, value: self.editorAddress),
        .init(key: Localization.file_detail_location, value: self.path),
        .init(key: Localization.file_detail_modified, value: Self.dateFormatter.string(from: node.modifiedDate))
    ]

    lazy var fileExtension: String? = { [unowned self] in
        guard let fileUTI = UTType(tag: self.node.mimeType, tagClass: .mimeType, conformingTo: nil) else { return nil }
        return fileUTI.preferredFilenameExtension
    }()
    
    lazy var editorAddress: String = {
        guard let signatureEmail = node.signatureEmail, !signatureEmail.isEmpty else {
            return Localization.file_detail_uploaded_by_anonymous
        }
        guard let address = self.tower.sessionVault.getAddress(for: signatureEmail) else {
            return signatureEmail
        }
        if address.displayName.isEmpty {
            return "\(address.email)"
        } else {
            return "\(address.displayName)\n\(address.email)"
        }
    }()
    
    lazy var path: String = {
        var path = [node.parentNode?.decryptedName ?? ""]
        var parent = node.parentNode
        while let next = parent?.parentNode {
            path.append(next.decryptedName)
            parent = next
        }
        
        return "/" + path.reversed().dropFirst().joined(separator: "/")
    }()

    private func initializeQaDetails() {
        guard Constants.buildType.isQaOrBelow else {
            return
        }

        guard let file = node as? File else {
            return
        }

        // Doesn't need localization, since it's only for dev/QA builds
        qaDetails = QADetails(
            attributes: [
                KeyValue(key: "Key author", value: file.signatureEmail ?? ""),
                KeyValue(key: "Name author", value: file.nameSignatureEmail ?? ""),
                KeyValue(key: "Content author", value: file.activeRevision?.signatureAddress ?? ""),
                KeyValue(key: "MIME type", value: file.mimeType),
            ],
            extendedAttributes: makeExtendedAttributes(file: file)
        )
    }

    private func makeExtendedAttributes(file: File) -> [KeyValue] {
        if file.isProtonFile { return [] }
        guard let revision = file.activeRevision else {
            assertionFailure("Active revision is nil")
            return []
        }

        do {
            let attributes = try revision.decryptedExtendedAttributes()
            let floatingStyle = FloatingPointFormatStyle<Double>().precision(.fractionLength(2))

            var array = [KeyValue?]()
            if let common = attributes.common {
                let blockSizes = (common.blockSizes ?? []).map { ByteCountFormatter.storageSizeString(forByteCount: Int64($0)) }
                let clearSize = common.size.map { ByteCountFormatter.storageSizeString(forByteCount: Int64($0)) }
                array += [
                    KeyValue(key: "Block sizes", value: blockSizes.joined(separator: ", ")),
                    KeyValue(key: "Original size", value: clearSize),
                    KeyValue(key: "SHA1", value: common.digests?.sha1 ?? ""),
                ]
                if let modificationTime = common.modificationTime {
                    let modificationTimeDate = ISO8601DateFormatter.default.date(modificationTime)
                    let formattedTime = modificationTimeDate.map { Self.dateFormatter.string(from: $0) }
                    array += [
                        KeyValue(key: "Modified (in xAttr)", value: formattedTime ?? ""),
                    ]
                }
            }
            if let location = attributes.location {
                array += [
                    KeyValue(key: "Longitude", value: location.longitude.formatted(floatingStyle)),
                    KeyValue(key: "Latitude", value: location.latitude.formatted(floatingStyle)),
                ]
            }
            if let camera = attributes.camera {
                let coordinates = camera.subjectCoordinates.map { subjectCoordinates in
                    "top: \(subjectCoordinates.top), left: \(subjectCoordinates.left), bottom: \(subjectCoordinates.bottom), right: \(subjectCoordinates.right)"
                }
                array += [
                    KeyValue(key: "Device", value: camera.device),
                    KeyValue(key: "Orientation", value: camera.orientation.map(String.init)),
                    KeyValue(key: "Subject Coordinates", value: coordinates),
                ]
            }
            if let media = attributes.media {
                array += [
                    KeyValue(key: "Duration", value: media.duration?.formatted(floatingStyle)),
                    KeyValue(key: "Height", value: media.height?.formatted()),
                    KeyValue(key: "Width", value: media.width?.formatted()),
                ]
            }
            return array.compactMap { $0 }
        } catch {
            assertionFailure("Couldn't decrypt extended attributes")
            return []
        }
    }
}
