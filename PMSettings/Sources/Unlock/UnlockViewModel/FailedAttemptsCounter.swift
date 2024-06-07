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

public protocol FailedAttemptsCounter: AnyObject {
    var numberOfFailedAttempts: Int { get set }
    var maximumNumberOfAttempts: Int { get }
}

extension FailedAttemptsCounter {
    var exceededNumberOfAttempts: Bool {
        assert(maximumNumberOfAttempts > 0, "Misconfiguration: maximumNumberOfAttempts should be positive")
        return numberOfFailedAttempts >= maximumNumberOfAttempts
    }
    var attemptsLeft: Int {
        maximumNumberOfAttempts - numberOfFailedAttempts
    }
}

public final class InMemoryFailedAttemptsCounter: FailedAttemptsCounter {
    public init(maximumNumberOfAttempts: Int, numberOfFailedAttempts: Int) {
        self.maximumNumberOfAttempts = maximumNumberOfAttempts
        self.numberOfFailedAttempts = numberOfFailedAttempts
    }
    
    public var maximumNumberOfAttempts: Int
    public var numberOfFailedAttempts: Int
}
