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
import CoreData
import PDCore
import UIKit

struct CancelationError: Error { }

final class CoreDataFilePreviewRepository: FilePreviewRepository {
    private let context: NSManagedObjectContext
    private let file: File

    private var cleartextUrl: URL?
    private var isCancelled = false

    init(context: NSManagedObjectContext, file: File) {
        self.context = context
        self.file = file
        NotificationCenter.default.addObserver(
                    self,
                    selector: #selector(cleanup),
                    name: UIApplication.willTerminateNotification,
                    object: nil
                )
    }
    
    func getURL() -> URL {
        if let cleartextUrl = cleartextUrl, FileManager.default.fileExists(atPath: cleartextUrl.path) {
            return cleartextUrl
        } else {
            Log.error(DriveError("The file was not found."), domain: .fileManager)
            return URL.blank
        }
    }

    func loadFile() async throws {
        Log.info("Will start decrypting the file", domain: .fileManager)
        return try await context.perform {
            do {
                let file = self.file.in(moc: self.context)
                guard self.cleartextUrl == nil, let revision = file.activeRevision else {
                    throw file.invalidState("No active revision in file")
                }

                let cleartextUrl = try revision.clearURL()
                self.cleartextUrl = cleartextUrl
                _ = try revision.decryptFileToURL(cleartextUrl, isCancelled: &self.isCancelled)
                if self.isCancelled {
                    self.cleanup()
                    self.cleartextUrl = nil
                    throw CancelationError()
                }
            } catch {
                self.cleanup()
                self.cleartextUrl = nil
                throw error
            }
        }
    }

    deinit {
        cancel()
        cleanup()
    }
}

extension CoreDataFilePreviewRepository {
    func cancel() {
        self.isCancelled = true
    }

    @objc private func cleanup() {
        if let url = self.cleartextUrl {
            try? FileManager.default.removeItemIncludingUniqueDirectory(at: url)
            self.cleartextUrl = nil
        }
    }
}
