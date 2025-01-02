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

public struct NewShare: Codable {
    public var ID: String
    public var linkID: String
    
    public init(ID: String, linkID: String) {
        self.ID = ID
        self.linkID = linkID
    }
}

public struct NewVolume: Codable {
    public var ID: String
    public var share: NewShare
    
    public init(ID: String, share: NewShare) {
        self.ID = ID
        self.share = share
    }
}

public class NewVolumeParameters: Codable {
    public init(
        addressID: String,
        addressKeyID: String,
        shareKey: String,
        sharePassphrase: String,
        sharePassphraseSignature: String,
        folderName: String,
        folderKey: String,
        folderPassphrase: String,
        folderPassphraseSignature: String,
        folderHashKey: String
    ){
        self.AddressID = addressID
        self.AddressKeyID = addressKeyID
        self.ShareKey = shareKey
        self.SharePassphrase = sharePassphrase
        self.SharePassphraseSignature = sharePassphraseSignature
        self.FolderName = folderName
        self.FolderKey = folderKey
        self.FolderPassphrase = folderPassphrase
        self.FolderPassphraseSignature = folderPassphraseSignature
        self.FolderHashKey = folderHashKey
    }

    var AddressID: String
    var AddressKeyID: String
    var ShareKey: String
    var SharePassphrase: String
    var SharePassphraseSignature: String
    var FolderName: String
    var FolderKey: String
    var FolderPassphrase: String
    var FolderPassphraseSignature: String
    var FolderHashKey: String
}

public struct NewVolumeEndpoint: Endpoint {
    public struct Response: Codable {
        var code: Int
        var volume: NewVolume
        
        public init(code: Int, volume: NewVolume) {
            self.code = code
            self.volume = volume
        }
    }
    
    public var request: URLRequest
    
    init(parameters: NewVolumeParameters, service: APIService, credential: ClientCredential) {
        // url
        let url = service.url(of: "/volumes")
        
        // request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // headers
        var headers = service.baseHeaders
        headers.merge(service.authHeaders(credential), uniquingKeysWith: { $1 })
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        
        request.httpBody = try? JSONEncoder().encode(parameters)
        
        self.request = request
    }
}
