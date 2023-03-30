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

import CoreData

extension NSManagedObject {
    public func `in`(moc: NSManagedObjectContext) -> Self {
        return moc.object(with: self.objectID) as! Self
    }
}

extension NSManagedObjectContext {
    public func existingObject<O: NSManagedObject>(with url: URL) -> O? {
        guard let objectId = persistentStoreCoordinator?.managedObjectID(forURIRepresentation: url) else {
            return nil
        }
        return object(with: objectId) as? O
    }
}

extension NSManagedObject {
    public var moc: NSManagedObjectContext? {
        managedObjectContext
    }

    struct NoMOCError: Error, LocalizedError {
        let file: String
        let line: Int

        internal init(file: String, line: Int) {
            self.file = (file as NSString).lastPathComponent
            self.line = line
        }

        var errorDescription: String? {
            "Could not find NSManagedObjectContext in file: \(file), line: \(line)"
        }
    }

    struct InvalidState: Error {
        let line: Int
        let file: String
        let message: String

        internal init(message: String, file: String = #filePath, line: Int = #line) {
            self.message = message
            self.file = (file as NSString).lastPathComponent
            self.line = line
        }
    }

    static func noMOC(file: String = #filePath, line: Int = #line) -> NoMOCError {
        NoMOCError(file: file, line: line)
    }

    func invalidState(_ message: String, file: String = #filePath, line: Int = #line) -> InvalidState {
        let message = "Invalid \(type(of: self)).\n" + message
        return InvalidState(message: message, file: file, line: line)
    }
}
