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

final class FileTypeAsset {
    typealias FileTypeID = String
    
    static var shared = FileTypeAsset()

    private(set) var bag: [FileTypeID: FileAssetName] = [:]

    func getAsset(_ id: FileTypeID) -> FileTypeID {
        guard let fileAsset = bag[id] else {
            return searchAssetForFile(id: id).rawValue
        }

        return fileAsset.rawValue
    }

    private func searchAssetForFile(id: FileTypeID) -> FileAssetName {
        let newAsset = assetForMimeTypeDidPass(mimeTypeString: id)
        bag[id] = newAsset
        return newAsset
    }

    private func assetForMimeTypeDidPass(mimeTypeString: FileTypeID) -> FileAssetName {
        let mimeType = MimeType(value: mimeTypeString)

        if mimeType.value == "Folder" {
            return .folder
        }

        if let asset = types[mimeType] {
            return asset
        }

        if mimeType.isImage {
            return .image
        }

        if mimeType.isVideo {
            return .video
        }

        if mimeType.isAudio {
            return .audio
        }

        if mimeType.isText {
            return .text
        }

        return .unknown
    }

    private let types: [MimeType: FileAssetName] = [
        .abw: .word,
        .arc: .compressed,
        .azw: .unknown,
        .bin: .unknown,
        .bz: .compressed,
        .bz2: .compressed,
        .cda: .audio,
        .csh: .text,
        .css: .text,
        .csv: .excel,
        .doc: .word,
        .docx: .word,
        .eot: .font,
        .epub: .unknown,
        .gz: .compressed,
        .html: .xml,
        .ics: .calendar,
        .jar: .compressed,
        .js: .text,
        .json: .text,
        .jsonld: .unknown,
        .mpkg: .compressed,
        .odp: .powerpoint,
        .ods: .excel,
        .odt: .word,
        .ogx: .audio,
        .otf: .font,
        .pdf: .pdf,
        .php: .text,
        .ppt: .powerpoint,
        .pptx: .powerpoint,
        .rar: .compressed,
        .rtf: .word,
        .sh: .text,
        .swf: .unknown,
        .tar: .compressed,
        .ttf: .font,
        .txt: .text,
        .vsd: .image,
        .woff: .font,
        .woff2: .font,
        .xhtml: .xml,
        .xls: .excel,
        .xlsx: .excel,
        .xml: .xml,
        .xul: .unknown,
        .zip: .compressed,
        .sevenZ: .compressed,

        .pages: .pages,
        .numbers: .numbers,
        .keynote: .keynote
    ]

    enum FileAssetName: String {
        case folder = "ic-file-folder"
        case image = "ic-file-image"
        case video = "ic-file-video"
        case audio = "ic-file-sound"
        case text = "ic-text"

        case pages = "ic-file-pages"
        case numbers = "ic-file-numbers"
        case keynote = "ic-file-keynote"

        case word = "ic-file-word"
        case excel = "ic-file-excel"
        case powerpoint = "ic-file-powerpoint"

        case pdf = "ic-file-pdf"
        case compressed = "ic-file-rar-zip"
        case xml = "ic-file-xml"
        case font = "ic-file-font"
        case unknown = "ic-file-default"

        case calendar = "ic-calendar-event"
    }
}
