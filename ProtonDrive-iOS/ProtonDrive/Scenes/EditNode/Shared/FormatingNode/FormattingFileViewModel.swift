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

final class FormattingFileViewModel: NameFormattingViewModel {
    let initialName: String?
    let nameAttributes: [NSAttributedString.Key: Any]
    let extensionAttributes: [NSAttributedString.Key: Any]

    init(initialName: String?, nameAttributes: [NSAttributedString.Key: Any], extensionAttributes: [NSAttributedString.Key: Any]) {
        self.initialName = initialName
        self.nameAttributes = nameAttributes
        self.extensionAttributes = extensionAttributes
    }

    func preselectedRange() -> NSRange? {
        guard let name = initialName else {
            return nil
        }
        let formatter = NodeNameFormatter<FileFormatter>(fullName: name)
        return NSRange(string: formatter.name)
    }

    func attributed(_ name: String) -> NSAttributedString {
        let formatter = NodeNameFormatter<FileFormatter>(fullName: name)
        let a = NSMutableAttributedString(string: formatter.name, attributes: nameAttributes)
        let b = NSMutableAttributedString(string: formatter.extension ?? "", attributes: extensionAttributes)
        a.append(b)
        return a
    }
}
