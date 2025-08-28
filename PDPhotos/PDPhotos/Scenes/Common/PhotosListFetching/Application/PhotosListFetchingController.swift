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

import Combine
import Foundation
import PDCore

protocol PhotosListFetchingControllerProtocol: AnyObject, ErrorController {
    var firstLoad: AnyPublisher<Void, Never> { get }
    var lastAnchor: AnyPublisher<PhotosListFetchingAnchor, Never> { get }
    var isLoading: AnyPublisher<Bool, Never> { get }
    var paginationStatus: AnyPublisher<PhotosPaginationStatus, Never> { get }
    func loadNext()
    func loadNextIfNeeded(captureTime: Date)
    func loadIfEmpty()
    func reset()
    func setFilter(_ filter: PhotosListFilter)
}

final class PhotosListFetchingController: PhotosListFetchingControllerProtocol {
    private let facade: PhotosListFetchingFacade
    private let anchorController: PhotosListAnchorControllerProtocol
    private let errorController: ErrorSetControllerProtocol
    private let configuration: PhotosListConfiguration
    private var filter: PhotosListFilter = .default
    private var currentInput: PhotosListFetchingInput?
    private var lastAnchorSubject = CurrentValueSubject<PhotosListFetchingAnchor?, Never>(nil)
    private var paginationSubject = CurrentValueSubject<PhotosPaginationStatus, Never>(.loading)
    private var cancellables = Set<AnyCancellable>()
    private var errorSubject = PassthroughSubject<Error, Never>()
    private var firstLoadSubject = PassthroughSubject<Void, Never>()
    private var lastAnchorValue: PhotosListFetchingAnchor? {
        get { lastAnchorSubject.value }
        set { lastAnchorSubject.send(newValue) }
    }
    private let isLoadingSubject = PassthroughSubject<Bool, Never>()

    var errorPublisher: AnyPublisher<Error, Never> {
        errorSubject.eraseToAnyPublisher()
    }

    var firstLoad: AnyPublisher<Void, Never> {
        firstLoadSubject.eraseToAnyPublisher()
    }

    var paginationStatus: AnyPublisher<PhotosPaginationStatus, Never> {
        paginationSubject.eraseToAnyPublisher()
    }

    var lastAnchor: AnyPublisher<PhotosListFetchingAnchor, Never> {
        lastAnchorSubject
            .compactMap { $0 }
            .eraseToAnyPublisher()
    }

    var isLoading: AnyPublisher<Bool, Never> {
        isLoadingSubject
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    init(
        facade: PhotosListFetchingFacade,
        anchorController: PhotosListAnchorControllerProtocol,
        errorController: ErrorSetControllerProtocol,
        configuration: PhotosListConfiguration
    ) {
        self.facade = facade
        self.anchorController = anchorController
        self.errorController = errorController
        self.configuration = configuration
        subscribeToUpdates()
        setupCachedAnchor()
    }

    private func subscribeToUpdates() {
        facade.result
            .sink { [weak self] result in
                self?.handle(result)
            }
            .store(in: &cancellables)
    }

    private func handle(_ result: PhotosListFetchingResult) {
        switch result {
        case let .success(response):
            handleSuccess(response)
        case let .failure(error):
            handleFailure(error)
        }
    }

    private func handleSuccess(_ response: PhotosListFetchingResponse) {
        guard response.input == currentInput else {
            return
        }

        isLoadingSubject.send(false)
        paginationSubject.send(.finished)
        lastAnchorValue = response.anchor
        anchorController.store(anchor: response.anchor, for: makeListIdentifier())

        Log.info("handleSuccess", domain: .photosProcessing)
        if !response.anchor.hasMore {
            Log.info("loaded full list (anchor hasMore is false)", domain: .photosProcessing)
        } else if configuration.shouldLoadAllAtOnce {
            Log.info("loaded partial list (will continue fetching)", domain: .photosProcessing)
            loadNext()
        }
    }

    private func handleFailure(_ error: Error) {
        isLoadingSubject.send(false)
        currentInput = nil
        errorSubject.send(error)
        paginationSubject.send(.error)
        errorController.setError(error)
        Log.error(error: error, domain: .photosProcessing)
    }

    private func canLoadNext() -> Bool {
        if let lastAnchor = lastAnchorValue {
            return lastAnchor.hasMore
        } else {
            return true
        }
    }

    private func load(with input: PhotosListFetchingInput) {
        guard input != currentInput else {
            return
        }

        if lastAnchorValue == nil && !input.isResetting {
            firstLoadSubject.send()
        }

        Log.info("load, anchorId: \(input.anchorId ?? "empty"), isResetting: \(input.isResetting)", domain: .photosProcessing)
        isLoadingSubject.send(true)
        facade.execute(with: input)
        paginationSubject.send(.loading)
        currentInput = input
    }

    func loadNext() {
        guard canLoadNext() else {
            return
        }

        let anchorId = lastAnchorValue?.anchorId
        let input = PhotosListFetchingInput(anchorId: anchorId, tag: filter.tag, isResetting: false)
        load(with: input)
    }

    func loadNextIfNeeded(captureTime: Date) {
        guard canLoadNext() else {
            return
        }

        // Scrolling past the last fetched photo (photos are ordered by capture time descending)
        guard let captureTimeThreshold = lastAnchorValue?.captureTimeThreshold else { return }

        if captureTime <= captureTimeThreshold {
            Log.debug("loadNextIfNeeded, compared dates: \(captureTime), \(captureTimeThreshold)", domain: .photosProcessing)
            loadNext()
        }
    }

    func loadIfEmpty() {
        if lastAnchorValue == nil {
            loadNext()
        }
    }

    func reset() {
        lastAnchorValue = nil
        currentInput = nil
        anchorController.remove(for: makeListIdentifier())
        let input = PhotosListFetchingInput(anchorId: nil, tag: filter.tag, isResetting: true)
        load(with: input)
    }

    func setFilter(_ filter: PhotosListFilter) {
        guard self.filter != filter else {
            return
        }
        self.filter = filter
        currentInput = nil
        setupCachedAnchor()
        // We fetch only if for a given anchor we don't have any results locally.
        loadIfEmpty()
    }

    private func setupCachedAnchor() {
        let anchor = anchorController.load(for: makeListIdentifier())
        let anchorDescription = anchor.map { "\($0)" } ?? "nil"
        Log.debug("setupCachedAnchor, anchor: \(anchorDescription)", domain: .photosProcessing)
        lastAnchorValue = anchor
        if let anchor, !anchor.hasMore {
            paginationSubject.send(.finished)
        }
    }

    private func makeListIdentifier() -> PhotosListAnchorIdentifier {
        PhotosListAnchorIdentifier(configuration: configuration, filter: filter)
    }
}
