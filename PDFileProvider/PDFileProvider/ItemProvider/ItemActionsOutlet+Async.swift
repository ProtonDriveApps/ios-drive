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
import Foundation
import PDCore
import os.log

// swiftlint:disable function_parameter_count
extension ItemActionsOutlet {

    public func deleteItem(tower: Tower,
                           identifier: NSFileProviderItemIdentifier,
                           baseVersion version: NSFileProviderItemVersion?,
                           options: NSFileProviderDeleteItemOptions = [],
                           request: NSFileProviderRequest? = nil,
                           completionHandler: @escaping (Error?) -> Void) -> Progress
    {
        let version = version ?? NSFileProviderItemVersion()

        Task {
            do {
                try await deleteItem(tower: tower, identifier: identifier, baseVersion: version, options: options, request: request)
                ConsoleLogger.shared?.log("Successfully deleted item", osLogType: Self.self)
                completionHandler(nil)
            } catch {
                ConsoleLogger.shared?.log(error, osLogType: Self.self)
                completionHandler(error)
            }
        }
        
        return Progress()
    }
    
    public func modifyItem(tower: Tower,
                           item: NSFileProviderItem,
                           baseVersion version: NSFileProviderItemVersion?,
                           changedFields: NSFileProviderItemFields,
                           contents newContents: URL?,
                           options: NSFileProviderModifyItemOptions? = nil,
                           request: NSFileProviderRequest? = nil,
                           completionHandler: @escaping Completion) -> Progress
    {
        let version = version ?? NSFileProviderItemVersion()

        Task {
            do {
                let (item, fields, needUpload) = try await modifyItem(tower: tower, item: item, baseVersion: version, changedFields: changedFields, contents: newContents, options: options, request: request)
                ConsoleLogger.shared?.log("Successfully modified item", osLogType: Self.self)
                completionHandler(item, fields, needUpload, nil)
            } catch {
                ConsoleLogger.shared?.log(error, osLogType: Self.self)
                completionHandler(nil, [], false, error)
            }
        }
        
        return Progress()
    }
    
    public func createItem(tower: Tower,
                           basedOn itemTemplate: NSFileProviderItem,
                           fields: NSFileProviderItemFields = [],
                           contents url: URL?,
                           options: NSFileProviderCreateItemOptions = [],
                           request: NSFileProviderRequest? = nil,
                           completionHandler: @escaping (NSFileProviderItem?, NSFileProviderItemFields, Bool, Error?) -> Void) -> Progress
    {
        Task {
            do {
                let (item, fields, needUpload) = try await createItem(tower: tower, basedOn: itemTemplate, fields: fields, contents: url, options: options, request: request)
                ConsoleLogger.shared?.log("Successfully created item", osLogType: Self.self)
                completionHandler(item, fields, needUpload, nil)
            } catch {
                ConsoleLogger.shared?.log(error, osLogType: Self.self)
                completionHandler(nil, [], false, error)
            }
        }
        
        return Progress()
    }

}
// swiftlint:enable function_parameter_count
