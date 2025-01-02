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
import PDCore
import Combine

protocol EnumeratorWithItemsFromAPI: AnyObject, EnumeratorWithItemsFromDB where Model: NodesFetching & NodesSorting {
    var fetchFromAPICancellable: AnyCancellable? { get set }
}

extension EnumeratorWithItemsFromAPI {
    
    func fetchPageFromAPI(_ page: Int, observers: [NSFileProviderEnumerationObserver]) {
        self.model.prepareForRefresh(fromPage: page)
        self.fetchFromAPICancellable?.cancel()
        
        // This additional guard was introduced to work around a double enumeration issue, aka following scenario:
        // 1. Enumerator 1 starts fetching page 0
        // 2. Enumerator 1 finishes fetching page 0 and reports 150 items (150 total reported)
        // 3. Enumerator 1 starts fetching page 1
        // 4. Enumerator 2 starts fetching page 0
        // 5. Enumerator 1 finishes fetching page 1 and reports 100 items (250 total reported)
        // 6. Enumerator 1 sets model.node.isChildrenListFullyFetched = true and finishes enumeration
        // 7. Enumerator 2 finishes fetching page 0 and reports 150 items (150 total reported)
        // 8. Enumerator 2 finishes enumeration early because model.node.isChildrenListFullyFetched is true
        // Outcome: system now thinks there are 150 items, because that's what was last reported
        // To fix that, we skip the model.node.isChildrenListFullyFetched check if fetched page was not the last page
        var receivedTheLastPage = false
        
        self.fetchFromAPICancellable = self.model.fetchChildrenFromAPI(proceedTillLastPage: false)
        .receive(on: DispatchQueue.main)
        .sink { completion in
            if case let .failure(error) = completion {
                Log.error("Error fetching page: \(error.localizedDescription)", domain: .fileProvider)
                let fsError = Errors.mapToFileProviderError(error) ?? error
                observers.forEach { $0.finishEnumeratingWithError(fsError) }
            } else {
                Log.info("Finished fetching page \(page) from cloud", domain: .fileProvider)

                // if it fetched from the cloud, but it's not the last page, it should NOT finish here
                if receivedTheLastPage, 
                    let moc = self.model.node.moc,
                    moc.performAndWait({ self.model.node.isChildrenListFullyFetched }) {
                    observers.forEach { $0.finishEnumerating(upTo: nil) }
                    return
                }

                let nextPage = page + 1
                let providerPage = NSFileProviderPage(nextPage)
                observers.forEach { $0.finishEnumerating(upTo: providerPage) }
            }
        } receiveValue: { value in
            Log.info("Received page from cloud", domain: .fileProvider)
            receivedTheLastPage = value.isLastPage
            let nodes = value.nodes
            guard let moc = nodes.first?.managedObjectContext else {
                return
            }

            let items = moc.performAndWait {
                nodes.filter { $0.state != .deleted }.compactMap {
                    do {
                        return try NodeItem(node: $0)
                    } catch {
                        self.model.reportDecryptionError(for: $0, underlyingError: error)
                        return nil
                    }
                }
            }
            observers.forEach { $0.didEnumerate(items) }
        }
    }
}
