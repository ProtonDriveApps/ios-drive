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

public struct NewPhotoShare {
    let addressID: String
    let addressKeyID: String
    let volumeID: String
    let shareName: String
    let shareKey: String
    let sharePassphrase: String
    let sharePassphraseSignature: String
    let nodeName: String
    let nodeKey: String
    let nodePassphrase: String
    let nodePassphraseSignature: String
    let nodeHashKey: String

    public init(
        addressID: String,
        addressKeyID: String,
        volumeID: String,
        shareName: String,
        shareKey: String,
        sharePassphrase: String,
        sharePassphraseSignature: String,
        nodeName: String,
        nodeKey: String,
        nodePassphrase: String,
        nodePassphraseSignature: String,
        nodeHashKey: String
    ) {
        self.addressID = addressID
        self.addressKeyID = addressKeyID
        self.volumeID = volumeID
        self.shareName = shareName
        self.shareKey = shareKey
        self.sharePassphrase = sharePassphrase
        self.sharePassphraseSignature = sharePassphraseSignature
        self.nodeName = nodeName
        self.nodeKey = nodeKey
        self.nodePassphrase = nodePassphrase
        self.nodePassphraseSignature = nodePassphraseSignature
        self.nodeHashKey = nodeHashKey
    }
}
