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

#if DEBUG
import OHHTTPStubs

final class HumanVerification {

    static func setupUITestsMocks() {
        HTTPStubs.setEnabled(true)
        stub(condition: pathEndsWith("/folders") && isMethodPOST()) { request in
            let body = responseString9001.data(using: String.Encoding.utf8)!
            let headers = ["Content-Type": "application/json;charset=utf-8"]
            return HTTPStubsResponse(data: body, statusCode: 200, headers: headers)
        }
    }

    static var responseString9001: String { """
        {
            "Code": 9001,
            "Error": "Human verification required",
            "Details": {
                "Title": "Human verification",
                "HumanVerificationMethods": ["captcha", "sms", "email", "payment", "invite", "coupon"],
                "HumanVerificationToken": "signup"
            },
            "ErrorDescription": "signup"
        }
        """
    }
}

extension AppDelegate {
    func setupUITestsMocks() {
        if ProcessInfo.processInfo.arguments.contains("--human_verification") {
            HumanVerification.setupUITestsMocks()
        }
        
        OnboardingFlowTestsManager.skipOnboardingInTestsIfNeeded()
        OneDollarUpsellFlowTestsManager.skipUpsellInTestsIfNeeded()
    }
}
#endif
