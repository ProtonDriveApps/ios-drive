// Copyright (c) 2024 Proton AG
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

import CoreData
import FileProvider
import PDClient

public final class CancelToken {
    public var onCancel: () -> Void = { }
    @MainActor
    public var isCancelled: Bool = false
    public init() { }
    public func cancel() {
        Task { @MainActor in
            guard !isCancelled else { return }
            isCancelled = true
            onCancel()
        }
    }
}

public struct RefreshedNodesReport {
    public let active: Int
    public let total: Int
    /// Items abandoned after retries (isolated folder listings + metadata fetches). Non-zero means the scan
    /// completed with failures — the work queue is preserved so a resume can re-attempt them.
    public let failed: Int
    /// Which scan engine produced this report; stamped by `refreshUsingSyncApproach`.
    public let engine: ScanEngineVersion

    public init(active: Int, total: Int, failed: Int = 0, engine: ScanEngineVersion = .v1) {
        self.active = active
        self.total = total
        self.failed = failed
        self.engine = engine
    }
}

public protocol RefreshingNodesServiceProtocol {
    func refreshUsingSyncApproach(
        root: Folder,
        volumeID: String,
        resume: Bool,
        cancelToken: CancelToken?,
        onNodesRefreshed: @MainActor @escaping (_ saved: Int, _ total: Int?) -> Void
    ) async throws -> RefreshedNodesReport

    func resolvedScanEngineVersion() -> ScanEngineVersion
}

public extension RefreshingNodesServiceProtocol {
    // Non-resuming convenience overloads: a fresh scan is the default; only the full-resync resume path
    // passes resume: true.
    func refreshUsingSyncApproach(root: Folder, volumeID: String) async throws -> RefreshedNodesReport {
        try await refreshUsingSyncApproach(
            root: root, volumeID: volumeID, resume: false, cancelToken: nil, onNodesRefreshed: { _, _ in }
        )
    }

    func refreshUsingSyncApproach(
        root: Folder,
        volumeID: String,
        cancelToken: CancelToken?,
        onNodesRefreshed: @MainActor @escaping (_ saved: Int, _ total: Int?) -> Void
    ) async throws -> RefreshedNodesReport {
        try await refreshUsingSyncApproach(
            root: root, volumeID: volumeID, resume: false,
            cancelToken: cancelToken, onNodesRefreshed: onNodesRefreshed
        )
    }
}

public final class RefreshingNodesService: RefreshingNodesServiceProtocol {

    private let downloader: Downloader
    private let featureFlags: ExternalFeatureFlagsResource
    private let v1ScanEngine: MetadataScanEngine
    private let v2ScanEngine: MetadataScanEngine

    // Override of the engine selection (nil = follow the feature flag): true forces v2, false forces v1.
    // Only ever written by the macOS QA settings (a QA-only screen), so it is nil in production.
    @SettingsStorage("SyncMetadataScanV2EnabledQAOverride") private var scanEngineV2EnabledOverride: Bool?

    // Test-automation override injected from macOS `RuntimeConfiguration` (returns nil elsewhere): true
    // forces v2, false forces v1, nil defers to the QA override and the feature flag. Read live per scan.
    private let scanEngineV2TestOverride: () -> Bool?

    init(downloader: Downloader,
         featureFlags: ExternalFeatureFlagsResource,
         v1ScanEngine: MetadataScanEngine,
         v2ScanEngine: MetadataScanEngine,
         scanEngineV2TestOverride: @escaping () -> Bool? = { nil }) {
        self.downloader = downloader
        self.featureFlags = featureFlags
        self.v1ScanEngine = v1ScanEngine
        self.v2ScanEngine = v2ScanEngine
        self.scanEngineV2TestOverride = scanEngineV2TestOverride
        _scanEngineV2EnabledOverride.configure(with: .group(named: Constants.appGroup))
    }

    public func refreshUsingSyncApproach(
        root: Folder,
        volumeID: String,
        resume: Bool,
        cancelToken: CancelToken?,
        onNodesRefreshed: @MainActor @escaping (_ saved: Int, _ total: Int?) -> Void
    ) async throws -> RefreshedNodesReport {
        // v1 is the default; resolveV2Enabled() applies the test/QA overrides and the feature flag.
        let engineVersion = resolvedScanEngineVersion()
        let engine = engineVersion == .v2 ? v2ScanEngine : v1ScanEngine
        let report = try await engine.scanMetadata(
            root: root,
            volumeID: volumeID,
            resume: resume,
            cancelToken: cancelToken,
            onNodesRefreshed: onNodesRefreshed
        )
        return RefreshedNodesReport(active: report.active, total: report.total, failed: report.failed, engine: engineVersion)
    }

    public func resolvedScanEngineVersion() -> ScanEngineVersion {
        resolveV2Enabled() ? .v2 : .v1
    }

    /// Whether the v2 engine should run. Precedence: the test-automation override (macOS
    /// `RuntimeConfiguration`, injected) wins, then the QA settings override, then the feature flag.
    /// v1 is the default; v2 is opt-in.
    private func resolveV2Enabled() -> Bool {
        if let forced = scanEngineV2TestOverride() { return forced }
        if let scanEngineV2EnabledOverride { return scanEngineV2EnabledOverride }
        return featureFlags.isEnabled(flag: .driveSyncMetadataScanV2Enabled)
    }

}
