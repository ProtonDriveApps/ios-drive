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

public extension NumberFormatter {
    static var priceFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter
    }()
    
    static var decimalWithNoFracionDigitsFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter
    }()
    
    static func formatPrice(amount: Decimal, currencyCode: String) -> String? {
        let formatter = priceFormatter
        formatter.currencyCode = currencyCode
        return formatter.string(from: NSDecimalNumber(decimal: amount))
    }
    
    static func formatDecimalWithNoFractionDigits(number: Int) -> String? {
        return decimalWithNoFracionDigitsFormatter.string(from: NSNumber(value: number))
    }
}
