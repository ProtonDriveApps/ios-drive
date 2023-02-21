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
    func fetchAllPagesFromAPI(_ observer: NSFileProviderEnumerationObserver) {
        self.model.prepareForRefresh(fromPage: 0)
        self.fetchFromAPICancellable?.cancel()
        self.fetchFromAPICancellable = self.model.fetchChildrenFromAPI(proceedTillLastPage: true)
        .receive(on: DispatchQueue.main)
        .sink { completion in
            if case let .failure(error) = completion {
                ConsoleLogger.shared?.log(error, osLogType: Self.self)
                let fsError = Errors.mapToFileProviderError(error) ?? error
                observer.finishEnumeratingWithError(fsError)
            } else {
                ConsoleLogger.shared?.log("Finished fetching pages from cloud", osLogType: Self.self)
                self.fetchAllChildrenFromDB(observer)
            }
        } receiveValue: { _ in
            ConsoleLogger.shared?.log("Received page from cloud", osLogType: Self.self)
        }
    }
}
