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
import Foundation
import PDLocalization

protocol NewDocumentViewModelProtocol {
    var loading: AnyPublisher<String?, Never> { get }
    func start(parentIdentifier: NodeIdentifier)
}

final class NewDocumentViewModel: NewDocumentViewModelProtocol {
    private let facade: NewDocumentFacadeProtocol
    private let openingController: ProtonDocumentOpeningControllerProtocol
    private let messageHandler: UserMessageHandlerProtocol
    private let dateResource: DateResource
    private let dateFormatter: DateFormatterResource
    private var cancellables = Set<AnyCancellable>()
    private let subject = PassthroughSubject<String?, Never>()

    var loading: AnyPublisher<String?, Never> {
        subject.eraseToAnyPublisher()
    }

    init(facade: NewDocumentFacadeProtocol, openingController: ProtonDocumentOpeningControllerProtocol, messageHandler: UserMessageHandlerProtocol, dateResource: DateResource, dateFormatter: DateFormatterResource) {
        self.facade = facade
        self.openingController = openingController
        self.messageHandler = messageHandler
        self.dateResource = dateResource
        self.dateFormatter = dateFormatter
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
        subject.send(Localization.creating_new_document)
        let timestamp = dateFormatter.format(dateResource.getDate())
        let name = Localization.new_document_title(timestamp: timestamp)
        let input = NewDocumentInput(name: name, parentIdentifier: parentIdentifier)
        facade.execute(with: input)
    }

    private func handle(_ result: ProtonDocumentCreationResult) {
        subject.send(nil)
        switch result {
        case let .failure(error):
            let localizedError = map(error: error)
            messageHandler.handleError(localizedError)
        case let .success(identifier):
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
