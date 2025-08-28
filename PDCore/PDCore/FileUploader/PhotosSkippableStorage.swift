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

public protocol PhotosSkippableStorage {
    typealias Identifier = PhotoAssetMetadata.iOSPhotos
    subscript(index: Identifier) -> Int? { get set }

    func checkSkippableStatus(identifier: Identifier) -> SkippableStatus
    func batchMarkAsSkippable(data: [Identifier: Int])
    func clean()
}

public enum SkippableStatus {
    /// Recorded identifier, all files are uploaded
    case skippable
    /// Has pending upload tasks
    case hasPendingUpload
    /// New created asset
    case newAsset
    /// Need to compare adjustmentTimestamp with modification date
    case needsDoubleCheck
}

public class UserDefaultsPhotosSkippableStorage: PhotosSkippableStorage {
    typealias Store = [String: Int]
    private static let delimiter = "@"
    
    @SettingsStorage(SettingsStorageKey.photosSkippableCacheKey.value) private var store: Store?
    private let queue = DispatchQueue(label: "SkippableStorage", qos: .userInteractive, attributes: .concurrent)
    private var inMemorySet: Set<InMemoryData> = Set()
    
    public init(suite: SettingsStorageSuite = .standard) {
        _store.configure(with: suite)
        queue.async(flags: .barrier) {
            self.inMemorySet = self.loadSetFromStore()
        }
    }
    
    public subscript(index: Identifier) -> Int? {
        get {
            queue.sync {
                let tmp = InMemoryData(identifier: index)
                guard let cached = inMemorySet.first(where: { $0 == tmp }) else { return nil }
                return cached.fileNeedsToBeUploaded(on: index.modificationTime)
            }
        }
        set {
            queue.async(flags: .barrier) { [weak self] in
                let tmp = InMemoryData(identifier: index, fileNeedsToBeUploaded: newValue)
                self?.inMemorySet.mergeableInsert(tmp)
                self?.saveSetToStore(self!.inMemorySet)
            }
        }
    }
    
    public func batchMarkAsSkippable(data: [Identifier: Int]) {
        queue.async(flags: .barrier) { [weak self] in
            for (identifier, value) in data {
                let tmp = InMemoryData(
                    cloudIdentifier: identifier.identifier,
                    data: [identifier.modificationTime: value]
                )
                self?.inMemorySet.mergeableInsert(tmp)
            }
            self?.saveSetToStore(self!.inMemorySet)
        }
    }
    
    public func checkSkippableStatus(identifier: Identifier) -> SkippableStatus {
        let tmp = InMemoryData(identifier: identifier)
        
        return queue.sync {
            guard let cached = self.inMemorySet.first(where: { $0 == tmp }) else { return .newAsset }
            if let value = cached.fileNeedsToBeUploaded(on: identifier.modificationTime) {
                return value == 0 ? .skippable : .hasPendingUpload
            }
            return .needsDoubleCheck
        }
    }

    public func clean() {
        store = [:]
        queue.sync {
            self.inMemorySet = self.loadSetFromStore()
        }
    }

    private func loadSetFromStore() -> Set<InMemoryData> {
        var set: Set<InMemoryData> = Set()
        
        for (string, value) in store ?? [:] {
            var parts = string.components(separatedBy: Self.delimiter)
            
            let identifier = parts.removeFirst()
            
            var date: Date?
            if let time = parts.last, let double = TimeInterval(time) {
                date = Date(timeIntervalSinceReferenceDate: double)
            }
            let data: InMemoryData = .init(cloudIdentifier: identifier, data: [date: value])
            set.mergeableInsert(data)
        }
        return set
    }
    
    private func saveSetToStore(_ set: Set<InMemoryData>) {
        var dict = Store()
        for data in set {
            let exported = data.export()
            dict.merge(exported, uniquingKeysWith: { $1 })
        }
        self.store = dict
    }
}

final class InMemoryData: Hashable {
    private static let delimiter = "@"
    let cloudIdentifier: String
    /// [Modification date: file needs to be uploaded]
    private(set) var data: [Date?: Int] = [:]
    
    init(cloudIdentifier: String, data: [Date?: Int]) {
        self.cloudIdentifier = cloudIdentifier
        self.data = data
    }
    
    init(identifier: PhotoAssetMetadata.iOSPhotos, fileNeedsToBeUploaded: Int? = nil) {
        self.cloudIdentifier = identifier.identifier
        if let fileNeedsToBeUploaded {
            self.data = [identifier.modificationTime: fileNeedsToBeUploaded]
        } else {
            self.data = [:]
        }
    }
    
    func fileNeedsToBeUploaded(on date: Date?) -> Int? {
        data[date]
    }
    
    func merge(other: [Date?: Int]) {
        data.merge(other) { $1 }
    }
    
    func export() -> [String: Int] {
        var result: [String: Int] = [:]
        for (date, value) in data {
            var time = ""
            if let double = date?.timeIntervalSinceReferenceDate {
                time = "\(double)"
            }
            let string = cloudIdentifier + Self.delimiter + time
            result[string] = value
        }
        return result
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(cloudIdentifier)
    }
    
    static func == (lhs: InMemoryData, rhs: InMemoryData) -> Bool {
        lhs.cloudIdentifier == rhs.cloudIdentifier
    }
}

extension Set where Element == InMemoryData {
    mutating func mergeableInsert(_ element: InMemoryData) {
        if let cached = first(where: { $0 == element }) {
            cached.merge(other: element.data)
        } else {
            insert(element)
        }
    }
}
