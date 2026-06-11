// Copyright (c) 2026 Proton AG
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
import UniformTypeIdentifiers
import PDCore

struct NSItemProviderTextUsecase: NSItemProviderLoadUsecase {
    typealias URLErrorCompletion = ((URL?, Error?)) -> Void
    private let copyURLFactory: (String) -> URL
    private let fileUsecase: NSItemProviderFileUsecase

    init(fileUsecase: NSItemProviderFileUsecase, copyURLFactory: @escaping (String) -> URL) {
        self.fileUsecase = fileUsecase
        self.copyURLFactory = copyURLFactory
    }

    func load(_ itemProvider: NSItemProvider, typeIdentifier: String, completion: @escaping URLErrorCompletion) {
        Log.info("Loading item provider with Text type", domain: .itemProviderLoader)
        itemProvider.loadDataRepresentation(forTypeIdentifier: typeIdentifier) { data, error in
            guard let data else {
                Log.error("Failed to load text data", error: error, domain: .itemProviderLoader)
                completion((nil, error))
                return
            }

            let filename = self.filename(
                suggestedName: itemProvider.suggestedName,
                typeIdentifier: typeIdentifier
            )
            let copyURL = copyURLFactory(filename)

            do {
                let parsedData = parse(data)
                try parsedData.write(to: copyURL, options: .atomic)
                completion((copyURL, nil))
            } catch {
                completion((nil, error))
            }
        }
    }

    private func filename(suggestedName: String?, typeIdentifier: String) -> String {
        let baseName: String
        if let suggestedName, !suggestedName.isEmpty {
            baseName = suggestedName
        } else {
            baseName = defaultFilename(suffix: "text")
        }
        return appendFileExtensionIfNeeded(filename: baseName, typeIdentifier: typeIdentifier, defaultExtension: "txt")
    }

    private func parse(_ data: Data) -> Data {
        if let value = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSString.self, from: data) {
            return Data((value as String).utf8)
        } else {
            return data
        }
    }
}
