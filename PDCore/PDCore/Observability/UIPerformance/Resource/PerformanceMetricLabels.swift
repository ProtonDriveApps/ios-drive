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

// drive_mobile_performance_tabToFirstItem_histogram_v1.schema.json
struct PerformanceTabToFirstItemLabels: Encodable, Equatable {
    let appLoadType: PerformanceMetric.AppLoadType
    let dataSource: PerformanceMetric.DataSource
    let pageType: PerformanceMetric.PageType
}

// See drive_mobile_performance_previewToThumbnail_histogram_v1.schema.json
struct PerformancePreviewToThumbnailLabels: Encodable, Equatable {
    let appLoadType: PerformanceMetric.AppLoadType
    let dataSource: PerformanceMetric.DataSource
    let fileType: PerformanceMetric.FileType
    let pageType: PerformanceMetric.PageType
}

// See drive_mobile_performance_previewToFullContent_histogram_v1.schema.json
struct PerformancePreviewToFullContentLabels: Encodable, Equatable {
    let appLoadType: PerformanceMetric.AppLoadType
    let dataSource: PerformanceMetric.DataSource
    let fileType: PerformanceMetric.FileType
    let pageType: PerformanceMetric.PageType
}
