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
import ProtonCoreUtilities
import PDCore

public extension Progress {
    
    convenience init(totalUnitCount: Int64 = 0, oneTimeCancellationHandler: @escaping (Progress?) -> Void) {
        self.init(totalUnitCount: totalUnitCount)
        setOneTimeCancellationHandler(oneTimeCancellationHandler: oneTimeCancellationHandler)
    }
    
    @discardableResult
    func setOneTimeCancellationHandler(oneTimeCancellationHandler: @escaping (Progress?) -> Void) -> Progress {
        // optionality allows for nilling out the reference to oneTimeCancellationHandler after the first use
        // atomic ensures the oneTimeCancellationHandler is indeed called only once,
        // even in case of cancellation happening multiple times in a multi-threaded environment
        let oneTimeCancellationHandlerWrapper: Atomic<((Progress?) -> Void)?> = Atomic(oneTimeCancellationHandler)
        cancellationHandler = { [weak self] in
            Log.trace("cancellationHandler called")
            oneTimeCancellationHandlerWrapper.mutate { [weak self] oneTimeCancellationHandler in
                oneTimeCancellationHandler?(self)
                oneTimeCancellationHandler = nil
                self?.clearOneTimeCancellationHandler()
            }
        }
        return self
    }

    func clearOneTimeCancellationHandler() {
        cancellationHandler = nil
    }
}
