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

final class FileProviderMemoryMonitoringResource {
    private let resource: MemoryDiagnosticsResource
    private let queue = DispatchQueue(label: "FileProviderMemoryMonitoringResource", qos: .default)
    private var timer: Timer?

    init(resource: MemoryDiagnosticsResource) {
        self.resource = resource
        start()
    }

    private func start() {
        let timer = Timer(timeInterval: 5, repeats: true) { [weak self] _ in
            self?.handleUpdate()
        }
        self.timer?.invalidate()
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func cancel() {
        timer?.invalidate()
        timer = nil
    }

    private func handleUpdate() {
        guard let diagnostics = try? resource.getDiagnostics() else {
            return
        }

        Log.info("Memory dump: using \(diagnostics.usedMB) MB", domain: .diagnostics)
        // Threshold is 20MB. Let's log error in case of > 18 and see the trend in Sentry
        if diagnostics.usedMB > 18 {
            Log.error("File provider using > 18 MB of memory", domain: .diagnostics)
        }
    }
}
