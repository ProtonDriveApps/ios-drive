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

import PDCore
import PDClient

struct PhotoRemoteFilterFactory {
    func makeRemoteFilterInteractor(tower: Tower, circuitBreaker: CircuitBreakerController) -> PhotoAssetCompoundsConflictInteractor {
        let observer = FetchedResultsControllerObserver(controller: tower.storage.subscriptionToPhotoShares(moc: tower.storage.backgroundContext))
        let rootDataSource = PhotosRepositoriesFactory().makeEncryptingRepository(tower: tower)
        let photoShareDataSource = PhotosFactory().makeLocalPhotosRootDataSource(observer: observer)
        let hashResource = FileStreamHashResource(digestBuilderFactory: { SHA1DigestBuilder() })
        let hashInteractor = LocalPhotoContentHashInteractor(hashResource: hashResource, rootDataSource: rootDataSource, encryptionResource: CoreEncryptionResource())
        let nameConflictsInteractor = RemotePhotoNameConflictsInteractor(
            identifiersInteractor: LocalPhotoAssetIdentifiersInteractor(rootDataSource: rootDataSource, encryptionResource: CoreEncryptionResource(), validator: DefaultNodeValidator()),
            volumeIdDataSource: DatabasePhotosVolumeIdDataSource(photoShareDataSource: photoShareDataSource),
            duplicatesRepository: tower.client,
            nameHashesStrategy: LocalPhotoConflictNameHashesStrategy(), circuitBreaker: circuitBreaker
        )
        let linkIdRepository = ConcreteLocalPhotoLinkIdRepository(storageManager: tower.storage, managedObjectContext: tower.storage.newBackgroundContext())
        let validator = ConcretePhotoConflictRemoteCheckValidator(hashInteractor: hashInteractor, clientUIDProvider: tower.sessionVault, linkIdRepository: linkIdRepository)
        let contentConflictsInteractor = RemotePhotoContentConflictsInteractor(validator: validator)
        return ConcretePhotoAssetCompoundsConflictInteractor(
            nameConflictsInteractor: nameConflictsInteractor,
            contentConflictsInteractor: contentConflictsInteractor
        )
    }
}
