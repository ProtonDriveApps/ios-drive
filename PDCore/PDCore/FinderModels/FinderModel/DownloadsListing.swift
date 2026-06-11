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

public protocol DownloadsListing: AnyObject {
    var tower: Tower! { get }
}

public typealias ProgressTrackers = [String: ProgressTracker]

extension DownloadsListing {
    @MainActor
    public func childrenDownloading() -> AnyPublisher<ProgressTrackers, Error> {
        let legacyPublisher = tower.downloader!.downloadProcessesAndErrors()
        if let sdkDownloader = tower.getSdkFileDownloader() {
            let sdkPublisher = makeSDKProgresses(sdkDownloader: sdkDownloader)
            return legacyPublisher
                .combineLatest(sdkPublisher)
                .map { legacyProgresses, sdkProgresses in
                    return legacyProgresses.merging(sdkProgresses, uniquingKeysWith: { $1 })
                }
                .mapError { $0 }
                .eraseToAnyPublisher()
        } else {
            return legacyPublisher
        }
    }

    @MainActor
    private func makeSDKProgresses(sdkDownloader: SDKFileDownloaderProtocol) -> AnyPublisher<ProgressTrackers, Error> {
        let failurePublisher = sdkDownloader.failures
            .first() // only care about the first emission
            .flatMap { value in
                Fail<ProgressTrackers, Error>(error: value.1)
            }
            .eraseToAnyPublisher()
        let combinedPublisher = sdkDownloader.progresses
            .map { progresses in
                let keysAndValues = progresses.map { progressEntry in
                    let progress = progressEntry.value
                    progress.fileURL = URL(string: progressEntry.key.id) // This is necessary to `match` progresses against files
                    return (progressEntry.key.id, ProgressTracker(progress: progress, direction: .downstream))
                }
                return Dictionary(uniqueKeysWithValues: keysAndValues)
            }
            .setFailureType(to: Error.self)
            .merge(with: failurePublisher)
        return combinedPublisher.eraseToAnyPublisher()
    }

    public func download(node: Node, useRefreshableDownloadOperation: Bool = false) {
        let file = node as! File // TODO: later will need to download folders as trees
        tower.downloader?.scheduleDownloadWithBackgroundSupport(
            cypherdataFor: file,
            useRefreshableDownloadOperation: useRefreshableDownloadOperation
        ) { result in
            switch result {
            case .success(let file):
                _ = try? file.activeRevision?.decryptFile()
            case .failure:
                break
            }
        }
    }
}
