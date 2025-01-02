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
import Foundation
import PDLocalization

final class CreateFolderViewModel: EditNodeViewModel {
    var onDismiss: (() -> Void)?
    var onError: ((Error) -> Void)?
    var onSuccess: (() -> Void)?
    var onPerformingRequest: (() -> Void)?

    private let validator: Validator<String>
    private let folderCreator: FolderCreator
    private let parent: Folder

    init(folderCreator: FolderCreator, validator: Validator<String>, parent: Folder) {
        self.folderCreator = folderCreator
        self.validator = validator
        self.parent = parent
    }

    var title: String {
        Localization.create_folder_title
    }

    var buttonText: String {
        Localization.general_done
    }

    var placeHolder: String {
        Localization.create_folder_placeholder
    }

    var fullName: String {
        ""
    }

    func validate(_ proposal: String) -> [ValidationError<String>] {
        validator.validate(proposal)
    }

    func setName(to name: String) {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        for error in validator.validate(name) {
            onError?(error)
            return
        }

        onPerformingRequest?()
        folderCreator.createFolder(with: name, parent: parent) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .failure(let error):
                    self?.onError?(error)
                case .success:
                    self?.onSuccess?()
                }
            }
        }
    }

    func close() {
        onDismiss?()
    }
}
