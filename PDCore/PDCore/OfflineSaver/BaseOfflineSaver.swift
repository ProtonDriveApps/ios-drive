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

#if os(iOS)

import Foundation

public class BaseOfflineSaver: NSObject {
    let configuration: OfflineSaverConfiguration

    init(configuration: OfflineSaverConfiguration) {
        self.configuration = configuration
        super.init()
    }

    func filterFiles(files: [File]) -> [File] {
        switch configuration {
        case .bothMyFilesAndPhotos:
            return files
        case .onlyMyFiles:
            return files.filter { !($0 is CoreDataPhoto) }
        case .onlyPhotos:
            return files.filter { $0 is CoreDataPhoto }
        }
    }

    func filterFolders(folders: [Folder]) -> [Folder] {
        switch configuration {
        case .bothMyFilesAndPhotos:
            return folders
        case .onlyMyFiles:
            return folders
        case .onlyPhotos:
            return [] // Photos root cannot be marked offline available
        }
    }
}

#endif
