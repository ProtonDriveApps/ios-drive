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
import Combine
import PDUIComponents

class MenuViewModel: ObservableObject, LogoutRequesting {
    typealias ProgressMenuSectionViewModel = ProgressMenuSectionViewModelGeneric<OfflineSaver>

    private let model: MenuModel
    private let offlineSaver: OfflineSaver
    let downloads: ProgressMenuSectionViewModel
    private let logLoader: LogContentLoader?

    @Published var accountInfo: AccountInfo = .blank
    @Published var usagePercent: Double = 0.0
    @Published var usageBreakdown: String = ""
    @Published var isStorageButtonAvailable: Bool = false
    @Published var logsShareURL: URL?
    @Published var loadingLogs: Bool = false

    private var cancellables: Set<AnyCancellable> = []
    private let selectedScreenSubject = CurrentValueSubject<Destination, Never>(.myFiles)
    var selectedScreenPublisher: AnyPublisher<Destination, Never> {
        selectedScreenSubject.eraseToAnyPublisher()
    }

    init(model: MenuModel, offlineSaver: OfflineSaver, logLoader: LogContentLoader?) {
        self.model = model
        self.offlineSaver = offlineSaver
        self.logLoader = logLoader
        self.downloads = ProgressMenuSectionViewModel(
            progressProvider: offlineSaver,
            steadyTitle: "Available offline",
            inProgressTitle: "Downloading files...",
            iconName: "ic-availableoffline"
        )
    }

    lazy var appVersion: String = {
        let dictionary = Bundle.main.infoDictionary!
        let name = dictionary["CFBundleDisplayName"] as? String
        let version = dictionary["CFBundleShortVersionString"] as? String
        let build = dictionary["CFBundleVersion"] as? String
        return "\(name ?? "") v\(version ?? "") (\(build ?? ""))"
    }()

    private func apply(userInfo: UserInfo) {
        usagePercent = userInfo.usedSpace / max(userInfo.maxSpace, 1)
        usageBreakdown = "\(ByteCountFormatter.storageSizeString(forByteCount: userInfo.usedSpace)) of \(ByteCountFormatter.storageSizeString(forByteCount: userInfo.maxSpace)) used"
        isStorageButtonAvailable = !userInfo.isPaid
    }

    func subscribeToUserInfoChanges() {
        model.userInfoPublisher
            .receive(on: DispatchQueue.main)
            .sink { [unowned self] in apply(userInfo: $0) }
            .store(in: &cancellables)
        
        model.accountInfoPublisher
            .receive(on: DispatchQueue.main)
            .sink { [unowned self] in self.accountInfo = $0 }
            .store(in: &cancellables)
    }

    func go(to destination: Destination) {
        selectedScreenSubject.send(destination)
    }

    func accountHeaderViewModel() -> AccountHeaderViewModel {
        AccountHeaderViewModel(name: accountInfo.displayName, email: accountInfo.email)
    }
}

extension MenuViewModel {
    enum Destination: Equatable {
        case myFiles
        case servicePlans
        case accountManager
        case trash
        case offlineAvailable
        case settings
        case feedback
        case logout
    }
}

extension OfflineSaver: ProgressFractionCompletedProvider {}
