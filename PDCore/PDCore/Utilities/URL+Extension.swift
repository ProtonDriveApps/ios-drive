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
import UniformTypeIdentifiers

private typealias UTT = String

extension URL {
    public func mimeType() -> String {
        let pathExtension = self.pathExtension
        
        if let uti = UTType(tag: pathExtension, tagClass: .filenameExtension, conformingTo: nil),
            let type = uti.preferredMIMEType {
                return type
        }
            
        if let appleExtension = MimeType.appleExtensions[path] {
            return appleExtension.value
        }

        if let nonRecognized = MimeType.nonRecognizedExtensions[path] {
            return nonRecognized.value
        }

        return "application/octet-stream"
    }
}

private extension MimeType {
    static let appleExtensions: [UTT: MimeType] = [
        "com.apple.iwork.pages.pages": .pages,
        "com.apple.iwork.numbers.numbers": .numbers,
        "com.apple.iwork.keynote.key": .keynote,
    ]

    static let nonRecognizedExtensions: [UTT: MimeType] = [
        "abw": .abw,
        "arc": .arc,
        "azw": .azw,
        "bin": .bin,
        "bz": .bz,
        "bz2": .bz2,
        "cda": .cda,
        "csh": .csh,
        "css": .css,
        "csv": .csv,

        "eot": .eot,
        "epub": .epub,
        "gz": .gz,
        "html": .html,
        "ics": .ics,
        "jar": .jar,
        "js": .js,
        "json": .json,
        "jsonld": .jsonld,
        "mjs": .mjs,
        "mpkg": .mpkg,
        "odp": .odp,
        "ods": .ods,
        "odt": .odt,
        "ogx": .ogx,
        "otf": .otf,

        "php": .php,

        "rar": .rar,
        "rtf": .rtf,
        "sh": .sh,
        "swf": .swf,
        "tar": .tar,
        "ttf": .ttf,
        "txt": .txt,
        "vsd": .vsd,
        "woff": .woff,
        "woff2": .woff2,
        "xhtml": .xhtml,

        "xul": .xul,

        "7z": .sevenZ,
    ]
}
