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

final class EditNodeNameViewModel: EditNodeViewModel {
    var onDismiss: (() -> Void)?
    var onError: ((Error) -> Void)?
    var onSuccess: (() -> Void)?
    var onPerformingRequest: (() -> Void)?

    private let node: NameEditingNode
    private let nameEditor: NodeNameEditor
    private let validator: Validator<String>

    init(node: NameEditingNode, nameEditor: NodeNameEditor, validator: Validator<String>) {
        self.node = node
        self.nameEditor = nameEditor
        self.validator = validator
    }
    
    var title: String {
        node.type == .file ? "Rename file" : "Rename folder"
    }

    var buttonText: String {
        "Done"
    }

    var placeHolder: String {
        node.fullName
    }

    var fullName: String {
        node.fullName
    }

    func validate(_ proposal: String) -> [ValidationError<String>] {
        validator.validate(proposal)
    }

    func setName(to name: String) {

        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)

        guard name != fullName else {
            onSuccess?()
            return
        }

        for error in validator.validate(name) {
            onError?(error)
            return
        }

        onPerformingRequest?()
        nameEditor.rename(to: name, node: node.id) { [weak self] result in
            switch result {
            case .success:
                self?.onSuccess?()
            case .failure(let error):
                self?.onError?(error)
            }
        }
    }
}
