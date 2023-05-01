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
import PDCore

typealias URLResultBlock = (URLResult) -> Void

final class ItemProviderLoadOperation: AsynchronousOperation {
    private let resource: ItemProviderLoadResource
    private let itemProvider: NSItemProvider
    private let completion: URLResultBlock

    init(resource: ItemProviderLoadResource, itemProvider: NSItemProvider, completion: @escaping URLResultBlock) {
        self.resource = resource
        self.itemProvider = itemProvider
        self.completion = completion
    }

    override func main() {
        guard !isCancelled else {
            return
        }

        resource.execute(with: itemProvider) { [weak self] result in
            DispatchQueue.main.async {
                self?.completion(result)
                self?.state = .finished
            }
        }
    }
}
