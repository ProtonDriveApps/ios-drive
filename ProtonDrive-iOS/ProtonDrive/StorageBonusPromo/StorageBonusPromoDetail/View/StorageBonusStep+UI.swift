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

import SwiftUI
import ProtonCoreUIFoundations
import Foundation

extension StorageBonusStep {
    var icon: Image {
        switch self {
        case .upload: return IconProvider.arrowUpLine
        case .share: return IconProvider.link
        case .recovery: return IconProvider.key
        }
    }

    var attributedDescription: AttributedString {
        do {
            var string = try AttributedString(
                markdown: description,
                options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
            )

            for run in string.runs where run.attributes[keyPath: \.link] != nil {
                string[run.range].foregroundColor = ColorProvider.BrandNorm
            }

            return string
        } catch {
            return AttributedString(description)
        }
    }
}
