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

import SwiftUI
import PDCore
import ProtonCoreUIFoundations
import PDUIComponents
import PDLocalization

struct EmptyFolderView<Header: View, Footer: View>: View {
    let viewModel: EmptyViewConfiguration
    let header: () -> Header
    let footer: () -> Footer
    
    var body: some View {
        VStack(alignment: .center, spacing: 32) {
            header()

            Image(imageName)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: maxImageHeight)
                .padding(.horizontal, 24)

            VStack(spacing: 16) {
                Text(viewModel.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(ColorProvider.TextNorm)

                Text(viewModel.message)
                    .font(.title3)
                    .fontWeight(.regular)
                    .foregroundColor(ColorProvider.TextWeak)
            }
            .fixedSize(horizontal: false, vertical: true)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)

            footer()
        }
    }
    
    private var imageName: String {
        switch viewModel.image {
        case .emptySharedWithMe:
            return "empty-shared-with-me"
        case .emptySharedByMe:
            return "empty-shared-by-me"
        case .emptyShared:
            return "empty-shared"
        case .emptyFolder:
            return "empty-folder"
        case .offlineFiles:
            return "offline-files"
        case .emptyTrash:
            return "empty-trash"
        case .genericError:
            return "error-generic"
        case .cloudError:
            return "cloud-error"
        }
    }
    
    // Throw away specific sizes when we have new standardized illustrations.
    private var maxImageHeight: CGFloat {
        switch viewModel.image {
        case .offlineFiles:
            return 170
        case .genericError:
            return 114
        case .cloudError:
            return 132
        case .emptyFolder, .emptyTrash:
            return 150
        default:
            return 120
        }
    }
}

extension EmptyFolderView where Footer == Spacer, Header == Spacer {
    init(viewModel: EmptyViewConfiguration) {
        self.init(viewModel: viewModel, header: { Spacer.init() }, footer: { Spacer.init() })
    }
}

extension EmptyFolderView where Footer == Spacer {
    init(viewModel: EmptyViewConfiguration, header: @escaping () -> Header) {
        self.init(viewModel: viewModel, header: header, footer: { Spacer.init() })
    }
}

extension EmptyFolderView where Header == Spacer {
    init(viewModel: EmptyViewConfiguration, footer: @escaping () -> Footer) {
        self.init(viewModel: viewModel, header: { Spacer.init() }, footer: footer)
    }
}

struct EmptyViewConfiguration {
    enum ImageType {
        case emptyShared
        case emptyFolder
        case offlineFiles
        case emptyTrash
        case genericError
        case cloudError
        case emptySharedByMe
        case emptySharedWithMe
    }
    
    let image: ImageType
    let title: String
    let message: String
}

extension EmptyViewConfiguration {
    static let folder = EmptyViewConfiguration(
        image: .emptyFolder,
        title: Localization.empty_folder_title,
        message: Localization.empty_folder_message
    )

    static let folderWithoutMessage = EmptyViewConfiguration(
        image: .emptyFolder,
        title: Localization.empty_folder_title,
        message: ""
    )

    static let trash = EmptyViewConfiguration(
        image: .emptyTrash,
        title: Localization.trash_empty_title,
        message: Localization.trash_empty_message
    )

    static let shared = EmptyViewConfiguration(
        image: .emptySharedByMe,
        title: Localization.share_empty_title,
        message: Localization.share_empty_message
    )

    static let sharedByMe = EmptyViewConfiguration(
        image: .emptySharedByMe,
        title: Localization.shared_by_me_empty_title,
        message: Localization.shared_by_me_empty_message
    )

    static let sharedWithMe = EmptyViewConfiguration(
        image: .emptySharedWithMe,
        title: Localization.shared_with_me_empty_title,
        message: Localization.shared_with_me_empty_message
    )

    static let offlineAvailable = EmptyViewConfiguration(
        image: .offlineFiles,
        title: Localization.available_offline_empty_title,
        message: Localization.available_offline_empty_message
    )

    static let noConnection = EmptyViewConfiguration(
        image: .genericError,
        title: Localization.disconnection_view_title,
        message: Localization.disconnection_folder_message
    )

    static let noConnectionInPhoto = EmptyViewConfiguration(
        image: .genericError,
        title: Localization.disconnection_view_title,
        message: ""
    )
}
