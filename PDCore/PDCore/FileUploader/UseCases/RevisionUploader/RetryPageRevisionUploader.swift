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

class RetryPageRevisionUploader: PageRevisionUploader {
    let decoratee: PageRevisionUploader
    let maximumRetryCount: Int
    let retryDelay: TimeInterval

    private var retryCount = 0

    init(decoratee: PageRevisionUploader, maximumRetryCount: Int, retryDelay: TimeInterval) {
        self.decoratee = decoratee
        self.maximumRetryCount = maximumRetryCount
        self.retryDelay = retryDelay
    }

    func upload(completion: @escaping (Result<Void, Error>) -> Void) {
        decoratee.upload { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success:
                completion(.success(()))
            case .failure(let error):
                if self.retryCount < self.maximumRetryCount {
                    self.retryCount += 1
                    DispatchQueue.main.asyncAfter(deadline: .now() + self.retryDelay) {
                        self.upload(completion: completion)
                    }
                } else {
                    completion(.failure(error))
                }
            }
        }
    }

    func cancel() {
        decoratee.cancel()
    }
}
