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

import CoreData

class RevisionCommitterOperationFactory: FileUploadOperationFactory {

    let cloudRevisionCommitter: CloudRevisionCommitter
    let uploadedRevisionChecker: UploadedRevisionChecker
    let signersKitFactory: SignersKitFactoryProtocol
    let moc: NSManagedObjectContext

    init(
        cloudRevisionCommitter: CloudRevisionCommitter,
        uploadedRevisionChecker: UploadedRevisionChecker,
        signersKitFactory: SignersKitFactoryProtocol,
        moc: NSManagedObjectContext
    ) {
        self.cloudRevisionCommitter = cloudRevisionCommitter
        self.uploadedRevisionChecker = uploadedRevisionChecker
        self.signersKitFactory = signersKitFactory
        self.moc = moc
    }

    func make(from draft: FileDraft, completion: @escaping OnUploadCompletion) -> any UploadOperation {
        let committer = makeRevisionCommitter()
        return RevisionCommitterOperation(draft: draft, commiter: committer, onError: { completion(.failure($0)) })
    }

    func makeRevisionCommitter() -> RevisionCommitter {
        NewFileRevisionCommitter(cloudRevisionCommitter: cloudRevisionCommitter, uploadedRevisionChecker: uploadedRevisionChecker, signersKitFactory: signersKitFactory, moc: moc)
    }
}
