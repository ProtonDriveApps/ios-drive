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

public struct PerformanceMetric {
    public enum FileType: String, Encodable, Equatable {
        case photo
        case video
        case protonDoc
        case protonSheet
        case other
    }

    public enum PageType: String, Encodable, Equatable {
        case myFiles = "my_files"
        case computers
        case photos
        case sharedWithMe = "shared_with_me"
        case sharedByMe = "shared_by_me"
        case trash
    }

    public enum AppLoadType: String, Encodable, Equatable {
        /// The first time to open the item since app launch
        case first
        case subsequent
    }

    public enum DataSource: String, Encodable, Equatable {
        /// Need to retrieve from remote 
        case remote
        /// Has local cache
        case local
    }
}
