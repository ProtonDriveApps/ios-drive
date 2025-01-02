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
import PDClient
import PDLocalization

protocol ProtonDocumentWebViewModelProtocol {
    var title: AnyPublisher<String, Never> { get }
    var state: AnyPublisher<ProtonDocumentWebViewState, Never> { get }
    func startLoading()
    func isInternal(url: URL) -> Bool
    func openExternal(url: URL)
    func makeCleartextURL(for filename: String) -> URL
    func openShare()
    func handleDownloadError()
    func cleanUp()
}

enum ProtonDocumentWebViewState: Equatable {
    case loading
    case url(URL)
}

enum ProtonDocumentWebPreviewError: LocalizedError {
    case failedDownload
    case failedOpening

    var errorDescription: String? {
        switch self {
        case .failedDownload:
            Localization.proton_docs_download_error
        case .failedOpening:
            Localization.proton_docs_opening_error
        }
    }
}

final class ProtonDocumentWebViewModel: ProtonDocumentWebViewModelProtocol {
    private let identifier: ProtonDocumentIdentifier
    private let configuration: APIService.Configuration
    private let coordinator: ProtonDocumentCoordinatorProtocol
    private let storageResource: LocalStorageResource
    private let messageHandler: UserMessageHandlerProtocol
    private let urlInteractor: ProtonDocumentAuthenticatedDataFacadeProtocol
    private let nameDataSource: ProtonDocsDecryptedNameDataSource
    private var exportURL: URL?
    private var cancellables = Set<AnyCancellable>()
    private let titleSubject = CurrentValueSubject<String, Never>("")
    private let stateSubject = CurrentValueSubject<ProtonDocumentWebViewState, Never>(.loading)

    var title: AnyPublisher<String, Never> {
        titleSubject.eraseToAnyPublisher()
    }

    var state: AnyPublisher<ProtonDocumentWebViewState, Never> {
        stateSubject.eraseToAnyPublisher()
    }

    init(
        identifier: ProtonDocumentIdentifier,
        configuration: APIService.Configuration,
        coordinator: ProtonDocumentCoordinatorProtocol,
        storageResource: LocalStorageResource,
        messageHandler: UserMessageHandlerProtocol,
        urlInteractor: ProtonDocumentAuthenticatedDataFacadeProtocol,
        nameDataSource: ProtonDocsDecryptedNameDataSource
    ) {
        self.identifier = identifier
        self.configuration = configuration
        self.coordinator = coordinator
        self.storageResource = storageResource
        self.messageHandler = messageHandler
        self.urlInteractor = urlInteractor
        self.nameDataSource = nameDataSource
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

    private func handleUrlResult(_ result: ProtonDocumentAuthenticatedDataResult) {
        switch result {
        case let .success(data):
            stateSubject.send(.url(data.url))
        case let .failure(error):
            Log.error(error.localizedDescription, domain: .protonDocs)
            messageHandler.handleError(ProtonDocumentWebPreviewError.failedOpening)
        }
    }

    func startLoading() {
        urlInteractor.execute(with: identifier)
        nameDataSource.start()
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
        let error = ProtonDocumentWebPreviewError.failedDownload
        messageHandler.handleError(error)
    }

    func cleanUp() {
        if let exportURL {
            try? storageResource.delete(at: exportURL)
        }
    }
}
