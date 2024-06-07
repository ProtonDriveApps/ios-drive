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

final class PhotosRetryViewModel: ObservableObject {
    @Published var destination: PhotosRetryViewDestination?
    @Published var presentedAlert: PhotosRetryViewAlert?
    @Published private(set) var items = [PhotosRetryListRowItem]()
    @Published private(set) var failedToPreview = 0
    
    private let interactor: PhotosRetryInteractorProtocol
    private let nameUnwrappingStrategy: (String?) -> String
    private let imageUnwrappingStrategy: (Data?) -> Data
    
    let fallbackSystemImage = "eye.slash"
    let title = "Backup issues"
    let retryButtonTitle = "Retry all"
    let skipButtonTitle = "Skip"
    
    var subtitle: String {
        let count = items.count + failedToPreview
        if count <= 1 {
            return "\(count) item failed to backup"
        } else {
            return "\(count) items failed to backup"
        }
    }
    
    init(
        interactor: PhotosRetryInteractorProtocol,
        nameUnwrappingStrategy: @escaping (String?) -> String = DefaultNameUnwrappingStrategy,
        imageUnwrappingStrategy: @escaping (Data?) -> Data = DefaultImageUnwrappingStrategy
    ) {
        self.interactor = interactor
        self.nameUnwrappingStrategy = nameUnwrappingStrategy
        self.imageUnwrappingStrategy = imageUnwrappingStrategy
    }

    @MainActor
    func task() async {
        let (previews, failures) = await interactor.fetchAssets(ofSize: CGSize(width: 32, height: 32))
        self.items = previews.map {
            PhotosRetryListRowItem(
                id: $0.localIdentifier,
                name: nameUnwrappingStrategy($0.filename),
                image: imageUnwrappingStrategy($0.imageData)
            )
        }
        self.failedToPreview = failures
    }
    
    // Navigation
    
    func pushRetryButton() {
        interactor.retryUpload()
        destination = .unwind
    }
    
    func pushSkipButton() {
        presentedAlert = .skipDialog
    }
    
    func pushSkipAlertConfirmButton() {
        interactor.clearDeletedStorage()
        destination = .unwind
    }
    
    func pushSkipAlertCancelButton() {
        presentedAlert = nil
    }
}
