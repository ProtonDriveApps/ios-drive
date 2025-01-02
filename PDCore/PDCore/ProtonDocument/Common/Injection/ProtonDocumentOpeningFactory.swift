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

public struct ProtonDocumentOpeningFactory {
    public init() {}

    public func makeNonAuthenticatedURLInteractor(tower: Tower) -> ProtonDocumentNonAuthenticatedURLInteractorProtocol {
        let identifierInteractor = makeIdentifierInteractor(tower: tower)
        let urlFactory = makeURLFactory(tower: tower)
        return ProtonDocumentNonAuthenticatedURLInteractor(identifierInteractor: identifierInteractor, urlFactory: urlFactory)
    }

    public func makeIdentifierInteractor(tower: Tower) -> ProtonDocumentIdentifierInteractorProtocol {
        let identifierResource = ProtonDocumentIdentifierRepository(sessionVault: tower.sessionVault, storageManager: tower.storage, managedObjectContext: tower.storage.mainContext)
        return ProtonDocumentIdentifierInteractor(parser: ProtonDocumentIncomingURLParser(), identifierResource: identifierResource)
    }

    public func makeURLFactory(tower: Tower) -> ProtonDocumentNonAuthenticatedURLFactoryProtocol {
        ProtonDocumentNonAuthenticatedURLFactory(configuration: tower.api.configuration)
    }

    public func makeAuthenticatedURLInteractor(tower: Tower, authenticator: Authenticator) -> ProtonDocumentAuthenticatedDataFacadeProtocol {
        let selectorRepository = ChildSessionSelectorRepository(sessionStorage: tower.sessionVault, authenticator: authenticator)
        let sessionInteractor = ProtonDocumentAuthenticatedWebSessionInteractor(sessionStore: tower.sessionVault, selectorRepository: selectorRepository, encryptionResource: CryptoKitAESGCMEncryptionResource(), encodingResource: FoundationEncodingResource())
        let urlFactory = ProtonDocumentAuthenticatedURLFactory(configuration: tower.api.configuration, nonAuthenticatedURLFactory: makeURLFactory(tower: tower))
        let authenticatedURLInteractor = ProtonDocumentAuthenticatedDataInteractor(sessionInteractor: sessionInteractor, urlFactory: urlFactory)
        return ProtonDocumentAuthenticatedDataFacade(interactor: authenticatedURLInteractor)
    }
}
