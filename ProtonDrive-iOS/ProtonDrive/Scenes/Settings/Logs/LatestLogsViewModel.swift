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
import PDCore
import PDCoreIOS

struct LatestLogsViewState: Equatable {
    let logText: String
    let matchRanges: [NSRange]
    let currentMatchIndex: Int
    let matchCountText: String?
    let showsMatchCount: Bool
    let isPreviousMatchEnabled: Bool
    let isNextMatchEnabled: Bool
}

final class LatestLogsViewModel {
    let url: URL

    // MARK: - Publishers
    @Published private(set) var latestLogText: String = ""
    @Published private(set) var hasMoreContent = false
    @Published private(set) var isLoadingMore = false
    @Published private(set) var displayState = LatestLogsViewState(
        logText: "",
        matchRanges: [],
        currentMatchIndex: 0,
        matchCountText: nil,
        showsMatchCount: false,
        isPreviousMatchEnabled: false,
        isNextMatchEnabled: false
    )
    @Published private(set) var scrollToMatchRange: NSRange?
    @Published var isExporting: Bool = false
    let logExported = PassthroughSubject<URL, Never>()

    private let chunkSize = 100 * 1024
    private var loadedByteCount: UInt64 = 0
    private var fileSize: UInt64 = 0

    private var searchTerm = ""
    private var matchRanges: [NSRange] = []
    private var currentMatchIndex = 0

    init(url: URL) {
        self.url = url
    }

    func startFetchingData() {
        loadedByteCount = 0
        fileSize = 0
        latestLogText = ""
        hasMoreContent = false
        searchTerm = ""
        matchRanges = []
        currentMatchIndex = 0
        scrollToMatchRange = nil
        rebuildDisplayState(scrollToMatch: false)
        loadNextChunk()
    }

    func loadMoreIfNeeded() {
        guard hasMoreContent, !isLoadingMore else { return }
        loadNextChunk()
    }

    func updateSearchTerm(_ term: String) {
        searchTerm = term
        currentMatchIndex = 0
        rebuildDisplayState(scrollToMatch: true)
    }

    func goToPreviousMatch() {
        guard !matchRanges.isEmpty else { return }
        currentMatchIndex = (currentMatchIndex - 1 + matchRanges.count) % matchRanges.count
        rebuildDisplayState(scrollToMatch: true)
    }

    func goToNextMatch() {
        guard !matchRanges.isEmpty else { return }
        currentMatchIndex = (currentMatchIndex + 1) % matchRanges.count
        rebuildDisplayState(scrollToMatch: true)
    }

    func clearScrollToMatchRange() {
        scrollToMatchRange = nil
    }

    private func loadNextChunk() {
        isLoadingMore = true

        Task.detached(priority: .background) { [weak self] in
            guard let self else { return }

            do {
                let chunk = try self.readNextChunk()
                await MainActor.run {
                    if !chunk.text.isEmpty {
                        self.latestLogText += chunk.text
                    }
                    self.loadedByteCount = chunk.newLoadedByteCount
                    self.fileSize = chunk.fileSize
                    self.hasMoreContent = self.loadedByteCount < self.fileSize
                    self.isLoadingMore = false
                    self.rebuildDisplayState(scrollToMatch: false)
                }
            } catch {
                Log.error("Failed to read latest logs file", error: error, domain: .logs)
                await MainActor.run {
                    self.isLoadingMore = false
                }
            }
        }
    }

    private func readNextChunk() throws -> (text: String, newLoadedByteCount: UInt64, fileSize: UInt64) {
        let fileHandle = try FileHandle(forReadingFrom: url)
        defer { try? fileHandle.close() }

        let fileSize = try fileHandle.seekToEnd()
        guard loadedByteCount < fileSize else {
            return ("", loadedByteCount, fileSize)
        }

        try fileHandle.seek(toOffset: loadedByteCount)

        let bytesToRead = min(UInt64(chunkSize), fileSize - loadedByteCount)
        guard let data = try fileHandle.read(upToCount: Int(bytesToRead)), !data.isEmpty else {
            return ("", loadedByteCount, fileSize)
        }

        let (text, consumedByteCount) = Self.decodeValidUTF8Prefix(from: data)
        let bytesConsumed = consumedByteCount > 0 ? consumedByteCount : data.count
        let newLoadedByteCount = loadedByteCount + UInt64(bytesConsumed)

        return (text, newLoadedByteCount, fileSize)
    }

    private static func decodeValidUTF8Prefix(from data: Data) -> (text: String, consumedByteCount: Int) {
        var end = data.count
        while end > 0 {
            if let text = String(data: data.prefix(end), encoding: .utf8) {
                return (text, end)
            }
            end -= 1
        }
        return ("", 0)
    }

    private func rebuildDisplayState(scrollToMatch: Bool) {
        let trimmedSearchTerm = searchTerm.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasQuery = !trimmedSearchTerm.isEmpty

        if hasQuery {
            matchRanges = Self.ranges(of: trimmedSearchTerm, in: latestLogText)
            if matchRanges.isEmpty {
                currentMatchIndex = 0
            } else {
                currentMatchIndex = min(currentMatchIndex, matchRanges.count - 1)
            }
        } else {
            matchRanges = []
            currentMatchIndex = 0
        }

        let matchCountText: String?
        if hasQuery {
            let current = matchRanges.isEmpty ? 0 : currentMatchIndex + 1
            matchCountText = "\(current) / \(matchRanges.count)"
        } else {
            matchCountText = nil
        }

        displayState = LatestLogsViewState(
            logText: latestLogText,
            matchRanges: matchRanges,
            currentMatchIndex: currentMatchIndex,
            matchCountText: matchCountText,
            showsMatchCount: hasQuery,
            isPreviousMatchEnabled: !matchRanges.isEmpty,
            isNextMatchEnabled: !matchRanges.isEmpty
        )

        if scrollToMatch, currentMatchIndex < matchRanges.count {
            scrollToMatchRange = matchRanges[currentMatchIndex]
        } else {
            scrollToMatchRange = nil
        }
    }

    private static func ranges(of searchTerm: String, in text: String) -> [NSRange] {
        guard !searchTerm.isEmpty else { return [] }

        var ranges: [NSRange] = []
        let nsText = text as NSString
        var searchRange = NSRange(location: 0, length: nsText.length)
        let options: NSString.CompareOptions = [.caseInsensitive, .diacriticInsensitive]

        while searchRange.length > 0 {
            let found = nsText.range(of: searchTerm, options: options, range: searchRange)
            guard found.location != NSNotFound else { break }
            ranges.append(found)
            let nextLocation = found.location + found.length
            guard nextLocation < nsText.length else { break }
            searchRange = NSRange(location: nextLocation, length: nsText.length - nextLocation)
        }

        return ranges
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
}
