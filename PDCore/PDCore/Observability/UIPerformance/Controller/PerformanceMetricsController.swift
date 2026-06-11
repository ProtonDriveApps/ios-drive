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

public protocol PerformanceMetricsControllerProtocol {
    func startRecord(id: AnyVolumeIdentifier, pageType: PerformanceMetric.PageType)
    func fetchThumbnail(id: AnyVolumeIdentifier, dataSource: PerformanceMetric.DataSource)
    func reportPreviewToThumbnail(id: AnyVolumeIdentifier, fileType: PerformanceMetric.FileType)
    func fetchFullContent(id: AnyVolumeIdentifier, dataSource: PerformanceMetric.DataSource)
    func reportPreviewToFullContent(id: AnyVolumeIdentifier, fileType: PerformanceMetric.FileType)
    func startRecord(pageType: PerformanceMetric.PageType)
    func updateTab(cacheCount: Int, in pageType: PerformanceMetric.PageType)
    func reportTabToFirstItem(pageType: PerformanceMetric.PageType)
    func reset()
}

public final class PerformanceMetricsController: PerformanceMetricsControllerProtocol {
    @ThreadSafe private var record: [String: RecordData] = [:]
    @ThreadSafe private var thumbnailFetch: [String: FetchData] = [:]
    @ThreadSafe private var contentFetch: [String: FetchData] = [:]
    @ThreadSafe private var tabFetch: [String: TabData] = [:]

    public init() { }

    // MARK: - Performance metrics for files
    public func startRecord(id: AnyVolumeIdentifier, pageType: PerformanceMetric.PageType) {
        record[id.key] = .init(pageType: pageType)
        Log.debug("start \(id), \(pageType)", domain: .metrics)
    }

    public func fetchThumbnail(id: AnyVolumeIdentifier, dataSource: PerformanceMetric.DataSource) {
        let isInitial = thumbnailFetch[id.key] == nil
        thumbnailFetch[id.key] = .init(
            appLoadType: isInitial ? .first : .subsequent,
            dataSource: dataSource
        )
    }

    public func fetchFullContent(id: AnyVolumeIdentifier, dataSource: PerformanceMetric.DataSource) {
        let isInitial = contentFetch[id.key] == nil
        contentFetch[id.key] = .init(
            appLoadType: isInitial ? .first : .subsequent,
            dataSource: dataSource
        )
    }

    public func reportPreviewToThumbnail(id: AnyVolumeIdentifier, fileType: PerformanceMetric.FileType) {
        guard
            let recordedData = record[id.key],
            let fetchData = thumbnailFetch[id.key]
        else {
            assertionFailure("Missing record")
            return
        }

        let intervalInNanoseconds = Double(DispatchTime.now().uptimeNanoseconds - recordedData.startDate.uptimeNanoseconds)
        ObservabilityPerformancePreviewToThumbnailResource()
            .send(
                labels: .init(
                    appLoadType: fetchData.appLoadType,
                    dataSource: fetchData.dataSource,
                    fileType: fileType,
                    pageType: recordedData.pageType
                ),
                duration: .init(value: intervalInNanoseconds / 1_000_000, unit: .milliseconds)
            )
    }

    public func reportPreviewToFullContent(id: AnyVolumeIdentifier, fileType: PerformanceMetric.FileType) {
        guard
            let recordedData = record[id.key],
            let fetchData = contentFetch[id.key]
        else {
            assertionFailure("Missing record")
            return
        }
        let intervalInNanoseconds = Double(DispatchTime.now().uptimeNanoseconds - recordedData.startDate.uptimeNanoseconds)
        ObservabilityPerformancePreviewToFullContentResource()
            .send(
                labels: .init(
                    appLoadType: fetchData.appLoadType,
                    dataSource: fetchData.dataSource,
                    fileType: fileType,
                    pageType: recordedData.pageType
                ),
                duration: .init(value: intervalInNanoseconds / 1_000_000, unit: .milliseconds)
            )
    }

    // MARK: - Performance metrics for tab
    public func startRecord(pageType: PerformanceMetric.PageType) {
        record[pageType.rawValue] = .init(pageType: pageType)

        let isInitial = tabFetch[pageType.rawValue] == nil
        let defaultData = TabData(
            loadType: isInitial ? .first : .subsequent,
            lastCacheCount: nil,
            dataSource: nil
        )
        let data = tabFetch[pageType.rawValue] ?? defaultData
        data.loadType = isInitial ? .first : .subsequent
        tabFetch[pageType.rawValue] = data
    }

    public func updateTab(cacheCount: Int, in pageType: PerformanceMetric.PageType) {
        guard let tabData = tabFetch[pageType.rawValue] else { return }
        if let lastCacheCount = tabData.lastCacheCount,
           lastCacheCount == 0,
           cacheCount != 0 {
            tabData.dataSource = .remote
        } else {
            tabData.dataSource = .local
        }
        tabData.lastCacheCount = cacheCount
        tabFetch[pageType.rawValue] = tabData
    }

    public func reportTabToFirstItem(pageType: PerformanceMetric.PageType) {
        guard
            let recordedData = record[pageType.rawValue],
            let tabData = tabFetch[pageType.rawValue],
            let lastCacheCount = tabData.lastCacheCount,
            lastCacheCount > 0, // Don't report if list is empty 
            let dataSource = tabData.dataSource
        else { return }

        let intervalInNanoseconds = Double(DispatchTime.now().uptimeNanoseconds - recordedData.startDate.uptimeNanoseconds)
        ObservabilityPerformanceTabToFirstItemResource()
            .send(
                labels: .init(
                    appLoadType: tabData.loadType,
                    dataSource: dataSource,
                    pageType: pageType
                ),
                duration: .init(value: intervalInNanoseconds / 1_000_000, unit: .milliseconds)
            )
        // SwiftUI.onAppear could be triggered couple times
        // Reset it to nil to prevent unwanted report
        record[pageType.rawValue] = nil
        tabFetch[pageType.rawValue]?.dataSource = .local
    }

    // MARK: - Others
    public func reset() {
        record = [:]
        thumbnailFetch = [:]
        contentFetch = [:]
    }
}

extension PerformanceMetricsController {
    struct RecordData {
        let pageType: PerformanceMetric.PageType
        let startDate: DispatchTime

        public init(pageType: PerformanceMetric.PageType) {
            self.pageType = pageType
            self.startDate = DispatchTime.now()
        }
    }

    struct FetchData {
        let appLoadType: PerformanceMetric.AppLoadType
        let dataSource: PerformanceMetric.DataSource
    }

    class TabData {
        var loadType: PerformanceMetric.AppLoadType
        var lastCacheCount: Int?
        var dataSource: PerformanceMetric.DataSource?

        init(
            loadType: PerformanceMetric.AppLoadType,
            lastCacheCount: Int?,
            dataSource: PerformanceMetric.DataSource?
        ) {
            self.loadType = loadType
            self.lastCacheCount = lastCacheCount
            self.dataSource = dataSource
        }
    }
}

private extension AnyVolumeIdentifier {
    var key: String { "\(volumeID)/\(id)" }
}
