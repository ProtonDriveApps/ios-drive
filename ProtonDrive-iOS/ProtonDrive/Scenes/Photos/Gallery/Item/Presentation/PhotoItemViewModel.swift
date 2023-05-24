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

import Combine
import Foundation

protocol PhotoItemViewModelProtocol: ObservableObject {
    var duration: String? { get }
    var image: Data? { get }
    func openPreview()
}

struct PhotoItemViewModelData {
    let image: Data?
    let duration: String?
}

final class PhotoItemViewModel: PhotoItemViewModelProtocol {
    private let item: PhotoGridViewItem

    let duration: String?
    var image: Data?

    init(item: PhotoGridViewItem) {
        self.item = item
        duration = item.duration
    }

    func openPreview() {
        // TODO: next MR
    }
}
