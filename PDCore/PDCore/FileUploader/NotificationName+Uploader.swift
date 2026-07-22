// Copyright (c) 2026 Proton AG
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

public extension Notification.Name {
    static var scheduleUploads: Notification.Name {
        Notification.Name("ch.protonmail.protondrive.uploadFiles")
    }
    
    static var uploadPendingPhotos: Notification.Name {
        Notification.Name("ch.protonmail.protondrive.uploadPendingPhotos")
    }
    
    static var didUploadPhoto: Notification.Name {
        Notification.Name("ch.protonmail.protondrive.didUploadPhoto")
    }
    
    static var didImportPhotos: Notification.Name {
        Notification.Name("ch.protonmail.protondrive.didImportPhotos")
    }
    
    static var backgroundPhotosProcessing: Notification.Name {
        Notification.Name("ch.protonmail.protondrive.photosProcessing")
    }
    
    static var didInterruptOnPhotoUpload: Notification.Name {
        Notification.Name("ch.protonmail.protondrive.didInterruptOnPhotoUpload")
    }
    
    static var didInterruptOnFileUpload: Notification.Name {
        Notification.Name("ch.protonmail.protondrive.didInterruptOnFileUpload")
    }
    
    static var didUploadFile: Notification.Name {
        Notification.Name("ch.protonmail.protondrive.didUploadFile")
    }
    
    static var didFindIssueOnFileUpload: Notification.Name {
        Notification.Name("ch.protonmail.protondrive.didFindIssueOnFileUpload")
    }

}
