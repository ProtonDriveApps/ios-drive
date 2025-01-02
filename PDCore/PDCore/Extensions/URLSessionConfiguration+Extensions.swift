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

import Foundation

extension URLSessionConfiguration {
    
    static var forUploading: URLSessionConfiguration {
        let configuration: URLSessionConfiguration = .ephemeral
        configuration.httpMaximumConnectionsPerHost = 16
        return configuration
    }
    
    /*
     Before the commit with this comment, this var was never actually used in the code.
     
     Where it should have been used, `forUploading` was used instead by mistake.
     
     To avoid any unintended consequences from fixing the callers to use this instead,
     the actual session configuration returned was made identical to what `forUploading` returns.
     
     Any further changes in future to either `forUploading` and `forDownloading` can now
     be independant of each other.
     */
    static var forDownloading: URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        if Constants.downloaderUsesSharedURLSession {
            // With a single shared session, we want this to equal the most concurrent blocks we can support
            configuration.httpMaximumConnectionsPerHost = Constants.maxConcurrentInflightFileDownloads * Constants.maxConcurrentBlockDownloadsPerFile
        } else {
            // Same as it ever was
            configuration.httpMaximumConnectionsPerHost = 16
        }
        return configuration
    }

}
