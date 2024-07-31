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

import Combine
import Foundation
import SwiftUI
import PDCore
import PDUIComponents
import SafariServices

protocol ProtonDocumentOpeningControllerProtocol {
    func openPreview(_ identifier: NodeIdentifier)
    func openPreview(_ url: URL)
}

final class ProtonDocumentOpeningController: ProtonDocumentOpeningControllerProtocol {
    private let interactor: ProtonDocumentOpeningURLInteractorProtocol
    private let coordinator: URLCoordinatorProtocol
    private let errorViewModel: ProtonDocumentErrorViewModelProtocol

    init(interactor: ProtonDocumentOpeningURLInteractorProtocol, coordinator: URLCoordinatorProtocol, errorViewModel: ProtonDocumentErrorViewModelProtocol) {
        self.interactor = interactor
        self.coordinator = coordinator
        self.errorViewModel = errorViewModel
    }

    func openPreview(_ identifier: NodeIdentifier) {
        do {
            let url = try interactor.getURL(for: identifier)
            coordinator.openExternal(url: url)
        } catch {
            handleError(error)
        }
    }

    func openPreview(_ url: URL) {
        do {
            let url = try interactor.getURL(for: url)
            coordinator.openExternal(url: url)
        } catch {
            handleError(error)
        }
    }

    private func handleError(_ error: Error) {
        Log.error("Failed to open Proton doc url: \(error.localizedDescription)", domain: .protonDocs)
        errorViewModel.handleError(error)
    }
}
