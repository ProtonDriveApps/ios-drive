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

import Foundation
import PDCore
import Combine

final class UploadOperationInteractor: OperationInteractor {
    
    private let interactor: FileUploader
    private let restartErrorPublisher = PassthroughSubject<Void, Never>()
    
    let updatePublisher: AnyPublisher<Void, Never>
    
    init(interactor: FileUploader) {
        self.interactor = interactor
        
        let operationsProgressPublisher = interactor.queue
            .publisher(for: \.operationCount)
            .map { return $0 == .zero }
            .removeDuplicates()
            .map { _ in Void() }
        updatePublisher = Publishers.Merge(operationsProgressPublisher, restartErrorPublisher)
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    private var isInProgress: Bool {
        interactor.queue.operationCount != .zero
    }

    var state: OperationInteractorState {
        isInProgress ? .running : .idle
    }

    func start() {
        do {
            try interactor.restartOperations()
        } catch {
            restartErrorPublisher.send()
        }
    }
    
    func cancel() {
        interactor.pauseAllUploads()
    }
}
