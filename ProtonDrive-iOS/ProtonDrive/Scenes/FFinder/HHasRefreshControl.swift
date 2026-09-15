// Copyright (c) 2026 Proton AG
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
import ProtonCoreUIFoundations
import UIKit
import SwiftUI
import PDUIComponents

@MainActor
protocol HHasRefreshControl {
    var lastEventFetchedDate: Date? { get }
    var lastUpdated: Date { get }
    var refreshControlSubtitle: NSAttributedString { get }
    
    func fetchAllChildren() async
}

extension HHasRefreshControl {
    var refreshControlSubtitle: NSAttributedString {
        let lastEvent = lastEventFetchedDate ?? .distantPast
        let lastForceFetch = lastUpdated
        let date = lastEvent.compare(lastForceFetch) == .orderedAscending ? lastForceFetch : lastEvent
        
        let text = date == .distantFuture ? "" : Localization.refresh_last_update(time: DateFormatter.shortRelative.string(from: date))
        let string = NSAttributedString(
            string: text,
            attributes: [
                NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: .caption2),
                NSAttributedString.Key.foregroundColor: UIColor(ColorProvider.TextHint)
            ]
        )
        return string
    }
}
