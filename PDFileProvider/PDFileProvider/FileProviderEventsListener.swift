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
import FileProvider
import os.log

public class FileProviderEventsListener: EventsListener {
    private let logger: LogObject.Type
    private var manager: NSFileProviderManager?
    
    public init(manager: NSFileProviderManager?, logger: LogObject.Type) {
        self.manager = manager
        self.logger = logger
    }

    public func processorReceivedEvents() { }
    
    public func processorAppliedEvents(affecting nodes: [NodeIdentifier]) {
        ConsoleLogger.shared?.log("Received events for \(nodes.count) nodes and parents", osLogType: self.logger)
        guard !nodes.isEmpty else { return }
        
        let completion: (Error?) -> Void = {
            if let error = $0 {
                ConsoleLogger.shared?.log(error, osLogType: self.logger)
            } else {
                ConsoleLogger.shared?.log("Signaled change", osLogType: self.logger)
            }
        }
        
        // this does not support changes in root because it has a special ItemIdentifier
        nodes.forEach { nodeIdentifier in
            let container = NSFileProviderItemIdentifier(nodeIdentifier)
            self.manager?.signalEnumerator(for: container, completionHandler: completion)
        }
        
        // signaling is cheap so we will ping these every time
        self.manager?.signalEnumerator(for: .rootContainer, completionHandler: completion)
        self.manager?.signalEnumerator(for: .trashContainer, completionHandler: completion)
        self.manager?.signalEnumerator(for: .workingSet, completionHandler: completion)
    }
}
