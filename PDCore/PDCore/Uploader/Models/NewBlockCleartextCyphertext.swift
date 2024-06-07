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

/// Temporary holder for block cleartext values
struct NewBlockUrlCleartext: NewBlockCleartext {
    var index: Int
    var cleardata: URL
    var size: Int? { cleardata.fileSize }
}

/// Temporary holder for block cyphertext values
struct NewBlockUrlCyphertext: NewBlockCyphertext {
    var index: Int
    var cypherdata: URL
    var hash: Data
    var size: Int
}

/// Temporary holder for block cleartext values
struct NewBlockDataCleartext: NewBlockCleartext {
    var index: Int
    var cleardata: Data
    var size: Int { cleardata.count }
}

/// Temporary holder for block cyphertext values
struct NewBlockDataCyphertext: NewBlockCyphertext {
    var index: Int
    var cypherdata: Data
    var hash: Data
    var size: Int { cypherdata.count }
}

/// Abstraction for temporary holder for block cleartext values
protocol NewBlockCleartext {
    associatedtype DataType
    var index: Int { get }
    var cleardata: DataType { get }
}

/// Abstraction for temporary holder for block cyphertext values
protocol NewBlockCyphertext {
    associatedtype DataType
    var index: Int { get }
    var cypherdata: DataType { get }
    var hash: Data { get }
    var size: Int { get }
}
