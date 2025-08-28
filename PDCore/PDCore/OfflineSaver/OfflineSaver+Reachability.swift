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
import Reachability
import PDClient

extension OfflineSaver {
    internal func trackReachability(toHost host: String) {
        let cancellable = connectionStateResource.state.sink { [weak self] state in
            self?.handle(state: state)
        }
        add(cancellable: cancellable)
    }

    private func handle(state: NetworkState) {
        switch state {
        case .reachable:
            self.rebuildProgressSubject.send()
            self.storage?.backgroundContext.perform {
                self.checkEverything()
            }
        case .unreachable:
            // check if something is not downloaded properly - and artificially add tiny fraction so progress will be claimed started
            self.storage?.backgroundContext.perform {
                if nil != self.markedFoldersAndFiles().files.first(where: { $0.activeRevision?.blocksAreValid() != true }) {
                    DispatchQueue.main.async { self.fractionCompleted += 0.01 }
                }
            }
        }
    }
}
