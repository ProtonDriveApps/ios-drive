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

import FileProvider

public extension PostLoginServices {
    func addNewFileProvider(domain: NSFileProviderDomain) {
        DispatchQueue.main.async {
            guard NSFileProviderManager(for: domain) != nil else {
                fatalError("Failed to create a manager")
            }
            
            // TODO: try NSFileProviderManager.reconnect if old local copy exists
            //       then first thing will be to ask NSFileProviderManager for changes since last logout
            ConsoleLogger.shared?.log("Adding domain \(domain.displayName)", osLogType: PostLoginServices.self)
            NSFileProviderManager.add(domain) { error in
                guard error == nil else {
                    ConsoleLogger.shared?.log(error!, osLogType: PostLoginServices.self)
                    return
                }
                ConsoleLogger.shared?.log("Added domain \(domain.displayName)", osLogType: PostLoginServices.self)
            }
        }
    }
    
    func removeFileProvider() {
        ConsoleLogger.shared?.log("Removing all domains", osLogType: PostLoginServices.self)
        // TODO: ask user if they want to wipe local copy
        NSFileProviderManager.removeAllDomains { error in
            guard error == nil else {
                ConsoleLogger.shared?.log(error!, osLogType: PostLoginServices.self)
                return
            }
            ConsoleLogger.shared?.log("Removed all domains", osLogType: PostLoginServices.self)
        }
    }
}
