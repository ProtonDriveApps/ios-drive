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

public protocol ProtonDocumentErrorViewModelProtocol {
    func handleError(_ error: Error)
}

public final class ProtonDocumentErrorViewModel: ProtonDocumentErrorViewModelProtocol {
    private let messageHandler: UserMessageHandlerProtocol

    public init(messageHandler: UserMessageHandlerProtocol) {
        self.messageHandler = messageHandler
    }

    public func handleError(_ error: Error) {
        let message = makeMessage(from: error as? ProtonDocumentOpeningError)
        let plainError = PlainMessageError(message)
        messageHandler.handleError(plainError)
    }

    private func makeMessage(from error: ProtonDocumentOpeningError?) -> String {
        switch error {
        case .invalidIncomingURL, .invalidIncomingFileExtension, .missingFile:
            return "This file type can only be opened from within Proton Drive."
        case .invalidFileType:
            return "This file type cannot be opened by Proton Drive."
        case .notSignedIn:
            return "You must sign in before you can open files in Proton Drive."
        case .missingIdentifier:
            return "Failed to locate file. Please right click and refresh before opening the file again."
        case .missingDirectShare, .missingAddressId, .missingAddress, .missingVolume, nil:
            return "Failed to open file, please try again later."
        }
    }
}
