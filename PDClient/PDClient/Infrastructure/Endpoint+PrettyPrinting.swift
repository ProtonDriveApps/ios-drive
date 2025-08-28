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
import ProtonCoreNetworking

// MARK: - Request
extension Endpoint {
    internal var prettyDescription: String {
        #if DEBUG
        """
        \(requestHeader)
        \(line)
        \(prettyURL)
        \(prettyBody)
        \(footer)
        """
        #else
        """
        \(requestHeader)
        \(prettyURL)
        """
        #endif
    }

    private var prettyURL: String {
        return request.url?.printableDescription ?? "|Error❗️: No URL found in request."
    }

    private var prettyBody: String {
        return "|-BODY:\n" + prettifyJSON(request.httpBody)
    }
}

// MARK: - Response
extension Endpoint {
    internal func prettyResponse(_ response: Data) -> String {
        #if DEBUG
        """
        \(responseHeader)
        \(line)
        \(printableUrl)
        "|-RESPONSE:\n" + \(prettifyJSON(response))"
        \(footer)
        """
        #else
        """
        \(responseHeader)
        \(printableUrl)
        """
        #endif
    }

    internal func networkingError(_ error: Error) -> String {
        var messages = [
            responseHeader,
            line,
            printableUrl,
            "|Networking Error ❌: \(error.localizedDescription)"
        ]
        if let responseError = error as? ResponseError {
            if let underlyingError = responseError.underlyingError {
                messages.append("|-UNDERLYING ERROR:")
                messages.append(contentsOf: readMessage(from: underlyingError))
            }
        } else {
            let nsError = error as NSError
            let underlyingErrors = nsError.underlyingErrors.map { $0 as NSError }
            if !underlyingErrors.isEmpty {
                messages.append("|-UNDERLYING ERROR:")
                for underlyingError in underlyingErrors {
                    messages.append(contentsOf: readMessage(from: underlyingError))
                }
            }
        }

        messages.append(footer)
        return messages.joined(separator: "\n")
    }

    private func readMessage(from underlyingError: NSError) -> [String] {
        var messages = [underlyingError.localizedDescription]
        for error in underlyingError.underlyingErrors {
            let nsError = error as NSError
            messages.append(contentsOf: readMessage(from: nsError))
        }
        return messages
    }

    internal func unknownError() -> String {
        """
        \(responseHeader)
        \(line)
        \(printableUrl)
        "|Unknown Error ❌: ResponseData is empty with nil error."
        \(footer)
        """
    }

    internal func serverError(_ error: Error) -> String {
        """
        \(responseHeader)
        \(line)
        \(printableUrl)
        "|Server Error ❌: \(error.localizedDescription)\n"
        \(footer)
        """
    }

    internal func deserializingError(_ error: Error) -> String {
        """
        \(responseHeader)
        \(line)
        \(printableUrl)
        "|Deserializing Error ❌: \(error.localizedDescription)"
        \(footer)
        """
    }

    private var printableUrl: String {
        guard let url = request.url else { return "|Error❗️: No URL found." }
        return "|URL: " + url.absoluteString
    }
}

// MARK: - Common
extension Endpoint {
    private var requestHeader: String { "REQUEST: 🌐🌐🌐🌐 \(method.rawValue) - \(Self.Type.self))" }
    private var responseHeader: String { "RESPONSE: 📩📩📩📩 \(method.rawValue) - \(Self.Type.self)" }
    private var line: String { "++++++++++++++++++++++++++++++++"}
    private var footer: String { "--------------------------------" }

    private func prettifyJSON(_ data: Data?) -> String {
        guard let data = data else {
            return "|Could not peek at JSON❕"
        }

        do {
            let json = try JSONSerialization.jsonObject(with: data, options: .mutableContainers)
            let jsonData = try JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
            return String(decoding: jsonData, as: UTF8.self)
        } catch {
            return "|Error❗️: \(error.localizedDescription)"
        }
    }
 }

// MARK: - Printable URL
extension URL {

    /// Formats in a readable way the **host**, **path** and possible **queries** of the URL.
    public var printableDescription: String {
        printableHost + printablePath + printableQueries
    }

    private var printableHost: String { "|- HOST: " + (host ?? "-") + "\n" }
    private var printablePath: String { "|- PATH: " + path + "\n" }
    private var printableQueries: String {
        guard let query = query else { return "" }
        return "|- QUERIES: \(query)"
    }
}
