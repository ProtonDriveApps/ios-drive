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
import ProtonCore_Networking
import PDCore

enum FinderError: Error, Equatable {
    static func == (lhs: FinderError, rhs: FinderError) -> Bool {
        (lhs as NSError).isEqual(rhs)
    }

    case noSpaceOnCloud
    case noSpaceOnDevice
    case toast(error: Error?)

        init(_ error: Error?) {
            switch error {
            case let (error as ResponseError):
                if let nsError = error.underlyingError {
                    self = Self.checkSpaceError(for: nsError)
                } else {
                    self = Self.toast(error: error)
                }
            case let error as NSError:
                self = Self.checkSpaceError(for: error)
            default:
                self = .toast(error: error)
            }
        }

        private static func checkSpaceError(for error: NSError) -> FinderError {
            if error.code == Uploader.Errors.noSpaceOnCloudError.code {
                return .noSpaceOnCloud
            } else if error.matches(Uploader.Errors.lackOfSpaceOnDiskError) || error.matches(Uploader.Errors.lackOfSpaceOnDeviceError) {
                return .noSpaceOnDevice
            } else {
                return .toast(error: error)
            }
        }

}

private extension NSError {
    func matches(_ error: Uploader.Errors.ErrorElements) -> Bool {
        return domain == error.domain && code == error.code
    }
}
