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

import Foundation
import Combine
import PDClient

public final class SuspendableDownloader: Downloader, NetworkConstrained {

    private var cancellables = Set<AnyCancellable>()
    var networkMonitor: NetworkStateResource = MonitoringNetworkStateResource()
    var isNetworkReachable = true

    public required init(downloader: Downloader) {
        self.networkMonitor.execute()
        super.init(cloudSlot: downloader.cloudSlot, storage: downloader.storage, endpointFactory: downloader.endpointFactory)
        self.setupNetworkMonitoring()
    }

    public func invalidateOperations() {
        if isNetworkReachable {
            Log.info("SuspendableDownloader.invalidateOperations, cancel all operations when network is reachable", domain: .downloader)
            cancelAll()
        } else {
            Log.info("SuspendableDownloader.invalidateOperations, suspend all operations when network is not reachable", domain: .downloader)
            suspendAll()
        }
    }

    private func setupNetworkMonitoring() {
        networkMonitor.state
            .removeDuplicates()
            .sink { [weak self] state in
                Log.info("SuspendableDownloader.setupNetworkMonitoring, network state became: \(state)", domain: .downloader)
                switch state {
                case .reachable:
                    self?.isNetworkReachable = true
                    self?.retryQueuedUploadOperations()
                case .unreachable:
                    self?.isNetworkReachable = false
                    self?.handleNetworkUnreachable()
                }
            }
            .store(in: &cancellables)
    }

    private func retryQueuedUploadOperations() {
        resumeAll()
    }

    private func handleNetworkUnreachable() {
        suspendAll()
    }

    func suspendAll() {
        Log.info("suspendAllOperations on downloading queue, isSuspended: \(queue.isSuspended)", domain: .downloader)
        if queue.isSuspended == false {
            queue.isSuspended = true
        }
    }

    func resumeAll() {
        Log.info("resumeAllOperations on downloading queue, isSuspended: \(queue.isSuspended)", domain: .downloader)
        if queue.isSuspended == true {
            self.queue.isSuspended = false
        }
    }
}
