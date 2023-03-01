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

extension Client {
    public func getSRPModulus(_ completion: @escaping (Result<Modulus, Error>) -> Void) {
        let endpoint = ShareSRPEndpoint(service: self.service)
        request(endpoint) { result in
            completion( result.flatMap { .success(.init(modulus: $0.modulus, modulusID: $0.modulusID)) })
        }
    }
    
    public func getVolumes(_ completion: @escaping (Result<[Volume], Error>) -> Void) {
        guard let credential = self.credentialProvider?.clientCredential() else {
            return completion(.failure(Errors.couldNotObtainCredential))
        }
        let endpoint = VolumesEndpoint(service: self.service, credential: credential)
        request(endpoint) { result in
            completion( result.flatMap { .success($0.volumes) })
        }
    }
    
    func getShares(_ completion: @escaping (Result<[ShareShort], Error>) -> Void) {
        guard let credential = self.credentialProvider?.clientCredential() else {
            return completion(.failure(Errors.couldNotObtainCredential))
        }
        let endpoint = SharesEndpoint(service: self.service, credential: credential)
        request(endpoint) { result in
            completion( result.flatMap { .success($0.shares) })
        }
    }
    
    public func getShare(_ id: ShareID, completion: @escaping (Result<Share, Error>) -> Void) {
        guard let credential = self.credentialProvider?.clientCredential() else {
            return completion(.failure(Errors.couldNotObtainCredential))
        }
        let endpoint = ShareEndpoint(volumeID: id, service: self.service, credential: credential)
        request(endpoint, completion: completion)
    }
    
    public func getShareUrl(_ id: ShareID, completion: @escaping (Result<[ShareURLMeta], Error>) -> Void) {
        guard let credential = self.credentialProvider?.clientCredential() else {
            return completion(.failure(Errors.couldNotObtainCredential))
        }
        let endpoint = ShareURLEndpoint(shareID: id, service: self.service, credential: credential)
        request(endpoint) {
            completion( $0.flatMap { .success($0.shareURLs) })
        }
    }
    
    public func getShareUrlRecursively(_ id: ShareID, page: Int = 0, pageSize size: Int = 0, completion: @escaping (Result<([Link], [ShareURLMeta]), Error>) -> Void) {
        guard let credential = self.credentialProvider?.clientCredential() else {
            return completion(.failure(Errors.couldNotObtainCredential))
        }
        
        let endpoint = ShareURLEndpoint(shareID: id, parameters: [.recursive, .page(page), .pageSize(size)], service: self.service, credential: credential)
        request(endpoint) {
            completion( $0.flatMap {
                let links = ($0.links != nil) ? Array($0.links!.values) : []
                let shareUrls = $0.shareURLs
                return .success((links, shareUrls))
            })
        }
    }
    
    public func getFolderChildren(_ shareID: ShareID, folderID: FolderID, parameters: [FolderChildrenEndpointParameters]? = nil, completion: @escaping (Result<[Link], Error>) -> Void) {
        guard let credential = self.credentialProvider?.clientCredential() else {
            return completion(.failure(Errors.couldNotObtainCredential))
        }
        let endpoint = FolderChildrenEndpoint(shareID: shareID, folderID: folderID, parameters: parameters, service: self.service, credential: credential)
        request(endpoint) {
            completion( $0.flatMap { .success($0.links) })
        }
    }
    
    public func getNode(_ shareID: ShareID, nodeID: FolderID, completion: @escaping (Result<Link, Error>) -> Void) {
        guard let credential = self.credentialProvider?.clientCredential() else {
            return completion(.failure(Errors.couldNotObtainCredential))
        }
        let endpoint = LinkEndpoint(shareID: shareID, linkID: nodeID, service: self.service, credential: credential)
        request(endpoint) {
            completion( $0.flatMap { .success($0.link) })
        }
    }
    
    public func getFolder(_ shareID: ShareID, folderID: FolderID, completion: @escaping (Result<Link, Error>) -> Void) {
        self.getNode(shareID, nodeID: folderID, completion: completion)
    }
    
    public func getFile(_ shareID: ShareID, fileID: FileID, completion: @escaping (Result<Link, Error>) -> Void) {
        self.getNode(shareID, nodeID: fileID, completion: completion)
    }
    
    public func getRevisions(_ shareID: ShareID, fileID: FileID, completion: @escaping (Result<[RevisionShort], Error>) -> Void) {
        guard let credential = self.credentialProvider?.clientCredential() else {
            return completion(.failure(Errors.couldNotObtainCredential))
        }
        let endpoint = RevisionsEndpoint(shareID: shareID, fileID: fileID, service: self.service, credential: credential)
        request(endpoint) {
            completion( $0.flatMap { .success($0.revisions) })
        }
    }
    
