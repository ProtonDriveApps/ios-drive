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
}

public class UserDefaultsPhotosSkippableStorage: PhotosSkippableStorage {
    typealias Store = [String: Int]
    private static let delimiter = "@"
    
    @SettingsStorage("skippable-icloud-ids") private var store: Store?
    private let queue = DispatchQueue(label: "SkippableStorage", qos: .userInteractive, attributes: .concurrent)
    private var inMemory: [Identifier: Int]!
    
    public init() { }
    
    public subscript(index: Identifier) -> Int? {
        get {
            queue.sync {
                if inMemory == nil {
                    inMemory = self.loadFromStore()
                }
                return inMemory[index]
            }
        }
        set {
            queue.async(flags: .barrier) { [weak self] in
                self?.inMemory[index] = newValue
                self?.saveToStore(self!.inMemory)
            }
        }
    }
    
    private func saveToStore(_ original: [Identifier: Int]) {
        var dict = Store()
        for (key, value) in original {
            var time = ""
            if let double = key.modificationTime?.timeIntervalSinceReferenceDate {
                time = "\(double)"
            }
            let string = key.identifier + Self.delimiter + time
            dict[string] = value
        }
        self.store = dict
    }
    
    private func loadFromStore() -> [Identifier: Int] {
        var original = [Identifier: Int]()
        for (string, value) in store ?? [:] {
            var parts = string.components(separatedBy: Self.delimiter)
            
            let identifier = parts.removeFirst()
            
            var date: Date?
            if let time = parts.last, let double = TimeInterval(time) {
                date = Date(timeIntervalSinceReferenceDate: double)
            }
            let key = Identifier(identifier: identifier, modificationTime: date)
            
            original[key] = value
        }
        return original
    }
}
