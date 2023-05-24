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
import Foundation

protocol FolderUpdateResource {
    var updatePublisher: AnyPublisher<Void, Never> { get }
    func execute(with url: URL)
    func cancel()
}

final class LocalFolderUpdateResource: FolderUpdateResource {
    private let queue = DispatchQueue(label: "LocalFolderUpdateResourceQueue")
    private var folderDescriptor: Int32 = -1
    private var source: DispatchSourceFileSystemObject?
    private let updateSubject = PassthroughSubject<Void, Never>()

    var updatePublisher: AnyPublisher<Void, Never> {
        updateSubject.eraseToAnyPublisher()
    }

    func execute(with url: URL) {
        cancel()

        folderDescriptor = open(url.path, O_EVTONLY)
        source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: folderDescriptor,
            eventMask: [.write, .delete],
            queue: queue
        )
        source?.setEventHandler { [weak self] in
            self?.updateSubject.send()
        }
        source?.setCancelHandler { [weak self] in
            self?.cancel()
        }
        source?.resume()
    }

    func cancel() {
        close(folderDescriptor)
        folderDescriptor = -1
        source?.cancel()
        source = nil
    }

    deinit {
        cancel()
    }
}
