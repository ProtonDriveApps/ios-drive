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
import Foundation

struct EditableData: Equatable {
    let expiration: Date?
    let password: String
}

final class EditLinkViewModel: ObservableObject {
    // Password
    @Published var password: String
    @Published var isSecure = true

    // Expiration Date
    @Published var expirationDate: Date
    @Published var hasExpirationDate: Bool

    let isLegacy: Bool
    let dateRange: ClosedRange<Date>

    private var now: Date
    private let savingSubjectWritter: CurrentValueSubject<EditableData, Never>
    private var cancellables = Set<AnyCancellable>()

    init(
        model: ShareLinkModel,
        savingSubjectWritter: CurrentValueSubject<EditableData, Never>,
        nowProvider: () -> Date = Date.init
    ) {
        self.savingSubjectWritter = savingSubjectWritter
        self.now = nowProvider()
        let tomorrow = now.addingTimeInterval(24 * 3600)
        let lastExpirationDay = now.addingTimeInterval(90 * 24 * 3600)
        self.isLegacy = model.linkModel.isLegacy

        let initialData = EditableData(expiration: model.linkModel.expirationDate, password: model.linkModel.customPassword)

        password = initialData.password

        if let expiration = initialData.expiration {
            hasExpirationDate = true

            if expiration < now {
                self.dateRange = expiration...lastExpirationDay
                expirationDate = expiration
            } else {
                self.dateRange = tomorrow...lastExpirationDay
                expirationDate = expiration
            }
        } else {
            self.dateRange = tomorrow...lastExpirationDay
            hasExpirationDate = false
            expirationDate = lastExpirationDay
        }

        $password
            .dropFirst()
            .sink { [weak self] pass in
                guard let self = self else { return }
                self.sendEdditedLink(pass: pass, hasExp: self.hasExpirationDate, expDate: self.expirationDate)
            }
            .store(in: &cancellables)

        $hasExpirationDate
            .dropFirst()
            .sink { [weak self] hasExp in
                guard let self = self else { return }
                self.sendEdditedLink(pass: self.password, hasExp: hasExp, expDate: self.expirationDate)
            }
            .store(in: &cancellables)

        $expirationDate
            .dropFirst()
            .sink { [weak self] expDate in
                guard let self = self else { return }
                self.sendEdditedLink(pass: self.password, hasExp: self.hasExpirationDate, expDate: expDate)
            }
            .store(in: &cancellables)
    }

    private func sendEdditedLink(pass: String, hasExp: Bool, expDate: Date) {
        let edited = EditableData(
            expiration: getCurrentExpirationDate(hasExp, expDate.startOfDay),
            password: getCurrentPassword(pass)
        )
        savingSubjectWritter.send(edited)
    }

    private func getCurrentExpirationDate(_ hasExpirationDate: Bool, _ expirationDate: Date) -> Date? {
        guard hasExpirationDate else { return nil }
        return expirationDate
    }

    private func getCurrentPassword(_ password: String) -> String {
        return password
    }

    var maximumPasswordSize: Int { 50 }
    var sectionTitle: String { "Privacy settings" }
    var passwordTitle: String { "Password protection" }
    var passwordPlaceholder: String { "Password" }
    var expirationDateTitle: String { "Expiration date" }
    var datePickerPlaceholder: String { "Date" }
}
