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

import WebKit

final class ProtonDocumentWebPlatformHandler: NSObject, WKScriptMessageHandler {
    private static let platformIdentifier = "iOS"

    init(userContentController: WKUserContentController) {
        super.init()
        // Adding a platform identifier to allow web to distinguish platform
        // No handling of messages will be performed
        userContentController.add(self, name: Self.platformIdentifier)
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        // No handling is necessary, delegate methods needs to be implemented just to conform to type
    }
}
