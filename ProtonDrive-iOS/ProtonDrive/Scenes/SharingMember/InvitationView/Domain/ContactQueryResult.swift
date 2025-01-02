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

class ContactQueryResult: Identifiable {
    let id: String

    // For query list
    let attributedName: AttributedString
    let attributedInfo: AttributedString
    
    // For candidate
    let name: String
    private(set) var mails: [String: Bool]
    let isGroup: Bool
    let isError: Bool
    var isDuplicated: Bool
    
    init(
        id: String,
        attributedName: NSAttributedString,
        attributedInfo: NSAttributedString,
        name: String,
        isGroup: Bool = false,
        isError: Bool = false,
        isDuplicated: Bool = false,
        mails: [String]
    ) {
        self.id = id
        self.attributedName = AttributedString(attributedName)
        self.attributedInfo = AttributedString(attributedInfo)
        self.name = name
        self.isGroup = isGroup
        self.isError = isError
        self.isDuplicated = isDuplicated
        // Duplicated mails can be passed. For translating them to dictionary we need a Set.
        let mailsKeyValues = Set(mails).map { ($0, true) }
        self.mails = Dictionary(uniqueKeysWithValues: mailsKeyValues)
    }
    
    var selectedMails: [String] {
        mails.compactMap { (mail, isSelected) in
            return isSelected ? mail : nil
        }
    }
    
    var displayName: String {
        if isGroup {
            return "\(name) (\(selectedMails.count)/\(mails.count))"
        } else {
            return name
        }
    }
    
    func update(selectedMails: [String]) {
        for (mail, _) in mails {
            mails[mail] = selectedMails.contains(mail)
        }
    }
}
