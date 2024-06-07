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

public protocol AssertionProvider {
    func assertionFailure(_ message: @autoclosure @escaping () -> String, file: StaticString, line: UInt)
}

public extension AssertionProvider {
    func assertionFailure(_ message: @autoclosure @escaping () -> String, fileName: StaticString = #file, lineNumber: UInt = #line) {
        self.assertionFailure(message(), file: fileName, line: lineNumber)
    }
}

public enum SystemAssertionProvider: AssertionProvider {
    case instance
    
    public func assertionFailure(_ message: @autoclosure @escaping () -> String, file: StaticString = #file, line: UInt = #line) {
        Swift.assertionFailure(message(), file: file, line: line)
    }
}
