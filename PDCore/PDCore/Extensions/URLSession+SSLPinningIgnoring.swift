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
import PDLoadTesting

extension URLSession {
    
    static func forUploading(delegate: URLSessionDelegate? = nil) -> URLSession {
        let session: URLSession
        if let delegate {
            session = URLSession(configuration: .forUploading, delegate: delegate, delegateQueue: nil)
        } else {
            if LoadTesting.isEnabled {
                // according to URLSession docs, the delegate is retained
                let testDelegate = TestDelegate()
                session = URLSession(configuration: .forUploading, delegate: delegate ?? testDelegate, delegateQueue: nil)
            } else {
                session = URLSession(configuration: .forUploading)
            }
        }
        
        session.sessionDescription = "Uploader"
        return session
    }
    
    static func forDownloading() -> URLSession {
        sharedDownloadSession ?? createDownloadingSession(description: "Downloader(Per File)")
    }
    
    private static func createDownloadingSession(description: String) -> URLSession {
        let session: URLSession
        if LoadTesting.isEnabled {
            // according to URLSession docs, the delegate is retained
            let testDelegate = TestDelegate()
            session = URLSession(configuration: .forDownloading, delegate: testDelegate, delegateQueue: nil)
        } else {
            session = URLSession(configuration: .forDownloading)
        }

        session.sessionDescription = description
        return session
    }
    
    private static let sharedDownloadSession: URLSession? = Constants.downloaderUsesSharedURLSession ? createDownloadingSession(description: "Downloader(Shared)") : nil
}
