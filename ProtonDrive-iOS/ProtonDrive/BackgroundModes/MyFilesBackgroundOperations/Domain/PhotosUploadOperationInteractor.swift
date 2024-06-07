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

import PDCore
import Combine
import Foundation

final class PhotosUploadOperationInteractor: OperationInteractor {

    private let uploadingFiles: () -> [File]
    private let interactor: FileUploader
    private let restartErrorPublisher = PassthroughSubject<Void, Never>()
    private var cancelables = Set<AnyCancellable>()

    let updatePublisher: AnyPublisher<Void, Never>

    init(
        uploadingFiles: @escaping () -> [File],
        interactor: FileUploader
    ) {
        self.uploadingFiles = uploadingFiles
        self.interactor = interactor

        let operationsProgressPublisher = interactor.isWorkingPublisher
            .removeDuplicates()
            .map { _ in Void() }
        updatePublisher = Publishers.Merge(operationsProgressPublisher, restartErrorPublisher)
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    var state: OperationInteractorState {
        interactor.isProcessingOperations ? .running : .idle
    }

    func start() {
        let uploadingFiles = uploadingFiles()

        guard !uploadingFiles.isEmpty else {
            restartErrorPublisher.send()
            return
        }

        for file in uploadingFiles {
            interactor.upload(file)
        }
    }

    func cancel() {
        interactor.pauseAllUploads()
    }

}
