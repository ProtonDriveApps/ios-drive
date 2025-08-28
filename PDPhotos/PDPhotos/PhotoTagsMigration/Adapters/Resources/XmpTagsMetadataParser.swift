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

/// A scanner to extract and parse XMP metadata from an image file URL.
public final class XMPScanner {

    /// Scans an image file for specific XMP metadata tags.
    ///
    /// This method asynchronously reads the start of the given file, extracts the XMP block,
    /// parses it, and returns the metadata.
    ///
    /// - Parameter url: The local file URL of the image to scan.
    /// - Returns: An `XMPMetadata` object if parsing is successful, otherwise `nil`.
    public func scan(url: URL) -> XMPMetadata? {
        // 1. Extract the XMP block as a string from the image file.
        guard let xmpString = extractXMP(from: url) else {
            // print("Debug: XMP block not found in file.")
            return nil
        }

        // 2. Initialize our custom parser with the XMP string.
        guard let parser = XMPMetadataParser(xmp: xmpString) else {
            // print("Debug: Failed to initialize XMP parser.")
            return nil
        }

        // 3. Create the final result object from the parser's findings.
        return XMPMetadata(
            isPortrait: parser.isPortrait,
            isMotionPhoto: parser.isMotionPhoto,
            isPanorama: parser.isPanorama
        )
    }

    /// Reads the image file to find and extract the XMP metadata block.
    private func extractXMP(from url: URL) -> String? {
        guard let fileHandle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? fileHandle.close() }

        let chunkSize = 4096
        let maxBytesToRead = 512 * 1024 // Stop reading after 512 KB if no XMP is found.
        let xmpHeader = "<x:xmpmeta"
        let xmpFooter = "</x:xmpmeta>"
        var buffer = Data()
        var totalBytesRead = 0

        // Read the file in chunks to avoid loading the whole image into memory.
        while totalBytesRead < maxBytesToRead {
            guard let chunk = try? fileHandle.read(upToCount: chunkSize), !chunk.isEmpty else {
                break // End of file
            }
            buffer.append(chunk)
            totalBytesRead += chunk.count

            // Once we find the header, look for the footer in the buffered data.
            if let startRange = buffer.range(of: Data(xmpHeader.utf8)) {
                if let endRange = buffer.range(of: Data(xmpFooter.utf8), in: startRange.lowerBound..<buffer.endIndex) {
                    let xmpData = buffer[startRange.lowerBound..<endRange.upperBound]
                    return String(data: xmpData, encoding: .utf8)
                }
            }
        }

        return nil // XMP not found within the read limit
    }
}

/// A data structure holding specific boolean flags derived from XMP metadata.
public struct XMPMetadata {
    /// True if the image is identified as a Portrait Mode photo (Google or Xiaomi).
    public let isPortrait: Bool

    /// True if the image is identified as a Motion Photo (Google).
    public let isMotionPhoto: Bool

    /// True if the image is identified as a Panorama (Google).
    public let isPanorama: Bool
}

/// An internal class that parses an XMP string using a SAX parser (`XMLParser`).
/// It conforms to `XMLParserDelegate` to handle parsing events.
internal final class XMPMetadataParser: NSObject, XMLParserDelegate {

    // MARK: - Properties to store parsed values
    private var foundSpecialTypeID: String?
    private var foundMiCameraXMPMeta: String?
    private var foundProjectionType: String?
    private var foundMotionPhoto: String?

    // MARK: - State Management for Parsing
    private var isParsingSpecialTypeID = false

    /// Initializes the parser and starts the parsing process.
    /// Fails if the XMP string cannot be converted to data.
    internal init?(xmp: String) {
        guard let data = xmp.data(using: .utf8) else { return nil }
        super.init()

        let parser = XMLParser(data: data)
        parser.delegate = self
        // Tell the parser to report namespaces, which separates the prefix from the element name.
        parser.shouldProcessNamespaces = true
        // The parse() method is synchronous.
        // After it returns, our properties will be populated.
        parser.parse()
    }

    // MARK: - Public Computed Properties (Replicating Kotlin Logic)

    var isPortrait: Bool {
        // Replicates:
        // getXMPProperty("//GCamera:SpecialTypeID[1]/*") == "..." ||
        // getXMPProperty("//@MiCamera:XMPMeta").orEmpty().contains("<depthmap")
        let isGooglePortrait = foundSpecialTypeID == "com.google.android.apps.camera.gallery.specialtype.SpecialType-PORTRAIT"
        let isXiaomiPortrait = foundMiCameraXMPMeta?.contains("<depthmap") ?? false
        return isGooglePortrait || isXiaomiPortrait
    }

    var isMotionPhoto: Bool {
        // Replicates: getXMPProperty("//@GCamera:MotionPhoto") == "1"
        return foundMotionPhoto == "1"
    }

    var isPanorama: Bool {
        // Replicates: getXMPProperty("//@GPano:ProjectionType") != null
        return foundProjectionType != nil
    }

    // MARK: - XMLParserDelegate Methods

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {

        // The `rdf:Description` element contains most of the attributes we need.
        // This is our equivalent of querying attributes on any node (`//@...`).
        if elementName == "Description" && namespaceURI == "http://www.w3.org/1999/02/22-rdf-syntax-ns#" {
            // Check for attributes and decode them for robustness.
            if let motionPhoto = attributeDict["GCamera:MotionPhoto"] {
                self.foundMotionPhoto = motionPhoto.byDecodingXMLEntities()
            }
            if let projectionType = attributeDict["GPano:ProjectionType"] {
                self.foundProjectionType = projectionType.byDecodingXMLEntities()
            }
            if let miCameraMeta = attributeDict["MiCamera:XMPMeta"] {
                self.foundMiCameraXMPMeta = miCameraMeta.byDecodingXMLEntities()
            }
        }

        // Handle the `SpecialTypeID` element, which contains its value as character data.
        if elementName == "SpecialTypeID" && namespaceURI == "http://ns.google.com/photos/1.0/camera/" {
            isParsingSpecialTypeID = true
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        // If we are inside a <SpecialTypeID> element, capture its string content.
        if isParsingSpecialTypeID {
            let content = string.trimmingCharacters(in: .whitespacesAndNewlines)
            if !content.isEmpty {
                // This might be called multiple times for one element, so append.
                foundSpecialTypeID = (foundSpecialTypeID ?? "") + content
            }
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        // Reset state when we exit the element.
        if elementName == "SpecialTypeID" && namespaceURI == "http://ns.google.com/photos/1.0/camera/" {
            isParsingSpecialTypeID = false
        }
    }
}

internal extension String {
    /// Decodes common XML character entities.
    /// This is necessary because `XMLParser` provides raw attribute values.
    func byDecodingXMLEntities() -> String {
        var result = self
        result = result.replacingOccurrences(of: "&lt;", with: "<")
        result = result.replacingOccurrences(of: "&gt;", with: ">")
        result = result.replacingOccurrences(of: "&quot;", with: "\"")
        result = result.replacingOccurrences(of: "&apos;", with: "'")
        // NOTE: &amp; must be decoded last.
        result = result.replacingOccurrences(of: "&amp;", with: "&")
        return result
    }
}
