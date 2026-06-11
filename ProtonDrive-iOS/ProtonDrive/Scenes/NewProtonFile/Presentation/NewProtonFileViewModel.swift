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
import PDCore
import PDCoreIOS
import Foundation
import PDLocalization

protocol NewProtonFileViewModelProtocol {
    var loading: AnyPublisher<String?, Never> { get }
    func start(parentIdentifier: NodeIdentifier)
}

final class NewProtonFileViewModel: NewProtonFileViewModelProtocol {
    private let facade: NewProtonFileFacadeProtocol
    private let openingController: ProtonFileOpeningControllerProtocol
    private let messageHandler: UserMessageHandlerProtocol
    private let dateResource: DateResource
    private let dateFormatter: DateFormatterResource
    private let fileType: ProtonFileType
    private let performanceMetricsController: PerformanceMetricsControllerProtocol?
    private let eventsSystemManager: EventsSystemManager
    private var cancellables = Set<AnyCancellable>()
    private let subject = PassthroughSubject<String?, Never>()

    var loading: AnyPublisher<String?, Never> {
        subject.eraseToAnyPublisher()
    }

    init(
        facade: NewProtonFileFacadeProtocol,
        openingController: ProtonFileOpeningControllerProtocol,
        messageHandler: UserMessageHandlerProtocol,
        dateResource: DateResource,
        dateFormatter: DateFormatterResource,
        fileType: ProtonFileType,
        performanceMetricsController: PerformanceMetricsControllerProtocol?,
        eventsSystemManager: EventsSystemManager
    ) {
        self.facade = facade
        self.openingController = openingController
        self.messageHandler = messageHandler
        self.dateResource = dateResource
        self.dateFormatter = dateFormatter
        self.fileType = fileType
        self.performanceMetricsController = performanceMetricsController
        self.eventsSystemManager = eventsSystemManager
        subscribeToUpdates()
    }

    private func subscribeToUpdates() {
        facade.result
            .sink { [weak self] result in
                self?.handle(result)
            }
            .store(in: &cancellables)
    }

    func start(parentIdentifier: NodeIdentifier) {
        subject.send(getCreatingText())
        let timestamp = dateFormatter.format(dateResource.getDate())
        let name = Localization.new_document_title(timestamp: timestamp)
        let input = NewProtonFileInput(name: name, parentIdentifier: parentIdentifier)
        facade.execute(with: input)
    }

    private func getCreatingText() -> String {
        switch fileType {
        case .doc:
            return Localization.creating_new_document
        case .sheet:
            return Localization.creating_new_sheet
        }
    }

    private func handle(_ result: ProtonFileCreationResult) {
        subject.send(nil)
        switch result {
        case let .failure(error):
            let localizedError = map(error: error)
            messageHandler.handleError(localizedError)
        case let .success(identifier):
            performanceMetricsController?.startRecord(
                id: .init(id: identifier.nodeID, volumeID: identifier.volumeID),
                pageType: .myFiles // Can't create document in computers
            )
            eventsSystemManager.forcePolling(volumeIDs: [identifier.volumeID])
            openingController.openPreview(identifier)
        }
    }

    private func map(error: Error) -> LocalizedError {
        if let localizedError = error as? LocalizedError {
            return localizedError
        } else {
            return PlainMessageError(Localization.create_document_error)
        }
    }
}
