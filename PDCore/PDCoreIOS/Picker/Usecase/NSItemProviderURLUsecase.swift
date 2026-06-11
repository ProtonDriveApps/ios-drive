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

struct NSItemProviderURLUsecase: NSItemProviderLoadUsecase {
    typealias URLErrorCompletion = ((URL?, Error?)) -> Void
    private let copyURLFactory: (String) -> URL

    init(copyURLFactory: @escaping (String) -> URL) {
        self.copyURLFactory = copyURLFactory
    }

    func load(_ itemProvider: NSItemProvider, completion: @escaping URLErrorCompletion) {
        if itemProvider.canLoadObject(ofClass: URL.self) {
            Log.info("Loading item provider with URL type", domain: .itemProviderLoader)
            _ = itemProvider.loadObject(ofClass: URL.self) { reading, error in
                if let url = reading {
                    handleSharedURL(url, completion: completion)
                } else {
                    completion((nil, error))
                }
            }
            return
        }

        itemProvider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { item, error in
            if let url = item as? URL {
                handleSharedURL(url, completion: completion)
            } else {
                completion((nil, error))
            }
        }
    }

    private func handleSharedURL(_ url: URL, completion: @escaping URLErrorCompletion) {
        if url.isFileURL {
            copyFileURLToLocalStorage(url: url, completion: completion)
        } else {
            downloadRemoteURL(url, completion: completion)
        }
    }

    private func copyFileURLToLocalStorage(url: URL, completion: @escaping URLErrorCompletion) {
        let needsSecurityScope = url.startAccessingSecurityScopedResource()
        defer {
            if needsSecurityScope {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            Log.info("Copy url file to temporary directory", domain: .itemProviderLoader)
            let copyURL = copyURLFactory(url.lastPathComponent)
            try FileManager.default.copyItem(at: url, to: copyURL)
            completion((copyURL, nil))
        } catch {
            completion((nil, error))
        }
    }

    private func downloadRemoteURL(_ url: URL, completion: @escaping URLErrorCompletion) {
        Log.info("Download file from remote url", domain: .itemProviderLoader)
        let task = URLSession.shared.downloadTask(with: url) { tempURL, response, error in
            guard let tempURL else {
                completion((nil, error))
                return
            }
            if isHTML(urlResponse: response as? HTTPURLResponse), Constants.runningInExtension {
                let data = Data(url.absoluteString.utf8)
                let name = "\(defaultFilename(suffix: "url")).txt"
                let fileURL = self.copyURLFactory(name)
                try? data.write(to: fileURL)
                completion((nil, NSItemProviderLoadResource.Errors.unsupportedHTML(fileURL)))
                return
            }

            let filename = filename(url: url, urlResponse: response as? HTTPURLResponse)

            let copyURL = self.copyURLFactory(filename)
            do {
                try FileManager.default.moveItem(at: tempURL, to: copyURL)
                completion((copyURL, nil))
            } catch {
                completion((nil, error))
            }
        }
        task.resume()
    }

    private func filename(url: URL, urlResponse: HTTPURLResponse?) -> String {
        guard let urlResponse, let contentType = urlResponse.headers["Content-Type"] else {
            return url.lastPathComponent.isEmpty ? defaultFilename(suffix: "url") : url.lastPathComponent
        }

        let path: String? = url.lastPathComponent.isEmpty ? nil : url.lastPathComponent
        let filename = path ?? url.host() ?? defaultFilename(suffix: "url")

        let type = contentType.split(separator: ";").first.map(String.init) ?? ""
        return appendFileExtensionIfNeeded(filename: filename, utType: UTType(mimeType: type), defaultExtension: nil)
    }

    private func isHTML(urlResponse: HTTPURLResponse?) -> Bool {
        guard let urlResponse, let contentType = urlResponse.headers["Content-Type"] else {
            return false
        }
        
        return contentType.contains("text/html")
    }
}
