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

import PDCore

protocol EditNodeViewModel: AnyObject {
    var onError: ((Error) -> Void)? { get set }
    var onSuccess: (() -> Void)? { get set }
    var onPerformingRequest: (() -> Void)? { get set }
    var onDismiss: (() -> Void)? { get set }
    
    var title: String { get }
    var buttonText: String { get }
    var placeHolder: String { get }
    var fullName: String { get }

    func validate(_ proposal: String) -> [ValidationError<String>]
    func setName(to name: String)
    func close()
}
