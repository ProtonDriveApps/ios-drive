// Copyright (c) 2026 Proton AG
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

/// Canonical mapping `(method, path) → family` shared by PDClient and PDSDKCore.
///
/// Both networking tiers must produce identical family identifiers for the same
/// (method, URL) so a 429 observed on one tier blocks subsequent requests to
/// the same endpoint on the other tier. To guarantee that, both tiers call
/// `RateLimitFamily.from(method:path:)` rather than each computing their own.
public enum RateLimitFamily {
    /// Derives a canonical family identifier from method + URL path.
    /// Strips opaque ID segments (anything that isn't a lowercase-letter / hyphen
    /// name) so a 429 on one variable instance blocks all instances of the same
    /// resource shape.
    ///
    /// Examples:
    ///   from(method: "GET",  path: "/drive/shares/abc123/links/xyz789")  → "GET /drive/shares/links"
    ///   from(method: "POST", path: "/drive/shares/abc123/links")        → "POST /drive/shares/links"
    ///   from(method: "GET",  path: "/drive/me/devices")                  → "GET /drive/me/devices"
    ///   from(method: "GET",  path: "/drive/volumes/V/links/L/children")  → "GET /drive/volumes/links/children"
    public static func from(method: String, path: String) -> String {
        let kept = path
            .split(separator: "/", omittingEmptySubsequences: true)
            .filter(isStructuralSegment)
            .joined(separator: "/")
        return "\(method.uppercased()) /\(kept)"
    }

    /// True for resource/collection names; false for IDs.
    /// Names: lowercase letters, optionally with `-`/`_`, plus the API-version
    /// pattern `<letter><digits>` so `v2`/`v3` stay distinct from each other
    /// and from version-less paths.
    static func isStructuralSegment(_ segment: Substring) -> Bool {
        guard !segment.isEmpty else { return false }
        if segment.contains(where: { $0.isUppercase }) { return false }
        if segment.allSatisfy({ $0.isLowercase }) { return true }
        if segment.contains("-") || segment.contains("_") { return true }
        // API-version pattern: <single lowercase letter><digits>.
        if let first = segment.first, first.isLowercase,
           segment.count >= 2,
           segment.dropFirst().allSatisfy({ $0.isNumber }) {
            return true
        }
        return false
    }
}
