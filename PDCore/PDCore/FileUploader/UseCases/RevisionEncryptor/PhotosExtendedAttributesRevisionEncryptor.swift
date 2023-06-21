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
import CoreData

final class PhotosExtendedAttributesRevisionEncryptor: ExtendedAttributesRevisionEncryptor {
    
    override func getXAttrs(_ draft: CreatedRevisionDraft) throws -> Data {
        guard let revision = draft.revision as? PhotoRevision else {
            throw draft.revision.invalidState("The item is not a Photo")
        }
        
        let commonAttributes = commonAttributes(draft)
        return try moc.performAndWait {
            let revision = revision.in(moc: moc)
            let photo = revision.photo
            let tempMetadata = TemporalMetadata(base64String: photo.tempBase64Metadata)

            return try ExtendedAttributes(
                common: commonAttributes,
                location: tempMetadata?.location,
                camera: tempMetadata?.camera,
                media: tempMetadata?.media,
                iOSPhotos: tempMetadata?.iOSPhotos
            ).encoded()
        }
    }
    
}
