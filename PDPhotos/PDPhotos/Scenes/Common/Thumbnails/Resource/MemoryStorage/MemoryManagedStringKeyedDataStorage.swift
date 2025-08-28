// Copyright (c) 2024 Proton AG
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
import UIKit

final class MemoryManagedStringKeyedDataStorage: StringKeyedDataStorage {
    struct Configuration {
        let countLimit: Int
        let totalCostLimit: Int
    }

    private let configuration: Configuration
    private var cache = NSCache<NSString, NSData>()
    private var observer: Any?

    init(configuration: Configuration) {
        self.configuration = configuration
        reload()
        observer = NotificationCenter.default.addObserver(forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: OperationQueue.main) { [weak self] _ in
            self?.reload()
        }
    }

    deinit {
        observer.map { NotificationCenter.default.removeObserver($0) }
    }

    @objc private func reload() {
        cache = NSCache<NSString, NSData>()
        cache.countLimit = configuration.countLimit
        cache.totalCostLimit = configuration.totalCostLimit
    }

    func store(data: Data, key: String) {
        let item = data as NSData
        cache.setObject(item, forKey: key as NSString)
    }

    func load(with key: String) -> Data? {
        cache.object(forKey: key as NSString) as? Data
    }
}
