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

public enum BuildType: Int, CaseIterable {
    case dev
    case qa
    case alphaOrBeta // TODO: separate into `alpha` and `beta` cases when we have separate builds
    case prod

    public var isDev: Bool {
        return self == .dev
    }

    public var isQaOrBelow: Bool {
        return rawValue <= Self.qa.rawValue
    }

    public var isBetaOrBelow: Bool {
        return rawValue <= Self.alphaOrBeta.rawValue
    }

    public var isProdOrBellow: Bool {
        return rawValue <= Self.prod.rawValue
    }
}
