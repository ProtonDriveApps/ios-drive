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

import SwiftUI
import ProtonCoreUIFoundations

public struct ListSection<Header: View, Content: View>: View {

    let header: Header
    let content: () -> Content

    public init(
        @ViewBuilder header: @escaping () -> Header,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.header = header()
        self.content = content
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.top, 24)
                .padding(.bottom, 8)
                .padding(.horizontal)

            content()
        }
    }
}

public extension ListSection where Header == EmptyView {
    init(@ViewBuilder content: @escaping () -> Content) {
        self.header = EmptyView()
        self.content = content
    }
}

public extension ListSection where Header == DriveListSectionHeader {
    init(header: String, @ViewBuilder content: @escaping () -> Content) {
        self.header = DriveListSectionHeader(title: header)
        self.content = content
    }
}

public struct DriveListSectionHeader: View {
    let title: String

    public var body: some View {
        Text(title)
            .foregroundColor(ColorProvider.TextHint)
            .font(.body)
    }
}

public extension NavigationLink where Label == EmptyView {
    init(to destination: Destination) {
        self = .init(destination: destination,
                     label: { EmptyView() })
    }
}
