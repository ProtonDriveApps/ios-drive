//
//  SettingsCommands.swift
//  ProtonCore-QuarkCommands - Created on 08.12.2023.
//
// Copyright (c) 2023. Proton Technologies AG
//
// This file is part of Proton Mail.
//
// Proton Mail is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Proton Mail is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Proton Mail. If not, see https://www.gnu.org/licenses/.

import Foundation

private let drivePopulate: String = "quark/raw::drive:populate"
private let driveUsedSpace: String = "quark/raw::drive:quota:set-used-space"

public extension Quark {

    @discardableResult
    func drivePopulateUser(user: User, scenario: Int, hasPhotos: Bool, withDevice: Bool = false) throws -> (data: Data, response: URLResponse) {

        let args = [
            "-u=\(user.name)",
            "-p=\(user.password)",
            "-S=\(scenario)",
            hasPhotos ? "--photo=\(hasPhotos)" : nil,
            withDevice ? "--device=\(withDevice)" : nil,
        ].compactMap { $0 }

        var request = try route(drivePopulate)
            .args(args)
            .build()
        request.timeoutInterval = 120

        return try executeQuarkRequest(request)
    }

    @available(*, renamed: "Quark.setUsedSpace", message: "Please use general setting command")
    @discardableResult
    func driveSetUsedSpace(uid: Int, space: String) throws -> (data: Data, response: URLResponse) {

        let args = [
            "--uid=\(uid)",
            "--used-space=\(space)"
        ]

        let request = try route(driveUsedSpace)
            .args(args)
            .build()

        return try executeQuarkRequest(request)
    }

}
