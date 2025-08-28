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

import PDCore

public protocol QuotaStateSettings: AnyObject {
    var quotaState: QuotaState? { get set }
}

extension LocalSettings: QuotaStateSettings {
    public var quotaState: QuotaState? {
        get {
            guard let value = quotaStateValue else { return nil }
            return QuotaState(rawValue: value)
        }
        set { quotaStateValue = newValue?.rawValue }
    }
}
