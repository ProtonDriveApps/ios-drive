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

import Foundation
import PDLocalization
import PDCore

final class DocumentNameViewModel: EditNodeViewModel {
    var onError: ((Error) -> Void)?
    var onSuccess: (() -> Void)?
    var onPerformingRequest: (() -> Void)?
    var onDismiss: (() -> Void)?
    var onSetName: ((String) -> Void)

    var title: String { Localization.name_document_title }
    var buttonText: String { Localization.general_done }
    var placeHolder: String { Localization.create_document_placeholder }
    var fullName: String
    let shouldDoneButtonBeEnabledByDefault: Bool = true

    private let validator: Validator<String>

    init(validator: Validator<String>, fullName: String, onSetName: @escaping ((String) -> Void)) {
        self.validator = validator
        self.fullName = fullName
        self.onSetName = onSetName
    }

    func validate(_ proposal: String) -> [ValidationError<String>] {
        validator.validate(proposal)
    }

    func setName(to name: String) {
        onSetName(name)
    }

    func close() {
        onDismiss?()
    }
}
