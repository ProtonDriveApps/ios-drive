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

import SwiftUI
import PDUIComponents
import PDCore

struct VerticalAlbumList: View {
    private let albumList: [AlbumListing]
    private var cellViewModel: ((AlbumListing) -> AlbumGridItemViewModel)?
    private var groupToAlbum: ((AnyVolumeIdentifier) -> Void)?

    init(
        albumList: [AlbumListing],
        cellViewModel: ((AlbumListing) -> AlbumGridItemViewModel)?,
        groupToAlbum: ((AnyVolumeIdentifier) -> Void)?
    ) {
        self.albumList = albumList
        self.cellViewModel = cellViewModel
        self.groupToAlbum = groupToAlbum
    }

    var body: some View {
        LazyVGrid(
            columns: [.init(.flexible())],
            content: albumListView
        )
    }

    @ViewBuilder
    func albumListView() -> some View {
        ForEach(albumList, id: \.albumIdentifier) { album in
            cell(for: album)
                .frame(height: 64)
                .contentShape(Rectangle()) // To enable tap gesture
                .onTapGesture {
                    groupToAlbum?(album.albumIdentifier)
                }
        }
    }

    @ViewBuilder
    private func cell(for album: AlbumListing) -> some View {
        if let vm = cellViewModel?(album) {
            GroupToAlbumActionSheetCell(viewModel: vm)
        } else {
            EmptyView()
        }
    }
}
