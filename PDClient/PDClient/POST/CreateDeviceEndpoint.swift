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

/// Create a new Device
/// - POST: /drive/devices
public struct CreateDeviceEndpoint: Endpoint {

    public var request: URLRequest

    public init(parameters: Parameters, service: APIService, credential: ClientCredential) throws {
        let url = service.url(of: "/devices")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        var headers = service.baseHeaders
        headers.merge(service.authHeaders(credential), uniquingKeysWith: { $1 })
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        let body = try JSONEncoder().encode(parameters.body)

        request.httpBody = body

        self.request = request
    }
}

extension CreateDeviceEndpoint {
    public struct Response: Codable {
        public let code: Int
        public let device: Device

        public init(code: Int, device: CreateDeviceEndpoint.Response.Device) {
            self.code = code
            self.device = device
        }

        public struct Device: Codable {
            public let deviceID: String
            public let shareID: String
            public let linkID: String

            public init(deviceID: String, shareID: String, linkID: String) {
                self.deviceID = deviceID
                self.shareID = shareID
                self.linkID = linkID
            }
        }
    }

    public struct Parameters {
        let body: Body

        struct Body: Codable {
            let device: Device
            let share: Share
            let link: Link
            
            enum CodingKeys: String, CodingKey {
                case device = "Device"
                case share = "Share"
                case link = "Link"
            }
        }

        struct Device: Codable {
            let volumeID: String
            let syncState: SyncState
            let type: ´Type´

            enum SyncState: Int, Codable {
                case off = 0
                case on = 1
            }

            enum ´Type´: Int, Codable {
                case windows = 1
                case macOS = 2
                case linux = 3
                case photos = 4
            }
            
            enum CodingKeys: String, CodingKey {
                case volumeID = "VolumeID"
                case syncState = "SyncState"
                case type = "Type"
            }
        }

        struct Share: Codable {
            let addressID: String
            let addressKeyID: String
            let key: String
            let passphrase: String
            let passphraseSignature: String
            
            enum CodingKeys: String, CodingKey {
                case addressID = "AddressID"
                case addressKeyID = "AddressKeyID"
                case key = "Key"
                case passphrase = "Passphrase"
                case passphraseSignature = "PassphraseSignature"
            }
        }

        struct Link: Codable {
            let nodeKey: String
            let nodePassphrase: String
            let nodePassphraseSignature: String
            let nodeHashKey: String
            let name: String
            
            enum CodingKeys: String, CodingKey {
                case nodeKey = "NodeKey"
                case nodePassphrase = "NodePassphrase"
                case nodePassphraseSignature = "NodePassphraseSignature"
                case nodeHashKey = "NodeHashKey"
                case name = "Name"
            }
        }
    }
}
