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

import PDLocalization
import PDUIComponents
import ProtonCoreUIFoundations
import SwiftUI

struct BurstGalleryView: View {
    @EnvironmentObject var hostingProvider: ViewControllerProvider
    @State private var sharedURL: URL?
    private let accessibilityIdentifier = "BurstGalleryView"
    private let constants = BurstGalleryViewConstant()
    private let itemAspectRatio: CGFloat = 1 / 1.4
    private let minimumNumberOfColumns: CGFloat = 3
    private let preferableItemWidth: CGFloat = 128
    private let spacing: CGFloat = 1.5
    private let viewModel: BurstGalleryViewModel
    
    init(viewModel: BurstGalleryViewModel) {
        self.viewModel = viewModel
    }
    
    var body: some View {
        GeometryReader { geometry in
            gallery(geometry: geometry)
                .sheet(item: $sharedURL) { url in
                    ShareSheet(
                        activityItems: [url],
                        applicationActivities: [SaveBurstPhotoActivity(urls: [url], saveWholeBurst: false)],
                        excludedActivityTypes: [.saveToCameraRoll]
                    )
                }
        }
        .toolbar {
            ToolbarItem(placement: .principal) { navigationTitleView }
            ToolbarItem(placement: .topBarLeading) { dismissButton }
            ToolbarItem(placement: .topBarTrailing) { doneButton }
        }
    }
}

// MARK: - Navigation bar
extension BurstGalleryView {
    private var navigationTitleView: some View {
        VStack {
            Text(viewModel.title)
                .font(.system(size: 17).bold())
                .foregroundStyle(ColorProvider.TextNorm)
                .accessibilityIdentifier("\(accessibilityIdentifier).title")
            Text(constants.subtitle(num: viewModel.numOfPhotos))
                .modifier(TextModifier(alignment: .center, fontSize: 13, textColor: ColorProvider.TextWeak))
                .accessibilityIdentifier("\(accessibilityIdentifier).subtitle")
        }
    }
    
    private var dismissButton: some View {
        Button {
            hostingProvider.viewController?.navigationController?.dismiss(animated: true)
        } label: {
            Image(uiImage: IconProvider.cross)
                .tint(ColorProvider.IconNorm)
        }
    }
    
    private var doneButton: some View {
        // TODO:DRVIOS-3042, enable this when implementing multiple selection
        Button {
        } label: {
            Text(constants.doneButtonTitle)
//                .modifier(TextModifier(fontSize: 17, textColor: ColorProvider.BrandNorm))
                .modifier(TextModifier(fontSize: 17, textColor: .clear))
        }
        .disabled(true)
    }
}

extension BurstGalleryView {
    @ViewBuilder
    private func gallery(geometry: GeometryProxy) -> some View {
        ScrollView {
            LazyVGrid(
                columns: columns(width: geometry.size.width),
                alignment: .leading,
                spacing: spacing
            ) {
                ForEach(viewModel.urls.indices, id: \.self) { index in
                    let image = UIImage(data: viewModel.imageData(of: index)) ?? .init()
                    let url = viewModel.urls[index]
                    if #available(iOS 16.0, *) {
                        gridCell(image: image, isCover: index == 0)
                            .aspectRatio(itemAspectRatio, contentMode: .fit)
                            .contextMenu(
                                menuItems: {
                                    contextMenuItems(image: image, url: url)
                                }, preview: {
                                    // preview only available on iOS 16 and later
                                    // remove else block after dropping iOS 15
                                    Image(uiImage: image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: geometry.size.width - 100)
                                        .frame(maxHeight: geometry.size.height - 200)
                                }
                            )
                    } else {
                        gridCell(image: image, isCover: index == 0)
                            .aspectRatio(itemAspectRatio, contentMode: .fit)
                            .contextMenu {
                                contextMenuItems(image: image, url: url)
                            }
                    }
                }
            }
        }
    }
    
    private func columns(width: CGFloat) -> [GridItem] {
        let widthForExtraColumns = preferableItemWidth * (minimumNumberOfColumns + 1) + spacing * (minimumNumberOfColumns - 1)
        if width >= widthForExtraColumns {
            return [GridItem(.adaptive(minimum: preferableItemWidth, maximum: .infinity))]
        } else {
            return Array(repeating: .init(.flexible(), spacing: spacing), count: 3)
        }
    }
    
    @ViewBuilder
    private func gridCell(image: UIImage, isCover: Bool) -> some View {
        GeometryReader { geometry in
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
                .overlay(alignment: .bottomTrailing) {
                    if isCover {
                        IconBadgeView(
                            text: constants.coverBadgeTitle,
                            icon: IconProvider.star,
                            accessibilityIDPrefix: "burst.gallery"
                        )
                            .padding(.trailing, 6)
                            .padding(.bottom, 6)
                    }
                }
        }
    }
    
    @ViewBuilder
    private func contextMenuItems(image: UIImage, url: URL) -> some View {
        Button {
            UIPasteboard.general.image = image
        } label: {
            Label(title: { Text(Localization.general_copy) }, icon: { Image(uiImage: IconProvider.squares) })
        }
        
        Button {
            sharedURL = url
        } label: {
            Label(
                title: { Text(Localization.share_action_share) },
                icon: { Image(uiImage: IconProvider.arrowUpFromSquare) }
            )
        }
        
        // TODO:DRVIOS-3042, uncomment when implement multiple selection 
//        Button {
//            
//        } label: {
//            Label(
//                title: { Text(Localization.general_select) },
//                icon: { Image(uiImage: IconProvider.checkmark) }
//            )
//        }
    }
}
