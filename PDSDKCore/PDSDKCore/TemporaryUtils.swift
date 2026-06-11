// Copyright (c) 2025 Proton AG
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

/// TODO(SDK): Used for testing purposes only - remove using the SDK is implemented

func listFiles(at path: String) {
    let fileManager = FileManager.default
    do {
        let items = try fileManager.contentsOfDirectory(atPath: path)
        for item in items {
            print("📄 \(item)")
        }
    } catch {
        print("❌ Error listing files at \(path): \(error)")
    }
}

func listDocumentsDirectory() {
    if let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
        print("📁 Documents path: \(docsURL.path)")
        listFiles(at: docsURL.path)
    }
}

public func createTempFile(withSize sizeInBytes: Int) throws -> URL {
    // Get the temporary directory
    let tempDirectory = FileManager.default.temporaryDirectory

    // Format the current date and time
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
    let timestamp = formatter.string(from: Date())

    // Create a filename with the timestamp
    let filename = "upload_via_sdk_tempfile_\(timestamp).bin"
    let fileURL = tempDirectory.appendingPathComponent(filename)

    // Create dummy data of the requested size
    // (this uses zeroed bytes; you could use random bytes if preferred)
    let data = Data(count: sizeInBytes)

    // Write to the file
    try data.write(to: fileURL)

    return fileURL
}
