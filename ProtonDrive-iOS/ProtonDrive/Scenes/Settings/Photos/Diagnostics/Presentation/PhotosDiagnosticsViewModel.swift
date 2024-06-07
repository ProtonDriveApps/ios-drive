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

import Combine
import Foundation

struct PhotosDiagnosticsData {
    struct Row: Identifiable, Hashable {
        var id: String {
            title
        }

        let location: String?
        let title: String
    }

    struct Section: Identifiable, Hashable {
        var id: String {
            title
        }

        let title: String
        let rows: [Row]
    }

    let title: String
    let isLoading: Bool
    let state: String?
    let exportButton: String?
    let startButton: String?
    let sections: [Section]?

    init(title: String = "Photos diagnostics", isLoading: Bool = false, state: String? = nil, exportButton: String? = nil, startButton: String? = nil, sections: [Section]? = nil) {
        self.title = title
        self.isLoading = isLoading
        self.state = state
        self.exportButton = exportButton
        self.startButton = startButton
        self.sections = sections
    }
}

protocol PhotosDiagnosticsViewModelProtocol: ObservableObject {
    var data: PhotosDiagnosticsData { get }
    var exportedInfosUrls: [URL]? { get set }
    func executeDiagnostics()
    func exportLogs()
}

final class PhotosDiagnosticsViewModel: PhotosDiagnosticsViewModelProtocol {
    private let facade: PhotosDiagnosticsFacade
    private var cancellable: AnyCancellable?

    @Published var data = PhotosDiagnosticsData(startButton: "Run diagnostics")
    @Published var exportedInfosUrls: [URL]?
    private var urls = [URL]()

    init(facade: PhotosDiagnosticsFacade) {
        self.facade = facade
    }

    func executeDiagnostics() {
        data = PhotosDiagnosticsData(isLoading: true)
        cancellable = facade.state
            .sink { [weak self] value in
                self?.handle(value)
            }
        facade.execute()
    }

    private func handle(_ value: Result<PhotosDiagnosticsState, Error>) {
        switch value {
        case .success(let state):
            handleState(state)
        case .failure(let error):
            data = PhotosDiagnosticsData(state: "Error: \(error.localizedDescription)", startButton: "Try again")
        }
    }

    private func handleState(_ state: PhotosDiagnosticsState) {
        switch state {
        case .library:
            data = PhotosDiagnosticsData(isLoading: true, state: "Processing library...")
        case .database:
            data = PhotosDiagnosticsData(isLoading: true, state: "Processing database...")
        case .cloud:
            data = PhotosDiagnosticsData(isLoading: true, state: "Processing cloud...")
        case .conflicts:
            data = PhotosDiagnosticsData(isLoading: true, state: "Finding differences...")
        case .storing:
            data = PhotosDiagnosticsData(isLoading: true, state: "Storing diagnostic files...")
        case .diagnostics(let photosDiagnostics):
            urls = photosDiagnostics.dumpUrls + photosDiagnostics.diffUrls
            let sections = makeSections(from: photosDiagnostics)
            data = PhotosDiagnosticsData(exportButton: "Export diagnostic files", sections: sections)
        }
    }

    private func makeSections(from photosDiagnostics: PhotosDiagnostics) -> [PhotosDiagnosticsData.Section] {
        return [
            makeSection(title: "Library to storage diff", differences: photosDiagnostics.libraryStorageDifferrences),
            makeSection(title: "Storage to cloud diff", differences: photosDiagnostics.storageCloudDifferences),
            makeSection(title: "Library to cloud diff", differences: photosDiagnostics.libraryCloudDifferences),
        ]
    }

    private func makeSection(title: String, differences: TreeDifferences) -> PhotosDiagnosticsData.Section {
        if Constants.isUITest {
            return PhotosDiagnosticsData.Section(title: title, rows: [PhotosDiagnosticsData.Row(location: nil, title: "section disabled in UI tests")])
        } else if differences.changes.isEmpty {
            return PhotosDiagnosticsData.Section(title: title, rows: [PhotosDiagnosticsData.Row(location: nil, title: "no changes")])
        } else {
            let rows = differences.changes.map {
                let location = $0.index.map { "index \($0)" }
                return PhotosDiagnosticsData.Row(location: location, title: $0.title)
            }
            return PhotosDiagnosticsData.Section(title: title + " (\(rows.count))", rows: rows)
        }
    }

    func exportLogs() {
        exportedInfosUrls = urls
    }
}
