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

import UniformTypeIdentifiers

private let DEFAULT_MIME_TYPE = "application/octet-stream"

public struct UTI {
    public let value: String
    
    /// UTI is a wrapper around a Uniform Type Identifier, the String representation of which can be accessed through the **value** field
    public init(value: String) {
        self.value = value
    }
}

extension UTI {
    /// Initializer of a **UTI** given a MIMEType
    /// - Parameter fromMimeType: String representing a MIMEType e.g.: *"application/msword"*, *"image/png"*, *"application/pdf"*...
    public init(fromMimeType mimeType: String) {
        if let uti = UTType(tag: mimeType, tagClass: .mimeType, conformingTo: nil) {
            self.value = uti.identifier
        } else {
            let dataUTI = UTType(tag: DEFAULT_MIME_TYPE, tagClass: .mimeType, conformingTo: nil)
            self.value = dataUTI!.identifier
        }
    }

    /// Initializer of a **UTI** given a file extension
    /// - Parameter fileExtension: String representing a file extension e.g.: *"doc"*, *"png"*, *"pdf"*...
    public init(fromFileExtension fileExtension: String) {
        if let uti = UTType(tag: fileExtension, tagClass: .filenameExtension, conformingTo: nil) {
            self.value = uti.identifier
        } else {
            let dataUTI = UTType(tag: DEFAULT_MIME_TYPE, tagClass: .mimeType, conformingTo: nil)
            self.value = dataUTI!.identifier
        }
    }

    /// Initializer of a **UTI** given a URL to the file
    /// - Parameter url: File url e.g.: *"file://"*, *"http://"*, *"https://"*...
    public init(url: URL) {
        if let uti = UTType(tag: url.pathExtension, tagClass: .filenameExtension, conformingTo: nil) {
            self.value = uti.identifier
        } else {
            let dataUTI = UTType(tag: DEFAULT_MIME_TYPE, tagClass: .mimeType, conformingTo: nil)
            self.value = dataUTI!.identifier
        }
    }
}

public extension UTI {
    var isImage: Bool {
        guard let type = UTType(value) else { return false }
        return type.conforms(to: .image)
    }

    var isVideo: Bool {
        guard let type = UTType(value) else { return false }
        return type.conforms(to: .movie)
    }

    var isAudio: Bool {
        guard let type = UTType(value) else { return false }
        return type.conforms(to: .audio)
    }

    var isText: Bool {
        guard let type = UTType(value) else { return false }
        return type.conforms(to: .text)
    }

    var isLivePhoto: Bool {
        guard let type = UTType(value) else { return false }
        return type.conforms(to: .livePhoto)
    }

    var isLiveAsset: Bool {
        return isLivePhoto || value == "com.apple.live-photo-bundle"
    }

    var isProtonFile: Bool {
        [ProtonDocConstants.uti, ProtonSheetConstants.uti].contains(value)
    }

    var isProtonDoc: Bool {
        value == ProtonDocConstants.uti
    }

    var isProtonSheet: Bool {
        value == ProtonSheetConstants.uti
    }

    var isGif: Bool {
        guard let type = UTType(value) else { return false }
        return type.conforms(to: .gif)
    }

    var isRawImage: Bool {
        guard let type = UTType(value) else { return false }
        return type.conforms(to: .rawImage)
    }
}
