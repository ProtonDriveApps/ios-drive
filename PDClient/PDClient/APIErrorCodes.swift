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

public enum APIErrorCodes: Int, Equatable {
    case invalidValue = 2001 // INVALID_VALUE
    case alreadyExists = 2500 // ALREADY_EXISTS
    case itemOrItsParentDeletedErrorCode = 2501 // NOT_EXISTS
    case currentRevisionIsNotUpToDateErrorCode = 2511 // INCOMPATIBLE_STATE
    case invalidManifestSignature = 200502 // SIGNATURE_VERIFICATION_FAILED
    case protonDocumentCannotBeCreatedFromMacOSAppErrorCode = 200701 // FILE_CREATION_NOT_ENABLED_FOR_DOCUMENTS
}
