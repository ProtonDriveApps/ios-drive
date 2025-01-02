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

class DownloadBinaryOperation: SynchronousOperation {
    let url: URL?
    var session: URLSession?
    // Task is held by the session, by making it weak the data involved in networking is released sooner.
    weak var task: URLSessionDownloadTask?

    init(url: URL?) {
        self.url = url
        self.session = URLSession.forDownloading()
        super.init()
    }

    override func cancel() {
        super.cancel()
        self.task?.cancel()
        if !Constants.downloaderUsesSharedURLSession {
            self.session?.invalidateAndCancel()
        }

        self.session = nil
        self.task = nil
    }
}
