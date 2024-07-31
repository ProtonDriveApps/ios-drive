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

import FileProvider
import PDCore

@available(macOS, unavailable)
public extension NSFileProviderItemIdentifier {
    
    /// URL should be compatible with structure produced by ``NSFileProviderItemIdentifier/makeUrl(filename:)`` method
    init(_ url: URL) {
        _ = url.lastPathComponent // filename
        let nodeId = url.deletingLastPathComponent().lastPathComponent // node id
        let shareId = url.deletingLastPathComponent().deletingLastPathComponent().lastPathComponent // share id
        let identifier = NodeIdentifier(nodeId, shareId)
        self.init(identifier)
    }
    
    /// URL contains some metadata of the file in order to simplify lookups: `.../ShareID/NodeID/filename`
    func makeUrl(item: NSFileProviderItem) -> URL? {
        guard let nodeIdentifier = NodeIdentifier(self) else {
            return nil
        }
        var url = NSFileProviderManager.default.documentStorageURL
        url.appendPathComponent(nodeIdentifier.shareID, isDirectory: true)
        url.appendPathComponent(nodeIdentifier.nodeID, isDirectory: true)
        let filename = makeFilename(item: item)
        url.appendPathComponent(filename, isDirectory: false)
        return url
    }

    private func makeFilename(item: NSFileProviderItem) -> String {
            let filename = item.filename
            guard let contentType = item.contentType, UTI(value: contentType.identifier).isProtonDocument else {
                return filename
            }
            // This url is used by OS to determine if the file should be opened in place or transferred.
            // Unless we add the extension, it won't be recognized.
            // Also it can be used to validate incoming URL in the main app to quickly verify that a proton doc is being requested.
            // Adding an extension shouldn't be a problem since the inverse function (`NSFileProviderItemIdentifier.init(_ url: URL)`) doesn't use it.
            return filename + "." + ProtonDocumentConstants.fileExtension
        }
}
