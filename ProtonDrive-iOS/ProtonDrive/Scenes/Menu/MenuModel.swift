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
import Combine
import PDCore

class MenuModel {
    
    var userInfoPublisher: AnyPublisher<UserInfo, Never> {
        userInfo.eraseToAnyPublisher()
    }
    var accountInfoPublisher: AnyPublisher<AccountInfo, Never> {
        accountInfo.eraseToAnyPublisher()
    }

    private let sessionVault: SessionVault
    private let userInfo: CurrentValueSubject<UserInfo, Never>
    private let accountInfo: CurrentValueSubject<AccountInfo, Never>
    private var cancellables = Set<AnyCancellable>()
    
    init(sessionVault: SessionVault) {
        self.sessionVault = sessionVault
        
        self.userInfo = .init(sessionVault.getUserInfo() ?? .blank)
        self.accountInfo = .init(sessionVault.getAccountInfo() ?? .blank)
        
        sessionVault
            .objectWillChange
            .throttle(for: .milliseconds(500), scheduler: DispatchQueue.main, latest: true)
            .compactMap { sessionVault.getUserInfo() }
            .replaceNil(with: .blank)
            .removeDuplicates()
            .subscribe(userInfo)
            .store(in: &cancellables)
        
        sessionVault
            .objectWillChange
            .throttle(for: .milliseconds(500), scheduler: DispatchQueue.main, latest: true)
            .compactMap { sessionVault.getAccountInfo() }
            .replaceNil(with: .blank)
            .removeDuplicates()
            .subscribe(accountInfo)
            .store(in: &cancellables)
    }

}

extension UserInfo {
    static var blank: UserInfo = .init(usedSpace: 0, maxSpace: 1, invoiceState: .onTime)
}

extension AccountInfo {
    static var blank: AccountInfo = .init(email: "", displayName: "")
}
