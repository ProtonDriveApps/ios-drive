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
import PDLocalization

final class ShareLinkDecryptionErrorViewModel: ObservableObject {
    @Published var attemptDeleteLink = false
    @Published var isScreenClosed = false

    private var cancellables = Set<AnyCancellable>()
    private let model: ShareLinkDecryptionErrorModel
    private let closeScreenSubject: AnyPublisher<Void, Never>

    init(
        closeScreenSubject: AnyPublisher<Void, Never>,
        model: ShareLinkDecryptionErrorModel
    ) {
        self.closeScreenSubject = closeScreenSubject
        self.model = model

        closeScreenSubject
            .sink { [unowned self] in self.close() }
            .store(in: &cancellables)
    }

    var stopSharingAlertTitle: String {
        Localization.stop_sharing_alert_title
    }

    var stopSharingAlertMessage: String {
        Localization.stop_sharing_success_text
    }

    var stopSharingButton: String {
        Localization.stop_sharing_alert_title
    }

    func deleteLink() {
        model.deleteSecureLink { [weak self] result in

            switch result {
            case.success:
                self?.isScreenClosed = true
                NotificationCenter.default.postBanner(.success(Localization.stop_sharing_success_text, delay: .delayed))

            case .failure(let error):
                NotificationCenter.default.postBanner(.failure(error, delay: .immediate))
            }
        }
    }

    private func close() {
        isScreenClosed = true
    }
}
