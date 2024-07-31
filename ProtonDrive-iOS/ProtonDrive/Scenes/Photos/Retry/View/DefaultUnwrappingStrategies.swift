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
import UIKit

typealias RetryItemNameUnwrappingStrategy = (String?) -> String
typealias RetryImageUnwrappingStrategy = (Data?) -> Data

struct RetryUnwrappingStrategyFactory {
    
    func makeItemNameUnwrappingStrategy() -> RetryItemNameUnwrappingStrategy {
        var unnamedCount = 0
        return { name in
            if let name {
                return name
            } else {
                unnamedCount += 1
                return "Asset \(unnamedCount)"
            }
        }
    }
    
    func makeImageUnwrappingStrategy() -> RetryImageUnwrappingStrategy {
        { $0 ?? UIImage(systemName: "eye.slash")?.pngData() ?? Data() }
    }
    
}
