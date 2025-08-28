// Copyright (c) 2025 Proton AG
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
import PDContacts

public protocol InviteeListLoadControllerProtocol {
    var publisher: AnyPublisher<Result<[InvitationInfoWrapper], Error>, Never> { get }

    func execute(shareID: String)
}

public final class InviteeListLoadController: InviteeListLoadControllerProtocol {
    private let dependencies: Dependencies
    private var cancellables = Set<AnyCancellable>()
    private var nameDictionary: [String: String] = [:]
    private var subject: PassthroughSubject<Result<[InvitationInfoWrapper], Error>, Never> = .init()
    public var publisher: AnyPublisher<Result<[InvitationInfoWrapper], Error>, Never> {
        subject.receive(on: DispatchQueue.main).eraseToAnyPublisher()
    }

    public init(dependencies: Dependencies) {
        self.dependencies = dependencies
        subscribeToUpdate()
    }

    public func execute(shareID: String) {
        dependencies.inviteeListLoadInteractor.execute(with: shareID)
    }

    private func subscribeToUpdate() {
        dependencies.inviteeListLoadInteractor.result
            .sink { [weak self] result in
                switch result {
                case .success(let list):
                    self?.handle(list: list)
                case .failure(let error):
                    self?.subject.send(.failure(error))
                }
            }
            .store(in: &cancellables)
    }

    private func handle(list: [any InviteeInfo]) {
        let mails = list.map(\.inviteeEmail)
        let mailsWithoutNameCache = mails.filter { nameDictionary[$0] == nil }
        Task {
            await queryName(of: mailsWithoutNameCache)
            let wrapperList = list
                .sorted(by: { $0.invitationID < $1.invitationID })
                .map { data in
                    let id = data.invitationID
                    let name = nameDictionary[data.inviteeEmail] ?? data.inviteeEmail
                    return InvitationInfoWrapper(id: id, name: name)
                }
            subject.send(.success(wrapperList))
        }
    }

    private func queryName(of emails: [String]) async {
        let remoteDic = await withTaskGroup(
            of: (String, String?).self,
            returning: [String: String].self
        ) { group in
            for email in emails {
                group.addTask {
                    let name = await self.dependencies.contactsController.name(of: email)
                    return (email, name)
                }
            }
            var remoteDic: [String: String] = [:]
            for await result in group {
                remoteDic[result.0] = result.1 ?? result.0
            }
            return remoteDic
        }
        await MainActor.run { self.nameDictionary.merge(remoteDic, uniquingKeysWith: { $1 }) }
    }
}

extension InviteeListLoadController {
    public struct Dependencies {
        let contactsController: ContactsControllerProtocol
        let inviteeListLoadInteractor: InviteeListLoadInteractor

        public init(
            contactsController: ContactsControllerProtocol,
            inviteeListLoadInteractor: InviteeListLoadInteractor
        ) {
            self.contactsController = contactsController
            self.inviteeListLoadInteractor = inviteeListLoadInteractor
        }
    }
}
