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
import PDCore
import PDLocalization

struct BurstGalleryViewConstant {
    let coverBadgeTitle = Localization.preview_burst_cover
    let doneButtonTitle = Localization.general_done
    
    func subtitle(num: Int) -> String {
        Localization.preview_burst_gallery_subtitle(num: num)
    }
}

final class BurstGalleryViewModel: ObservableObject {
    let urls: [URL]
    let title: String
    private var cache = [URL: Data]()
    var numOfPhotos: Int { urls.count }
    
    init(coverURL: URL, childrenURLs: [URL]) {
        self.urls = [coverURL] + childrenURLs
        self.title = coverURL.lastPathComponent
    }
    
    func imageData(of index: Int) -> Data {
        let url = urls[index]
        if let imageData = cache[url] {
            return imageData
        } else {
            let data = try? Data(contentsOf: url)
            cache[url] = data
            return data ?? .init()
        }
    }
}
