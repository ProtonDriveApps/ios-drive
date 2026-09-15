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

extension NSFileProviderSyncAnchor {
    struct UnderlyingAnchor: Codable {
        let eventID: String
        let shareID: String
        let referenceDate: Date
        /// Page cursor for the post-resync changes enumeration; nil for event-origin anchors. Optional so
        /// older persisted anchors (without the field) still decode — Codable handles it via *IfPresent.
        let resyncPageOffset: Int?

        init(eventID: String, shareID: String, eventSystemRerefenceDate: Date, resyncPageOffset: Int? = nil) {
            self.eventID = eventID
            self.shareID = shareID
            self.referenceDate = eventSystemRerefenceDate
            self.resyncPageOffset = resyncPageOffset
        }
        
        fileprivate init(rawValue: Data) throws {
            let decoded = try PropertyListDecoder().decode(Self.self, from: rawValue)
            self = decoded
        }
        
        fileprivate var rawValue: Data {
            // swiftlint:disable force_try
            try! PropertyListEncoder().encode(self)
            // swiftlint:enable force_try
        }
    }
    
    init(anchor: UnderlyingAnchor) {
        self.init(anchor.rawValue)
    }
    
    subscript<T>(_ member: KeyPath<UnderlyingAnchor, T>) -> T? {
        try? UnderlyingAnchor(rawValue: self.rawValue)[keyPath: member]
    }

    /// The resync page cursor carried by this anchor, or nil for event-origin / pre-paging anchors.
    var resyncPageOffset: Int? {
        // The subscript yields Int?? (outer nil = undecodable); flatten to Int?.
        self[\.resyncPageOffset] ?? nil
    }

    /// A copy of this anchor carrying `offset` as its resync page cursor (same eventID/shareID/referenceDate).
    /// Drives `moreComing` paging of the post-resync changes; returns self unchanged if it can't be decoded.
    func withResyncPageOffset(_ offset: Int) -> NSFileProviderSyncAnchor {
        guard let underlying = try? UnderlyingAnchor(rawValue: rawValue) else { return self }
        return NSFileProviderSyncAnchor(anchor: UnderlyingAnchor(
            eventID: underlying.eventID,
            shareID: underlying.shareID,
            eventSystemRerefenceDate: underlying.referenceDate,
            resyncPageOffset: offset
        ))
    }
}

extension NSFileProviderSyncAnchor: Swift.CustomDebugStringConvertible {
    public var debugDescription: String {
        Emojifier.gothic.symbolicate(self[\.eventID] ?? "")
    }
}
