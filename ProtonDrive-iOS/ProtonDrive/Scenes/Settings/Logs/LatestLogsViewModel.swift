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

import Foundation
import Combine
import UIKit
import PDCore
import PDCoreIOS

final class LatestLogsViewModel {
    let url: URL

    // MARK: - Publishers
    @Published var latestLogText: String = ""
    @Published var isExporting: Bool = false
    let logExported = PassthroughSubject<URL, Never>()

    private var timer: Timer?

    init(url: URL) {
        self.url = url
    }

    func startFetchingData() {
        fetchTextData(from: url)
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.fetchTextData(from: self?.url ?? URL(fileURLWithPath: ""))
        }
    }

    private func fetchTextData(from url: URL) {
        Task.detached(priority: .background) { [weak self] in
            guard let self else { return }
            do {
                let fileHandle = try FileHandle(forReadingFrom: url)
                let fileSize = try fileHandle.seekToEnd()
                let dataToRead = 100 * 1024
                let readOffset = fileSize >= UInt64(dataToRead) ? fileSize - UInt64(dataToRead) : 0

                try fileHandle.seek(toOffset: readOffset)

                let data = try fileHandle.readToEnd() ?? Data()
                try fileHandle.close()

                if let fetchedText = String(data: data, encoding: .utf8) {
                    await MainActor.run {
                        self.latestLogText = fetchedText
                    }
                }
            } catch {
                Log.error("Failed to read latest logs file", error: error, domain: .logs)
            }
        }
    }

    func exportAllLogs() {
        if isExporting { return }
        isExporting = true

        Task {
            // exporter present error banner
            let url = try? await LogExporter().export { progress in
                UserMessageHandler().handleSuccess(progress.rawValue)
            }
            if let url {
                await MainActor.run {
                    self.isExporting = false
                    self.logExported.send(url)
                }
            }
        }
    }

    func stopFetchingData() {
        timer?.invalidate()
        timer = nil
    }

    deinit {
        stopFetchingData()
    }
}
