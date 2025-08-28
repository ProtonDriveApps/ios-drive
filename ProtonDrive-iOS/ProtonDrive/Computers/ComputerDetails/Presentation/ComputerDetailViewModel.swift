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

import PDCore
import Foundation
import PDLocalization

struct DetailItem: Identifiable, Equatable {
    let id = UUID()
    let label: String
    let value: String
}

class ComputerDetailViewModel: ObservableObject {
    @Published var detailItems: [DetailItem] = []
    private let repository: ComputerDetailsRepositoryProtocol

    // MARK: - Localizables
    var sheetTitle: String { Localization.computer_details_title }
    private var computerNameTitle: String { Localization.computers_details_name }
    private var computerCreatorTitle: String { Localization.computers_details_creator }
    private var computerCreatedTitle: String { Localization.computers_details_created }

    init(repository: ComputerDetailsRepositoryProtocol) {
        self.repository = repository
        loadDetailItems()
    }

    func loadDetailItems() {
        do {
            let computerInformation = try repository.getComputerDetails()
            detailItems = [
                DetailItem(label: computerNameTitle, value: computerInformation.decryptedName),
                DetailItem(label: computerCreatorTitle, value: computerInformation.creator),
                DetailItem(label: computerCreatedTitle, value: formattedDate(from: computerInformation.createdDate))
            ]
        } catch {
            Log.error(error: error, domain: .computers)
        }
    }

    private func formattedDate(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd, yyyy"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date)
    }
}
