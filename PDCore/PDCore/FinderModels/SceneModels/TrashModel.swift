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
import os.log

public protocol TrashModelProtocol: FinderModel {
    var trashItems: AnyPublisher<[Node], Never> { get }
    var didFetchAllTrash: Bool { get set }
    
    func fetchTrash(at page: Int, completion: @escaping (Result<Int, Error>) -> Void)
    func delete(nodes: [String]) -> AnyPublisher<Void, Error>
    func emptyTrash(nodes: [String]) -> AnyPublisher<Void, Error>
    func restoreFromTrash(nodes: [String]) -> AnyPublisher<Void, Error>
}

public final class TrashModel {
    public var logger: Logger?
    private(set) unowned var tower: Tower
    public let shareID: String
    private let childrenObserver: FetchedObjectsObserver<Node>
    private var fetchFromAPICancellable: AnyCancellable?

    public init(tower: Tower) {
        self.tower = tower
        self.shareID = tower.rootFolderIdentifier()!.shareID
        let children = tower.uiSlot!.subscribeToTrash()
        let observer = FetchedObjectsObserver(children)
        childrenObserver = observer
        childrenObserver.start()
        trashItems = childrenObserver.objectWillChange
            .map { [weak observer] in
                let trash = observer?.fetchedObjects ?? []
                let sortedTrash = SortPreference.default.sort(trash)
                return sortedTrash
            }
            .eraseToAnyPublisher()
    }

    public let trashItems: AnyPublisher<[Node], Never>
}

extension TrashModel: TrashModelProtocol {
    // FinderModel
    public func loadFromCache() {}
    public var folder: Folder?  { nil }
    
    // unused by ViewModel, but can be used to prevent fetching of all nodes every time screen is opened
    public var didFetchAllTrash: Bool {
        get { tower.didFetchAllTrash }
        set { tower.didFetchAllTrash = newValue }
    }

    public func fetchTrash(at page: Int = 0, completion: @escaping (Result<Int, Error>) -> Void) {
        let pageSize = 50
        tower.getTrash(shareID: shareID, page: page, pageSize: pageSize) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let nodes):
                self.logger?.log("Fetched Trash – Page: \(page), Items: \(nodes)", osLogType: TrashLogger.self)
                if nodes < pageSize {
                    self.didFetchAllTrash = true
                    completion(.success(nodes))
                } else {
                    self.fetchTrash(at: page + 1, completion: completion)
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    public func delete(nodes: [String]) -> AnyPublisher<Void, Error> {
        Future<Void, Error> { [weak self] promise in
            guard let self = self else { return }
            self.logger?.log("Delete - Nodes, osLogType", osLogType: TrashLogger.self)
            self.tower.delete(nodes: nodes, shareID: self.shareID) {
                promise($0)
            }
        }
        .eraseToAnyPublisher()
    }

    public func emptyTrash(nodes: [String]) -> AnyPublisher<Void, Error> {
        Future<Void, Error> { [weak self] promise in
            guard let self = self else { return }
            self.logger?.log("Empty Trash - Share with id: \(self.shareID)", osLogType: TrashLogger.self)
            self.tower.emptyTrash(nodes: nodes, shareID: self.shareID) {
                promise($0)
            }
        }
        .eraseToAnyPublisher()
    }

    public func restoreFromTrash(nodes: [String]) -> AnyPublisher<Void, Error> {
        Future<Void, Error> { [weak self] promise in
            guard let self = self else { return }
            self.logger?.log("Restore from Trash - Share with id: \(self.shareID)", osLogType: TrashLogger.self)
            self.tower.restoreFromTrash(shareID: self.shareID, nodes: nodes) {
                promise($0)
            }
        }
        .eraseToAnyPublisher()
    }
}

extension TrashModel: ThumbnailLoader {
    public func loadThumbnail(with id: Identifier) {
        return tower.loadThumbnail(with: id)
    }

    public func cancelThumbnailLoading(_ id: Identifier) {
        tower.cancelThumbnailLoading(id)
    }
}

struct TrashLogger: LogObject {
    static var osLog: OSLog = OSLog(subsystem: "ch.protondrive", category: "Trash")
}
