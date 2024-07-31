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

public struct MimeType: Hashable {
    public let value: String

    public static let empty = MimeType(value: "")

    /// MimeType is a wrapper around a MIMEType, the String representation of which can be accessed through the value field
    public init(value: String) {
        self.value = value
    }

    /// Failable initializer of a **MimeType** given a file extension
    /// - Parameter fileExtension: String representing a File extension e.g.: "doc", "png", "pdf"...
    public init?(fromFileExtension fileExtension: String) {
        guard let uti = UTType(tag: fileExtension, tagClass: .filenameExtension, conformingTo: nil),
                let ext = uti.preferredMIMEType
            else { return nil }

        value = ext
    }

    /// Failable initializer of a **MimeType** given a Uniform Type Identifier
    /// - Parameter uti: String representing a Uniform Type Identifier e.g.: "com.microsoft.word.doc", "public.png", "com.adobe.pdf"...
    public init?(uti: String) {
        guard let preferredMIMEType = UTType(uti)?.preferredMIMEType else {
            return nil
        }

        value = preferredMIMEType
    }
}

public extension MimeType {
    var isImage: Bool {
        UTI(fromMimeType: value).isImage
    }

    var isVideo: Bool {
        UTI(fromMimeType: value).isVideo
    }

    var isAudio: Bool {
        UTI(fromMimeType: value).isAudio
    }

    var isText: Bool {
        UTI(fromMimeType: value).isText
    }
    
    var isGif: Bool {
        UTI(fromMimeType: value).isGif
    }
}

public extension MimeType {
    static let doc = MimeType(fromFileExtension: "doc")!
    static let docx = MimeType(fromFileExtension: "docx")!
    static let pdf = MimeType(fromFileExtension: "pdf")!
    static let pot = MimeType(fromFileExtension: "pot")!
    static let ppt = MimeType(fromFileExtension: "ppt")!
    static let pptx = MimeType(fromFileExtension: "pptx")!
    static let xls = MimeType(fromFileExtension: "xls")!
    static let xlsx = MimeType(fromFileExtension: "xlsx")!
    static let xml = MimeType(fromFileExtension: "xml")!
    static let zip = MimeType(fromFileExtension: "zip")!

    static let abw = MimeType(value: "application/x-abiword")
    static let arc = MimeType(value: "application/x-freearc")
    static let azw = MimeType(value: "application/vnd.amazon.ebook")
    static let bin = MimeType(value: "application/octet-stream")
    static let bz = MimeType(value: "application/x-bzip")
    static let bz2 = MimeType(value: "application/x-bzip2")
    static let cda = MimeType(value: "application/x-cdf")
    static let csh = MimeType(value: "application/x-csh")
    static let css = MimeType(value: "text/css")
    static let csv = MimeType(value: "text/csv")

    static let eot = MimeType(value: "application/vnd.ms-fontobject")
    static let epub = MimeType(value: "application/epub+zip")
    static let gz = MimeType(value: "application/gzip")
    static let html = MimeType(value: "text/html")
    static let ics = MimeType(value: "text/calendar")
    static let jar = MimeType(value: "application/java-archive")
    static let js = MimeType(value: "text/javascript")
    static let json = MimeType(value: "application/json")
    static let jsonld = MimeType(value: "application/ld+json")
    static let mjs = MimeType(value: "text/javascript") // Has the same mymetype as js!!!
    static let mpkg = MimeType(value: "application/vnd.apple.installer+xml")
    static let odp = MimeType(value: "application/vnd.oasis.opendocument.presentation")
    static let ods = MimeType(value: "application/vnd.oasis.opendocument.spreadsheet")
    static let odt = MimeType(value: "application/vnd.oasis.opendocument.text")
    static let ogx = MimeType(value: "application/ogg")
    static let otf = MimeType(value: "font/otf")

    static let php = MimeType(value: "application/x-httpd-php")
    
    static let rar = MimeType(value: "application/vnd.rar")
    static let rtf = MimeType(value: "application/rtf")
    static let sh = MimeType(value: "application/x-sh")
    static let swf = MimeType(value: "application/x-shockwave-flash")
    static let tar = MimeType(value: "application/x-tar")
    static let ttf = MimeType(value: "font/ttf")
    static let txt = MimeType(value: "text/plain")
    static let vsd = MimeType(value: "application/vnd.visio")
    static let woff = MimeType(value: "font/woff")
    static let woff2 = MimeType(value: "font/woff2")
    static let xhtml = MimeType(value: "application/xhtml+xml")
    
    static let xul = MimeType(value: "application/vnd.mozilla.xul+xml")
    
    static let sevenZ = MimeType(value: "application/x-7z-compressed")

    static let pages = MimeType(value: "application/vnd.apple.pages")
    static let numbers = MimeType(value: "application/vnd.apple.numbers")
    static let keynote = MimeType(value: "application/vnd.apple.keynote")
    static let protonDocument = MimeType(value: ProtonDocumentConstants.mimeType)
}
