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

import PDCore
import PDLocalization
import PDUIComponents
import ProtonCoreUIFoundations
import SwiftUI
import UIKit

protocol HasRefreshControl {
    var refreshControlSubtitle: NSAttributedString { get }
    func refreshControlAction()
}

extension HasRefreshControl where Self: FetchingViewModel, Self: FinderViewModel, Self: SortingViewModel, Self.Model: NodesFetching, Self.Model: NodesSorting {
    func refreshControlAction() {
        self.fetchAllPagesFromAPI()
    }
}

extension HasRefreshControl where Self: FinderViewModel {
    func newLastUpdatedFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.doesRelativeDateFormatting = true
        return formatter
    }
    
    var refreshControlSubtitle: NSAttributedString {
        let lastEvent = self.model.tower.eventSystemLatestFetchTime ?? .distantPast
        let lastForceFetch = self.lastUpdated
        let date = lastEvent.compare(lastForceFetch) == .orderedAscending ? lastForceFetch : lastEvent
        let text = date == .distantFuture ? "" : Localization.refresh_last_update(time: newLastUpdatedFormatter().string(from: date))
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

extension TrashViewModel: HasRefreshControl { }
extension HasRefreshControl where Self: TrashViewModel {
    var refreshControlSubtitle: NSAttributedString { .init(string: "") }
    func refreshControlAction() {
        fetchAllPages()
    }
}

struct PullToRefresh: View {
    @Binding private var needRefresh: Bool
    private var subtitle: String?
    private let coordinateSpaceName: String
    private let onRefresh: () -> Void

    init(needRefresh: Binding<Bool>, subtitle: String?, coordinateSpaceName: String, onRefresh: @escaping () -> Void) {
        self._needRefresh = needRefresh
        self.subtitle = subtitle
        self.coordinateSpaceName = coordinateSpaceName
        self.onRefresh = onRefresh
    }

    var body: some View {
        HStack(alignment: .center) {
            if needRefresh {
                VStack {
                    Spacer()

                    ProtonSpinner(size: .medium)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(ColorProvider.TextHint)
                            .padding()
                    }
                }
                .frame(height: 80)
            }
        }
        .background(GeometryReader {
            Color.clear.preference(key: ScrollViewOffsetPreferenceKey.self,
                                   value: $0.frame(in: .named(coordinateSpaceName)).origin.y)
        })
        .onPreferenceChange(ScrollViewOffsetPreferenceKey.self) { offset in
            guard !needRefresh else { return }
            if offset > 50 {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                needRefresh = true
                onRefresh()
            }
        }
    }
}

struct ScrollViewOffsetPreferenceKey: PreferenceKey {
    typealias Value = CGFloat
    static var defaultValue = CGFloat.zero
    static func reduce(value: inout Value, nextValue: () -> Value) {
        value += nextValue()
    }

}