    public func getRevision(_ shareID: ShareID, fileID: FileID, revisionID: RevisionID, completion: @escaping (Result<Revision, Error>) -> Void) {
        guard let credential = self.credentialProvider?.clientCredential() else {
            return completion(.failure(Errors.couldNotObtainCredential))
        }
        let endpoint = RevisionEndpoint(shareID: shareID, fileID: fileID, revisionID: revisionID, service: self.service, credential: credential)
        request(endpoint) {
            completion( $0.flatMap { .success($0.revision) })
        }
    }
}

extension Client {
    public func postFile(_ shareID: ShareID, parameters: NewFileParameters, completion: @escaping (Result<NewFile, Error>) -> Void) {
        guard let credential = self.credentialProvider?.clientCredential() else {
            return completion(.failure(Errors.couldNotObtainCredential))
        }
        let endpoint = NewFileEndpoint(shareID: shareID, parameters: parameters, service: self.service, credential: credential)
        request(endpoint) {
            completion( $0.flatMap { .success($0.file) })
        }
    }

    public func postRevision(_ fileID: LinkID, shareID: ShareID, completion: @escaping (Result<NewRevision, Error>) -> Void) {
        guard let credential = self.credentialProvider?.clientCredential() else {
            return completion(.failure(Errors.couldNotObtainCredential))
        }
        let endpoint = NewRevisionEndpoint(fileID: fileID, shareID: shareID, service: self.service, credential: credential)
        request(endpoint) {
            completion( $0.flatMap { .success($0.revision) })
        }
    }

    public func deleteRevision(_ revisionID: RevisionID, _ fileID: LinkID, shareID: ShareID, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let credential = self.credentialProvider?.clientCredential() else {
            return completion(.failure(Errors.couldNotObtainCredential))
        }
        let endpoint = DeleteRevisionEndpoint(shareID: shareID, fileID: fileID, revisionID: revisionID, service: self.service, credential: credential)
        request(endpoint) { result in
            completion( result.map { _ in return Void() })
        }
    }

    public func postFolder(_ shareID: ShareID, parameters: NewFolderParameters, completion: @escaping (Result<NewFolder, Error>) -> Void) {
        guard let credential = self.credentialProvider?.clientCredential() else {
            return completion(.failure(Errors.couldNotObtainCredential))
        }
        let endpoint = NewFolderEndpoint(shareID: shareID, parameters: parameters, service: self.service, credential: credential)
        request(endpoint) {
            completion( $0.flatMap { .success($0.folder) })
        }
    }

    public func postBlocks(parameters: NewBlocksParameters, completion: @escaping (Result<(blocks: [BlockUploadLink], thumbnail: ThumbnailUploadLink?), Error>) -> Void) {
        guard let credential = self.credentialProvider?.clientCredential() else {
            return completion(.failure(Errors.couldNotObtainCredential))
        }
        let endpoint = NewBlocksEndpoint(parameters: parameters, service: self.service, credential: credential)
        request(endpoint) { result in
            completion( result.flatMap { .success((blocks: $0.uploadLinks, thumbnail: $0.thumbnailLink)) })
        }
    }

    public func postVolume(parameters: NewVolumeParameters, completion: @escaping (Result<NewVolume, Error>) -> Void) {
        guard let credential = self.credentialProvider?.clientCredential() else {
            return completion(.failure(Errors.couldNotObtainCredential))
        }
        let endpoint = NewVolumeEndpoint(parameters: parameters, service: self.service, credential: credential)
        request(endpoint) {
            completion( $0.flatMap { .success($0.volume) })
        }
    }

    public func postAvailableHashes(shareID: Share.ShareID, folderID: Link.LinkID, parameters: AvailableHashesParameters, completion: @escaping (Result<[String], Error>) -> Void) {
        guard let credential = self.credentialProvider?.clientCredential() else {
            return completion(.failure(Errors.couldNotObtainCredential))
        }
        let endpoint = AvailableHashesEndpoint(shareID: shareID, folderID: folderID, parameters: parameters, service: self.service, credential: credential)
        request(endpoint) {
            completion( $0.flatMap { .success($0.availableHashes) })
        }
    }

    public func postShare(volumeID: Volume.VolumeID, parameters: NewShareParameters, completion: @escaping (Result<Share.ShareID, Error>) -> Void) {
        guard let credential = self.credentialProvider?.clientCredential() else {
            return completion(.failure(Errors.couldNotObtainCredential))
        }
        let endpoint = NewShareEndpoint(volumeID: volumeID, parameters: parameters, service: self.service, credential: credential)
        request(endpoint) {
            completion( $0.flatMap { .success($0.share.ID) })
        }
    }

