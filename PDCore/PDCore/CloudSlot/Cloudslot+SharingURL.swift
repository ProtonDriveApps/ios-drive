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

import PDClient

extension CloudSlot {
    func getSRPModulus(completion: @escaping (Result<Modulus, Error>) -> Void) {
        client.getSRPModulus(completion)
    }

    func createShareURL(shareID: ShareMeta.ShareID, parameters: NewShareURLParameters, completion: @escaping (Result<ShareURLMeta, Error>) -> Void) {
        client.postShareURL(shareID: shareID, parameters: parameters, completion: completion)
    }

    func updateShareURL<Parameters: EditShareURLParameters>(shareURLID: ShareURLMeta.ID, shareID: ShareMeta.ShareID, parameters: Parameters, completion: @escaping (Result<ShareURLMeta, Error>) -> Void) {
        client.putShareURL(shareURLID: shareURLID, shareID: shareID, parameters: parameters, completion: completion)
    }

    func deleteShareURL(_ shareURL: ShareURL, completion: @escaping (Result<Void, Error>) -> Void) {
        let moc = storage.backgroundContext
        let mocUI = storage.mainContext

        moc.perform {
            let shareURL = shareURL.in(moc: moc)
            let id = shareURL.id
            let shareID = shareURL.shareID

            self.client.deleteShareURL(id: id, shareID: shareID) { [weak self] resultShareURL in
                guard let self = self else { return }

                switch resultShareURL {
                case .success:
                    // we can not rollback the deletion process once it had started
                    // so further error cases do not make any difference
                    // we need to clear this out of local db

                    self.client.deleteShare(id: shareID) { _ in
                        mocUI.performAndWait {
                            let shareURLUI = shareURL.in(moc: mocUI)
                            let share = shareURLUI.share
                            // ⚠️ we are changing `isShared` property of the Node assuming that the share has been successfully removed to increase UX friendliness
                            share.root?.isShared = false
                            share.shareUrls.forEach(mocUI.delete)
                            mocUI.delete(share)
                            try? mocUI.saveWithParentLinkCheck()
                            completion(.success)
                        }
                    }

                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }
}
