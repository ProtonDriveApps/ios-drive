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

public class FileProviderEventsListener: EventsListener {
    private var manager: NSFileProviderManager?
    
    public init(manager: NSFileProviderManager?) {
        self.manager = manager
    }

    public func processorReceivedEvents() { }
    
    public func processorAppliedEvents(affecting nodes: [NodeIdentifier]) {
        Log.info("Received events for \(nodes.count) nodes and parents", domain: .fileProvider)
        guard !nodes.isEmpty else { return }
        
        let completion: (Error?) -> Void = {
            if let error = $0 {
                Log.error(error: error, domain: .fileProvider)
            } else {
                Log.info("Signaled change", domain: .fileProvider)
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
