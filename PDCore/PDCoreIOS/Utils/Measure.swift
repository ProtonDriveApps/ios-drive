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
import PDCore

public func measure<T>(
    message: String = "",
    file: String = #filePath,
    function: String = #function,
    line: Int = #line,
    domain: LogDomain,
    _ block: () async throws -> T
) async rethrows -> T {
    let start = CFAbsoluteTimeGetCurrent()
    let result = try await block()
    let end = CFAbsoluteTimeGetCurrent()

    var text = "takes \(end - start)s"
    if !message.isEmpty {
        text = "\(message) \(text)"
    }
    Log.info("\(text)", domain: domain, file: file, function: function, line: line)

    return result
}

public func measure<T>(
    message: String = "",
    file: String = #filePath,
    function: String = #function,
    line: Int = #line,
    domain: LogDomain,
    _ block: () throws -> T
) rethrows -> T {
    let start = CFAbsoluteTimeGetCurrent()
    let result = try block()
    let end = CFAbsoluteTimeGetCurrent()

    var text = "takes \(end - start)s"
    if !message.isEmpty {
        text = "\(message) \(text)"
    }
    Log.info("\(text)", domain: domain, file: file, function: function, line: line)

    return result
}
