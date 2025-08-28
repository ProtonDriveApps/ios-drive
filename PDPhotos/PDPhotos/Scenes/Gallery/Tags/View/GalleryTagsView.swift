// Copyright (c) 2025 Proton AG
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

import ProtonCoreUIFoundations
import SwiftUI

struct GalleryTagsView<ViewModel: GalleryTagsViewModelProtocol>: View {
    @ObservedObject var viewModel: ViewModel

    var body: some View {
        TagRowView(
            tags: tags,
            selectedTag: selectedTag
        ) { tags in
            let uiTag = (tags as? [PhotoUITag])?.first
            viewModel.select(tag: uiTag?.tag)
        }
    }

    private var tags: [PhotoUITag] {
        [PhotoUITag.all] + viewModel.tags.map(PhotoUITag.existing)
    }

    private var selectedTag: PhotoUITag? {
        if let selectedTag = viewModel.selectedTag {
            return tags.first(where: { $0.tag == selectedTag })
        } else {
            return nil
        }
    }
}
