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

import Foundation
import PDCore

protocol NameCorrectionPolicy {
    func validateNameAndCorrectIfNeeded(fileName: String) throws -> String
}

final class PhotoNameCorrectionPolicy: NameCorrectionPolicy {
    private let validator: NodeValidator
    
    init(validator: NodeValidator) {
        self.validator = validator
    }
    
    func validateNameAndCorrectIfNeeded(fileName: String) throws -> String {
        #if DEBUG
        if DebugConstants.commandLineContains(flags: [.uiTests, .skipPhotoNameCorrection]) {
            try validator.validateName(fileName)
            return fileName
        }
        #endif
        
        var name = fileName
        let fileExtension = name.fileExtension()
        let placeholderName = placeholderName(name: name, fileExtension: fileExtension)
        
        do {
            name = removingInvalidPhotoNameCharacters(name: name)
            if name.isEmpty {
                name = placeholderName
            }
            try validator.validateName(name)
        } catch {
            Log.info(
                "Photo name validation failed: \(error.localizedDescription), use placeholderName",
                domain: .photosProcessing
            )
            name = placeholderName
        }
        return name
    }
    
    private func placeholderName(name: String, fileExtension: String) -> String {
        let builder = SHA1DigestBuilder()
        builder.add(Data(name.utf8))
        let hex = builder.hexString()
        return fileExtension.isEmpty ? hex : "\(hex).\(fileExtension)"
    }
    
    private func removingInvalidPhotoNameCharacters(name: String) -> String {
        let regex = NSRegularExpression(#"\/|\\|[\u0000-\u001F]|[\u2000-\u200F]|[\u202E-\u202F]"#)
        let range = NSRange(location: 0, length: name.utf16.count)
        return regex.stringByReplacingMatches(in: name, options: [], range: range, withTemplate: "")
    }
}
