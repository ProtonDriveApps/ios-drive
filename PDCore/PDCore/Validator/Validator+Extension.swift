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
import PDLocalization

public enum Validations {
    public static let nonEmptyString = Validator(nonEmpty: \String.self)
}

public enum NameValidations {
    public static let nonEmpty = Validations.nonEmptyString.with(message: Localization.name_validation_non_empty)

    public static let charCount = Validator(\String.self, where: { $0.utf8.count < 256 }, message: Localization.name_validation_too_long)

    public static let dotNotAllowed = Validator(\String.self, where: { $0 != "." }, message: Localization.name_validation_dot)

    public static let twoDotsNotAllowed = Validator(\String.self, where: { $0 != ".." }, message: Localization.name_validation_two_dot)

    public static let invalidCharacters = Validator(
        \String.self,
         where: { !NSRegularExpression(#"\/|\\|[\u0000-\u001F]|[\u2000-\u200F]|[\u202E-\u202F]"#).matches($0) },
         message: Localization.name_validation_invisible_chars
    )

    public static let noleadingWhitespaces = Validator(\String.self, where: { !NSRegularExpression(#"^\s+"#).matches($0) }, message: Localization.name_validation_leading_white)

    static let noTrailingWhitespaces = Validator(\String.self, where: { !NSRegularExpression(#"\s+$"#).matches($0) }, message: Localization.name_validation_trailing_white)

    public static let userSelectedName = Validator(combining: [
                                        Self.nonEmpty,
                                        Self.dotNotAllowed,
                                        Self.twoDotsNotAllowed,
                                        Self.invalidCharacters])
    
    #if os(iOS)
    public static let iosName = Validator(combining: [
                                            Self.charCount,
                                            Self.userSelectedName,
                                            Self.noleadingWhitespaces,
                                            Self.noTrailingWhitespaces])
    #else
    public static let iosName = Validator(combining: [
                                            Self.nonEmpty,
                                            Self.charCount])
    #endif
}
