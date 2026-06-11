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
import PDLocalization

enum ReportTopic: String, CaseIterable, Identifiable {
    case photos
    case albums
    case sharing
    case offline
    case fileProvider
    case encryption
    case decryption
    case other
    case docs
    case sheets

    var id: String { self.rawValue }

    var name: String {
        switch self {
        case .photos: return Localization.report_topic_photos_title
        case .albums: return Localization.report_topic_albums_title
        case .sharing: return Localization.report_topic_sharing_title
        case .offline: return Localization.report_topic_offline_title
        case .fileProvider: return Localization.report_topic_file_provider_title
        case .encryption: return Localization.report_topic_encryption_title
        case .decryption: return Localization.report_topic_decryption_title
        case .other: return Localization.report_topic_other_title
        case .docs: return Localization.report_topic_docs_title
        case .sheets: return Localization.report_topic_sheets_title
        }
    }
}
