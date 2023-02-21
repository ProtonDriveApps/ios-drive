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

import Reachability
import PDClient

extension OfflineSaver {
    internal func trackReachability(toHost host: String) {
        do {
            // providing hostname, we'll get whenReachable called not only when connectivity changes
            // but also when VPN is connected
            let reachability = try Reachability(hostname: host)
            reachability.whenReachable = self.onReachable
            reachability.whenUnreachable = self.onUnreachable
            self.reachability = reachability
        } catch let error {
            assert(false, error.localizedDescription)
            ConsoleLogger.shared?.log(error, osLogType: OfflineSaver.self)
        }
    }
    
    func onReachable(_ reachability: Reachability) {
        switch reachability.connection {
        case .cellular, .wifi:
            ConsoleLogger.shared?.log("Became reachable via \(reachability.connection.description)", osLogType: OfflineSaver.self)
            
            self.requestProgressBlockUpdate()
            self.storage?.backgroundContext.perform {
                self.checkEverything()
            }
            
        default: break
        }
    }
    
    func onUnreachable(_ reachability: Reachability) {
        switch reachability.connection {
        case .unavailable, .none:
            ConsoleLogger.shared?.log("Lost reachability", osLogType: OfflineSaver.self)
            
            // check if something is not downloaded properly - and artificially add tiny fraction so progress will be claimed started
            self.storage?.backgroundContext.perform {
                if nil != self.markedFoldersAndFiles().files.first(where: { $0.activeRevision?.blocksAreValid() != true }) {
                    DispatchQueue.main.async { self.fractionCompleted += 0.01 }
                }
            }
            
        default: break
        }
    }
}
