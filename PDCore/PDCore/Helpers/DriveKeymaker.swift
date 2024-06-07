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

import ProtonCoreKeymaker

public final class DriveKeymaker: Keymaker {
    override public func setupCryptoTransformers(key: MainKey?) {
        super.setupCryptoTransformers(key: key)
        guard let key = key else {
            ValueTransformer.setValueTransformer(nil, forName: .init(rawValue: "DriveStringCryptoTransformer"))
            return
        }
        ValueTransformer.setValueTransformer(DriveStringCryptoTransformer(key: key), forName: .init(rawValue: "DriveStringCryptoTransformer"))
    }
}
