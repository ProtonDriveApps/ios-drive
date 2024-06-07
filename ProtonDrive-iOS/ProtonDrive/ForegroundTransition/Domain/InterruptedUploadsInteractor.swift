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

final class InterruptedUploadsInteractor: CommandInteractor {
    let storage: StorageManager
    let fileUploader: FileUploader
    
    init(storage: StorageManager, fileUploader: FileUploader) {
        self.storage = storage
        self.fileUploader = fileUploader
    }
    
    func execute() {
        let interruptedFiles = storage.fetchFilesInterrupted(moc: storage.newBackgroundContext())
        for file in interruptedFiles.filter({ !($0 is Photo) }) {
            fileUploader.upload(file)
        }
    }
}

import Combine
import Foundation

@available(*, deprecated, message: "Remove properly after GA to avoid clashing features with the PhotoUploaderFeeder")
final class PhotosInterruptedUploadsInteractor: CommandInteractor {
    private let uploadingFiles: () -> [File]
    private let uploader: FileUploader
    private let queue = DispatchQueue.global()

    private var cancelables = Set<AnyCancellable>()

    init(uploadingFiles: @escaping () -> [File], uploader: FileUploader) {
        self.uploadingFiles = uploadingFiles
        self.uploader = uploader
    }

    func execute() { }
}