    public func deleteShare(id: ShareID, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let credential = self.credentialProvider?.clientCredential() else {
            return completion(.failure(Errors.couldNotObtainCredential))
        }
        let endpoint = DeleteShareEndpoint(shareID: id, service: self.service, credential: credential)
        request(endpoint) {
            completion( $0.flatMap { _ in .success })
        }
    }

    public func postShareURL(shareID: Share.ShareID, parameters: NewShareURLParameters, completion: @escaping (Result<ShareURLMeta, Error>) -> Void) {
        guard let credential = self.credentialProvider?.clientCredential() else {
            return completion(.failure(Errors.couldNotObtainCredential))
        }
        let endpoint = NewShareURLEndpoint(shareID: shareID, parameters: parameters, service: self.service, credential: credential)
        request(endpoint) {
            completion( $0.flatMap { .success($0.shareURL) })
        }
    }

    public func deleteShareURL(id shareURLID: String, shareID: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let credential = self.credentialProvider?.clientCredential() else {
            return completion(.failure(Errors.couldNotObtainCredential))
        }
        let endpoint = DeleteSecureLinkEndpoint(shareID: shareID, shareURLID: shareURLID, service: self.service, credential: credential)
        request(endpoint) {
            completion($0.flatMap { _ in .success })
        }
    }
}

extension Client {
    public func getRevisionThumbnailURL(_ shareID: ShareID, fileID: FileID, revisionID: RevisionID, completion: @escaping (Result<URL, Error>) -> Void) {
        guard let credential = credentialProvider?.clientCredential() else {
            return completion(.failure(Errors.couldNotObtainCredential))
        }

        let endpoint = RevisionThumbnailEndpoint(share: shareID, file: fileID, revision: revisionID, service: service, credential: credential)

        request(endpoint) {
            completion($0.flatMap { .success($0.thumbnailLink) })
        }
    }
}

extension Client {
    public func putRevision(shareID: Share.ShareID, fileID: Link.LinkID, revisionID: Revision.RevisionID, parameters: UpdateRevisionParameters, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let credential = self.credentialProvider?.clientCredential() else {
            return completion(.failure(Errors.couldNotObtainCredential))
        }
        let endpoint = UpdateRevisionEndpoint(shareID: shareID, fileID: fileID, revisionID: revisionID, parameters: parameters, service: self.service, credential: credential)
        request(endpoint) {
            completion( $0.flatMap { _ in .success(Void()) })
        }
    }

    public func putRenameNode(shareID: Share.ShareID, nodeID: Link.LinkID, parameters: RenameNodeParameters, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let credential = self.credentialProvider?.clientCredential() else {
            return completion(.failure(Errors.couldNotObtainCredential))
        }
        let endpoint = RenameNodeEndpoint(shareID: shareID, nodeID: nodeID, parameters: parameters, service: self.service, credential: credential)
        request(endpoint) {
            completion( $0.flatMap { _ in .success(Void()) })
        }
    }

    public func putMoveNode(shareID: Share.ShareID, nodeID: Link.LinkID, parameters: MoveNodeParameters, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let credential = self.credentialProvider?.clientCredential() else {
            return completion(.failure(Errors.couldNotObtainCredential))
        }
        let endpoint = MoveNodeEndpoint(shareID: shareID, nodeID: nodeID, parameters: parameters, service: self.service, credential: credential)
        request(endpoint) {
            completion( $0.flatMap { _ in .success(Void()) })
        }
    }

    public func putShareURL<Parameters: EditShareURLParameters>(shareURLID: ShareURLMeta.ID, shareID: Share.ShareID, parameters: Parameters, completion: @escaping (Result<ShareURLMeta, Error>) -> Void) {
        guard let credential = self.credentialProvider?.clientCredential() else {
            return completion(.failure(Errors.couldNotObtainCredential))
        }
        let endpoint = EditShareURLEndpoint(shareURLID: shareURLID, shareID: shareID, parameters: parameters, service: service, credential: credential)
        request(endpoint) {
            completion( $0.flatMap { .success($0.shareURL) })
        }
    }
}

extension Client {
    public func getLatestEvent(_ shareID: ShareID, completion: @escaping (Result<EventID, Error>) -> Void) {
        guard let credential = self.credentialProvider?.clientCredential() else {
            return completion(.failure(Errors.couldNotObtainCredential))
        }
        let endpoint = LatestEventEndpoint(shareID: shareID, service: self.service, credential: credential)
        request(endpoint) {
            completion( $0.flatMap { .success($0.eventID) })
        }
    }

