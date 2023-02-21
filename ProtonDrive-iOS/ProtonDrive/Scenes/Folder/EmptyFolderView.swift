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
import ProtonCore_UIFoundations
import PDUIComponents

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
        }
    }
    
    // Throw away specific sizes when we have new standardized illustrations.
    private var maxImageHeight: CGFloat {
        switch viewModel.image {
        case .emptyShared:
            return 120
        case .emptyFolder:
            return 88
        case .offlineFiles:
            return 170
        case .emptyTrash:
            return 118
        case .genericError:
            return 114
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
    }
    
    let image: ImageType
    let title: String
    let message: String
}

extension EmptyViewConfiguration {
    static let shared = EmptyViewConfiguration(image: .emptyShared,
                                                title: "Share files with links",
                                                message: "Create links and share files with others")

    static let folder = EmptyViewConfiguration(image: .emptyFolder,
                                                  title: "Nothing to see here",
                                                  message: "This folder is empty")

    static let offlineAvailable = EmptyViewConfiguration(image: .offlineFiles,
                                                         title: "No offline files or folders",
                                                         message: "Tap “Make available offline” in a file’s or folder’s menu to access it without internet connection.")

    static let trash = EmptyViewConfiguration(image: .emptyTrash, title: "No files or folders in trash", message: "\n")

    static let noConnection = EmptyViewConfiguration(image: .genericError, title: "Your device has no connection", message: "We cannot read contents of this folder")
}
