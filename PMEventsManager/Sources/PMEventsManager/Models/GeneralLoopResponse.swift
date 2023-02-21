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
import ProtonCore_DataModel
import ProtonCore_Payments

public struct GeneralLoopResponse: Codable {
    public let code: Int
    public let eventID: String
    public let refresh: Int
    public let more: Int
    
    public let user: User?                  // from ProtonCore_DataModel
    public let subscription: Subscription? 
    public let userSettings: UserSettings?
    public let organization: Organization?  // from ProtonCore_Payments
    public let usedSpace: Double?
    
    public let addresses: [AddressUpdate]?
    
    /* Currently not used:
    public let pushes: [Push]
    public let notices: [String]
    public let invoices: [InvoiceUpdate]?
    */
    
}

extension GeneralLoopResponse: EventPage {
    
    public var requiresClearCache: Bool {
        refresh == 1
    }
    
    public var hasMorePages: Bool {
        more == 1
    }
    
    public var lastEventID: String {
        eventID
    }
    
}
