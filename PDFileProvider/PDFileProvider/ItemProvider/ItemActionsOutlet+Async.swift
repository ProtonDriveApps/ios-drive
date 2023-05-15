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

import FileProvider
import PDCore
import os.log

extension ItemActionsOutlet {

    public func deleteItem(tower: Tower,
                           identifier: NSFileProviderItemIdentifier,
                           baseVersion version: NSFileProviderItemVersion? = nil,
                           options: NSFileProviderDeleteItemOptions = [],
                           request: NSFileProviderRequest? = nil) async throws
    {
        try await withUnsafeThrowingContinuation { continuation in
            self.deleteItem(tower: tower, identifier: identifier) { error in
                if let error = error {
                    continuation.resume(with: .failure(error))
                } else {
                    continuation.resume(with: .success)
                }
            }
        } as Void
    }
    
    public func modifyItem(tower: Tower,
                           item: NSFileProviderItem,
                           baseVersion version: NSFileProviderItemVersion? = nil,
                           changedFields: NSFileProviderItemFields,
                           contents newContents: URL?,
                           options: NSFileProviderModifyItemOptions? = nil,
                           request: NSFileProviderRequest? = nil) async throws -> (NSFileProviderItem?, NSFileProviderItemFields, Bool)
    {
        try await withCheckedThrowingContinuation { continuation in
            self.modifyItem(tower: tower, item: item, changedFields: changedFields, contents: newContents) { item, fields, flag, error in
                if let error = error {
                    continuation.resume(with: .failure(error))
                } else {
                    continuation.resume(with: .success((item, fields, flag)))
                }
            }
        }
    }
    
    public func createItem(tower: Tower,
                           basedOn itemTemplate: NSFileProviderItem,
                           fields: NSFileProviderItemFields = [],
                           contents url: URL?,
                           options: NSFileProviderCreateItemOptions = [],
                           request: NSFileProviderRequest? = nil) async throws -> (NSFileProviderItem?, NSFileProviderItemFields, Bool)
    {
        try await withCheckedThrowingContinuation { continuation in
            self.createItem(tower: tower, basedOn: itemTemplate, fields: fields, contents: url, options: options, request: request) { item, fields, flag, error in
                if let error = error {
                    continuation.resume(with: .failure(error))
                } else {
                    continuation.resume(with: .success((item, fields, flag)))
                }
            }
        }
    }

}
