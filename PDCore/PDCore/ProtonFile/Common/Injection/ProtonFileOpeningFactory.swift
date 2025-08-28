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

import ProtonCoreAuthentication

public struct ProtonFileOpeningFactory {
    public init() {}

    public func makeNonAuthenticatedURLInteractor(tower: Tower) -> ProtonFileNonAuthenticatedURLInteractorProtocol {
        let identifierInteractor = makeIdentifierInteractor(tower: tower)
        let urlFactory = makeURLFactory(tower: tower)
        return ProtonFileNonAuthenticatedURLInteractor(identifierInteractor: identifierInteractor, urlFactory: urlFactory)
    }

    public func makeIdentifierInteractor(tower: Tower) -> ProtonFileIdentifierInteractorProtocol {
        let identifierResource = ProtonFileIdentifierRepository(sessionVault: tower.sessionVault, storageManager: tower.storage, managedObjectContext: tower.storage.mainContext)
        return ProtonFileIdentifierInteractor(parser: ProtonFileIncomingURLParser(), identifierResource: identifierResource)
    }

    public func makeURLFactory(tower: Tower) -> ProtonFileNonAuthenticatedURLFactoryProtocol {
        ProtonFileNonAuthenticatedURLFactory(configuration: tower.api.configuration)
    }

    public func makeAuthenticatedURLInteractor(tower: Tower, authenticator: Authenticator) -> ProtonFileAuthenticatedDataFacadeProtocol {
        let selectorRepository = ChildSessionSelectorRepository(sessionStorage: tower.sessionVault, authenticator: authenticator)
        let sessionInteractor = ProtonFileAuthenticatedWebSessionInteractor(sessionStore: tower.sessionVault, selectorRepository: selectorRepository, encryptionResource: CryptoKitAESGCMEncryptionResource(), encodingResource: FoundationEncodingResource())
        let urlFactory = ProtonFileAuthenticatedURLFactory(configuration: tower.api.configuration, nonAuthenticatedURLFactory: makeURLFactory(tower: tower))
        let authenticatedURLInteractor = ProtonFileAuthenticatedDataInteractor(sessionInteractor: sessionInteractor, urlFactory: urlFactory)
        return ProtonFileAuthenticatedDataFacade(interactor: authenticatedURLInteractor)
    }
}
