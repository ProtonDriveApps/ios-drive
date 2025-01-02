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

import Combine
import PDLocalization

final class SharedLinkEditorViewModel {
    let isSaveEnabledPublisher: AnyPublisher<Bool, Never>

    private let closeScreenSubject: PassthroughSubject<Void, Never>
    private let saveChangesSubject: PassthroughSubject<Void, Never>

    private var cancellables = Set<AnyCancellable>()

    init(
        closeScreenSubject: PassthroughSubject<Void, Never>,
        saveChangesSubject: PassthroughSubject<Void, Never>,
        isSaveEnabledPublisher: AnyPublisher<Bool, Never>
    ) {
        self.isSaveEnabledPublisher = isSaveEnabledPublisher
        self.closeScreenSubject = closeScreenSubject
        self.saveChangesSubject = saveChangesSubject
    }

    var title: String {
        Localization.edit_section_share_via_link
    }

    var saveButtonText: String {
        Localization.general_save
    }

    func attempSaving() {
        saveChangesSubject.send(Void())
    }

    func attemptClosing() {
        closeScreenSubject.send(Void())
    }
}