    public func getEvents(_ shareID: ShareID, since lastKnown: EventID, completion: @escaping (Result<(EventID, [Event], MoreEvents), Error>) -> Void) {
        guard let credential = self.credentialProvider?.clientCredential() else {
            return completion(.failure(Errors.couldNotObtainCredential))
        }
        let endpoint = EventsEndpoint(shareID: shareID, since: lastKnown, service: self.service, credential: credential)
        request(endpoint) {
            completion(
                $0.flatMap { response in
                    if response.refresh == .true {
                        return .failure(RefreshError())
                    } else {
                        return .success((response.eventID, response.events, response.more == .true))
                    }
                }
            )
        }
    }
}

public struct RefreshError: Error { }

extension Client {
    public func getTrash(shareID: ShareID, page: Int, pageSize size: Int, completion: @escaping (Result<(trash: [Link], parents: [Link]), Error>) -> Void) {
        guard let credential = self.credentialProvider?.clientCredential() else {
            return completion(.failure(Errors.couldNotObtainCredential))
        }
        let endpoint = TrashListingEndpoint(shareID: shareID, parameters: [.page(page), .pageSize(size)], service: service, credential: credential)
        request(endpoint) {
            completion( $0.flatMap { .success(($0.links, Array($0.parents.values.map { $0 }))) })
        }
    }

    public func trashNodes(shareID: ShareID, parentLinkID: LinkID, linkIDs: [LinkID], completion: @escaping (Result<Void, Error>) -> Void) {
        guard let credential = self.credentialProvider?.clientCredential() else {
            return completion(.failure(Errors.couldNotObtainCredential))
        }
        let parameters = TrashLinkEndpoint.Parameters(shareID: shareID, parentLinkID: parentLinkID, linkIDs: linkIDs)
        let endpoint = TrashLinkEndpoint(parameters: parameters, service: service, credential: credential)
        request(endpoint, completion: {
            completion($0.flatMap { _ -> Result<Void, Error> in
                .success
            })
        })
    }

    public func deletePermanently(shareID: ShareID, linkIDs: [LinkID], completion: @escaping (Result<Void, Error>) -> Void) {
        guard let credential = self.credentialProvider?.clientCredential() else {
            return completion(.failure(Errors.couldNotObtainCredential))
        }
        let parameters = DeleteLinkEndpoint.Parameters(shareID: shareID, linkIDs: linkIDs)
        let endpoint = DeleteLinkEndpoint(parameters: parameters, service: service, credential: credential)
        request(endpoint, completion: {
            completion($0.flatMap { _ in .success(()) })
        })
    }

    public func deleteLinkInFolderPermanently(shareID: ShareID, folderID: LinkID, linkIDs: [LinkID], completion: @escaping (Result<Void, Error>) -> Void) {
        guard let credential = self.credentialProvider?.clientCredential() else {
            return completion(.failure(Errors.couldNotObtainCredential))
        }
        let parameters = DeleteLinkInFolderEndpoint.Parameters(shareID: shareID, folderID: folderID, linkIDs: linkIDs)
        let endpoint = DeleteLinkInFolderEndpoint(parameters: parameters, service: service, credential: credential)
        request(endpoint, completion: {
            completion($0.flatMap { _ in .success(()) })
        })
    }

    public func emptyTrash(shareID: ShareID, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let credential = self.credentialProvider?.clientCredential() else {
            return completion(.failure(Errors.couldNotObtainCredential))
        }
        let endpoint = EmptyTrashEndpoint(shareID: shareID, service: service, credential: credential)
        request(endpoint) {
            completion($0.flatMap { _ in .success(()) })
        }
    }

    public func retoreTrashNode(shareID: ShareID, linkIDs: [LinkID], completion: @escaping (Result<[PartialFailure], Error>) -> Void) {
        guard let credential = self.credentialProvider?.clientCredential() else {
            return completion(.failure(Errors.couldNotObtainCredential))
        }
        let parameters = RestoreLinkEndpoint.Parameters(shareID: shareID, linkIDs: linkIDs)
        let endpoint = RestoreLinkEndpoint(parameters: parameters, service: service, credential: credential)
        request(endpoint, completion: {
            completion($0.flatMap { response -> Result<[PartialFailure], Error> in
                let failed = response.responses.compactMap(PartialFailure.init)
                return .success(failed)
            })
        })
    }
}

public struct PartialFailure {
    public let id: String
    public let error: Error

    init?(_ response: ResponseElement) {
        guard let id = response.linkID,
              let code = response.response?.code,
              let error = response.response?.error
        else { return nil }
        
        var description = error
        if let errorMessage = response.response?.errorDescription, !errorMessage.isEmpty {
            description = errorMessage
        }

        self.id = id
        self.error = NSError(domain: error, code: code, localizedDescription: description)
    }
}

public extension Result where Success == Void {
  static var success: Result { .success(()) }
}
