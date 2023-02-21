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

public struct LazyDrilldown<Content: View>: View {
    let build: () -> Content
    public init(_ build: @autoclosure @escaping () -> Content) {
        self.build = build
    }
    public var body: Content {
        build()
    }
}

// TODO: This extension cuts off updates saying explicitly that underlying Views are equal, which greatly reduces smartness of SwiftUI updates. Usage is discouraged
extension LazyDrilldown: Equatable {
    public static func == (lhs: LazyDrilldown<Content>, rhs: LazyDrilldown<Content>) -> Bool {
        return true
    }
}
