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

import PDCore
import WebKit

final class ProtonDocumentWebLoggingHandler: NSObject, WKScriptMessageHandler {
    private enum WebLoggingLevel: String, CaseIterable {
        case debug
        case info
        case warning
        case error

        func getLogLevel() -> LogLevel {
            switch self {
            case .debug:
                return .debug
            case .info:
                return .info
            case .warning:
                return .warning
            case .error:
                return .error
            }
        }
    }

    private static let logScriptName = "driveConsoleLog"

    init(userContentController: WKUserContentController) {
        super.init()
        let script = makeScript()
        userContentController.addUserScript(script)
        userContentController.add(self, name: Self.logScriptName)
    }

    private func makeScript() -> WKUserScript {
        // JS Script that overrides console's outputs, tries to stringify the arguments
        // and send it to original handlers plus our handler.
        // Prefixing the log with a `WebLoggingLevel` value helps us distinguish the level of log
        // All messages are trimmed to 3000 symbols.
        let script = """
            function log(type, args) {
                window.webkit.messageHandlers.\(Self.logScriptName).postMessage(
                    `${type}${Object.values(args)
                        .map(v => typeof(v) === "undefined" ? "undefined" : typeof(v) === "object" ? JSON.stringify(v) : v.toString())
                        .map(v => v.substring(0, 3000))
                        .join(", ")}`
                )
            }

            let originalLog = console.log
            let originalWarn = console.warn
            let originalError = console.error
            let originalDebug = console.debug

            console.log = function() {
                log("\(WebLoggingLevel.info.rawValue)", arguments);
                originalLog.apply(null, arguments);
            }
            console.warn = function() {
                log("\(WebLoggingLevel.warning.rawValue)", arguments);
                originalWarn.apply(null, arguments);
            }
            console.error = function() {
                log("\(WebLoggingLevel.error.rawValue)", arguments);
                originalError.apply(null, arguments)
            }
            console.debug = function() {
                log("\(WebLoggingLevel.debug.rawValue)", arguments);
                originalDebug.apply(null, arguments);
            }
            window.addEventListener("error", function(e) {
               log("\(WebLoggingLevel.error.rawValue)", [`${e.message} at ${e.filename}:${e.lineno}:${e.colno}`])
            })
        """
        return WKUserScript(source: script, injectionTime: .atDocumentStart, forMainFrameOnly: false)
    }

    // MARK: - WKScriptMessageHandler

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == Self.logScriptName else {
            return
        }
        guard var body = message.body as? String else {
            return
        }
        guard let level = parseLevel(from: body) else {
            return
        }
        body = body.deletingPrefix(level.rawValue)

        switch level {
        case .debug:
            Log.debug(body, domain: .protonDocs)
        case .info:
            Log.info(body, domain: .protonDocs)
        case .warning:
            Log.warning(body, domain: .protonDocs)
        case .error:
            Log.error(body, domain: .protonDocs)
        }
    }

    private func parseLevel(from message: String) -> WebLoggingLevel? {
        return WebLoggingLevel.allCases.first { mapping in
            message.hasPrefix(mapping.rawValue)
        }
    }
}
