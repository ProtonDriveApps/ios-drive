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

import Foundation
import PDClient
import ProtonCoreDataModel

public struct CloudHierarchyDumper {
    public init() { }
    
    public func dump(client: Client, sessionVault: SessionVault, sorter: @escaping NodeProviderNameSorter, obfuscator: @escaping NodeProviderNameObfuscator) async throws -> String {
        try await dump(
            client: client,
            addresses: sessionVault.addresses!,
            userKeys: sessionVault.userInfo!.keys,
            userPassphrases: sessionVault.passphrases!,
            sorter: sorter,
            obfuscator: obfuscator
        )
    }
    
    // swiftlint:disable:next function_parameter_count
    public func dump(client: Client, addresses: [Address], userKeys: [AddressKey], userPassphrases: [SessionVault.AddressID: String], sorter: @escaping NodeProviderNameSorter, obfuscator: @escaping NodeProviderNameObfuscator) async throws -> String {
        
        let dumper = HierarchyDumper<CloudNodeProvider>(nameObfuscator: obfuscator, childSorter: sorter)
        
        var output = ""
        let volumes = try await client.getVolumes()
        for volume in volumes {
            let share = try await client.getShare(volume.share.shareID)
            let root = try await client.getLink(shareID: share.shareID, linkID: share.linkID, breadcrumbs: [])
            
            let decryptor = try ConcreteCloudNodeDecryptor(share: share, addresses: addresses, userKeys: userKeys, userPassphrases: userPassphrases)
            let childrenProvider = CloudChildrenProvider(shareID: share.shareID, client: client)
            
            let provider = CloudNodeProvider(
                node: root,
                decryptor: decryptor,
                childrenProvider: childrenProvider
            )
            output += try await dumper.dump(root: provider)
        }
        
        return output
    }
}
