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

import Combine
import UIKit
import PDCore

protocol FetchingViewModel: AnyObject {
    var lastUpdated: Date { get set }
    var fetchFromAPICancellable: AnyCancellable? { get set }
}

extension FetchingViewModel where Self: FinderViewModel, Self: SortingViewModel, Self.Model: NodesSorting, Self.Model: NodesFetching {
    var refreshMode: RefreshMode {
        switch self.sorting {
        case .nameAscending, .nameDescending:
            return .fetchAllPages
        default:
            return Constants.childrenRefreshStrategy
        }
    }
    
    func onSortingChanged() {
        self.restartFetchPaging()
    }
    
    func fetchNextPageFromAPI() {
        if !self.isUpdating {
            self.isUpdating = true
        }
        
        self.model.prepareForRefresh()
        self.fetchFromAPICancellable?.cancel()
        self.fetchFromAPICancellable = self.model.fetchChildrenFromAPI(proceedTillLastPage: false)
        .receive(on: DispatchQueue.main)
        .sink(receiveCompletion: { [weak self] completion in
            if case Subscribers.Completion.failure(let error) = completion {
                self?.genericErrors.send(error)
            }
            self?.isUpdating = false
        }, receiveValue: { [weak self] _ in
            self?.lastUpdated = Date()
        })
    }

    func fetchAllPagesFromAPI() {
        if !self.isUpdating {
            self.isUpdating = true
        }
        
        self.model.prepareForRefresh(fromPage: 0)
        self.fetchFromAPICancellable?.cancel()
        self.fetchFromAPICancellable = self.model.fetchChildrenFromAPI(proceedTillLastPage: true)
        .receive(on: DispatchQueue.main)
        .sink(receiveCompletion: { [weak self] completion in
            if case Subscribers.Completion.failure(let error) = completion {

                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    self?.genericErrors.send(error)
                    self?.isUpdating = false
                }

            } else {
                self?.isUpdating = false
            }
        }, receiveValue: { [weak self] _ in
            self?.lastUpdated = Date()
        })
    }
    
    func restartFetchPaging() {
        self.lastUpdated = .distantPast
        self.model.prepareForRefresh(fromPage: 0)
        self.fetchPages()
    }
    
    func fetchPages() {
        switch self.refreshMode {
        case .fetchAllPages where !self.didRefreshRecently():
            self.fetchAllPagesFromAPI()
        case .fetchPageByRequest where !self.didRefreshRecently():
            self.fetchNextPageFromAPI()
        case .events where !self.model.node.isChildrenListFullyFetched:
            self.fetchAllPagesFromAPI()
        case .events:
            self.lastUpdated = Date()
        default: break
        }
    }
    
    private func didRefreshRecently() -> Bool {
        self.lastUpdated != .distantPast || self.isUpdating
    }
}
