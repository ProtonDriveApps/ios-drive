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

import Combine
import Foundation
import PDCore
import PDCoreIOS
import PDClient
import PDLocalization

protocol ProtonFileWebViewModelProtocol {
    var title: AnyPublisher<String, Never> { get }
    var state: AnyPublisher<ProtonFileWebViewState, Never> { get }
    var identifier: ProtonFileIdentifier { get }
    var deleter: InvalidNodesDeleterProtocol { get }
    func startLoading()
    func isInternal(url: URL) -> Bool
    func openExternal(url: URL)
    func makeCleartextURL(for filename: String) -> URL
    func openShare()
    func handleDownloadError()
    func cleanUp()
    func reportPerformanceIfNeeded(url: URL)
    func viewDisappear()
}

enum ProtonFileWebViewState: Equatable {
    case loading
    case url(URL)
}

enum ProtonFileWebPreviewError: LocalizedError {
    case failedDownload
    case failedOpening

    var errorDescription: String? {
        switch self {
        case .failedDownload:
            Localization.download_failed
        case .failedOpening:
            Localization.proton_docs_opening_error
        }
    }
}

final class ProtonFileWebViewModel: ProtonFileWebViewModelProtocol {
    /// Time to keep the preview VC alive after dismiss so the web editor can flush saves.
    private static let deallocDelay: TimeInterval = Constants.isUnitTest ? 0.1 : 3

    let identifier: ProtonFileIdentifier
    private let configuration: APIService.Configuration
    private let coordinator: ProtonFileCoordinatorProtocol
    private let storageResource: LocalStorageResource
    private let messageHandler: UserMessageHandlerProtocol
    private let urlInteractor: ProtonFileAuthenticatedDataFacadeProtocol
    private let nameDataSource: ProtonDocsDecryptedNameDataSource
    private let performanceMetricsController: PerformanceMetricsControllerProtocol?
    let deleter: InvalidNodesDeleterProtocol
    private var exportURL: URL?
    private var cancellables = Set<AnyCancellable>()
    private let titleSubject = CurrentValueSubject<String, Never>("")
    private let stateSubject = CurrentValueSubject<ProtonFileWebViewState, Never>(.loading)

    var title: AnyPublisher<String, Never> {
        titleSubject.eraseToAnyPublisher()
    }

    var state: AnyPublisher<ProtonFileWebViewState, Never> {
        stateSubject.eraseToAnyPublisher()
    }

    init(
        identifier: ProtonFileIdentifier,
        configuration: APIService.Configuration,
        coordinator: ProtonFileCoordinatorProtocol,
        storageResource: LocalStorageResource,
        messageHandler: UserMessageHandlerProtocol,
        urlInteractor: ProtonFileAuthenticatedDataFacadeProtocol,
        nameDataSource: ProtonDocsDecryptedNameDataSource,
        performanceMetricsController: PerformanceMetricsControllerProtocol?,
        deleter: InvalidNodesDeleterProtocol
    ) {
        self.identifier = identifier
        self.configuration = configuration
        self.coordinator = coordinator
        self.storageResource = storageResource
        self.messageHandler = messageHandler
        self.urlInteractor = urlInteractor
        self.nameDataSource = nameDataSource
        self.performanceMetricsController = performanceMetricsController
        self.deleter = deleter
        subscribeToUpdates()
    }

    private func subscribeToUpdates() {
        urlInteractor.result
            .sink { [weak self] result in
                self?.handleUrlResult(result)
            }
            .store(in: &cancellables)

        nameDataSource.decryptedName
            .sink { [weak self] name in
                self?.titleSubject.send(name)
            }
            .store(in: &cancellables)
    }

    private func handleUrlResult(_ result: ProtonFileAuthenticatedDataResult) {
        switch result {
        case let .success(data):
            stateSubject.send(.url(data.url))
        case let .failure(error):
            Log.error(error: error, domain: .protonDocs)
            messageHandler.handleError(ProtonFileWebPreviewError.failedOpening)
        }
    }

    func startLoading() {
        urlInteractor.execute(with: identifier)
        nameDataSource.start()
    }

    func viewDisappear() {
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.deallocDelay) {
            self.coordinator.releasePreviewViewController()
        }
    }

    func isInternal(url: URL) -> Bool {
        guard let host = url.host else {
            return false
        }
        let allowedHosts = [
            configuration.baseHost,
            "docs." + configuration.baseHost,
            "docs-editor." + configuration.baseHost,
            "account." + configuration.baseHost
        ]
        return allowedHosts.contains(host)
    }

    func openExternal(url: URL) {
        coordinator.openExternal(url: url)
    }
    
    func makeCleartextURL(for filename: String) -> URL {
        let url = storageResource.makeTemporaryURL(filename: filename)
        exportURL = url
        return url
    }

    func openShare() {
        guard let url = exportURL else {
            return
        }

        coordinator.openShare(url: url) { [weak self] in
            try? self?.storageResource.delete(at: url)
        }
    }

    func handleDownloadError() {
        let error = ProtonFileWebPreviewError.failedDownload
        messageHandler.handleError(error)
    }

    func cleanUp() {
        if let exportURL {
            try? storageResource.delete(at: exportURL)
        }
    }

    func reportPerformanceIfNeeded(url: URL) {
        guard
            let component = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let host = component.host,
            host.contains("docs-editor"),
            let items = component.queryItems,
            let value = items.first(where: { $0.name == "type" })?.value
        else { return }
        let fileType: PerformanceMetric.FileType
        if value == "doc" {
            fileType = .protonDoc
        } else if value == "sheet" {
            fileType = .protonSheet
        } else {
            Log.warning("Unknown file type \(value)", domain: .metrics)
            fileType = .other
        }
        let id = AnyVolumeIdentifier(id: identifier.linkId, volumeID: identifier.volumeId)
        performanceMetricsController?.fetchFullContent(id: id, dataSource: .remote)
        performanceMetricsController?.reportPreviewToFullContent(id: id, fileType: fileType)
    }
}
