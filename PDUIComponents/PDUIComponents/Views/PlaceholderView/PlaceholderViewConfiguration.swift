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

#if os(iOS)
import PDLocalization
import SwiftUI
import ProtonCoreUIFoundations

public struct PlaceholderViewConfiguration: Equatable {
    public enum ImageType {
        case emptyShared
        case emptyFolder
        case emptyComputerRootFolder
        case offlineFiles
        case emptyTrash
        case genericError
        case cloudError
        case emptySharedByMe
        case emptySharedWithMe
        case updateRequired
        case emptyComputers
        case emptyPhotos
    }

    public enum Illustration {
        case type(ImageType)
        /// (image, height, accessibilityIdentifier)
        case image(Image, CGFloat, String)
    }

    public let image: Illustration
    public let imageColor: Color
    public let title: String
    public let message: String

    public init(
        image: Illustration,
        imageColor: Color = ColorProvider.IconNorm,
        title: String,
        message: String
    ) {
        self.image = image
        self.imageColor = imageColor
        self.title = title
        self.message = message
    }

    public func imageName(type: ImageType) -> String {
        switch type {
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
        case .updateRequired:
            return "upgrade-required"
        case .emptyComputers:
            return "empty-computers"
        case .emptyComputerRootFolder:
            return "empty-computer-root-folder"
        case .emptyPhotos:
            return "empty-photos"
        }
    }

    public var accessibilityIdentifier: String {
        switch image {
        case .type(let imageType):
            return imageName(type: imageType)
        case .image(_, _, let identifier):
            return identifier
        }
    }

    public static func == (lhs: PlaceholderViewConfiguration, rhs: PlaceholderViewConfiguration) -> Bool {
        guard lhs.title == rhs.title, lhs.message == rhs.message else { return false }
        switch (lhs.image, rhs.image) {
        case let (.type(lhsType), .type(rhsType)):
            return lhsType == rhsType
        case let (.image(_, _, lhsIdentifier), .image(_, _, rhsIdentifier)):
            return lhsIdentifier == rhsIdentifier
        default:
            return false
        }
    }
}

public extension PlaceholderViewConfiguration {
    static let folder = PlaceholderViewConfiguration(
        image: .type(.emptyFolder),
        title: Localization.empty_folder_title,
        message: Localization.empty_folder_message
    )

    static let folderWithoutMessage = PlaceholderViewConfiguration(
        image: .type(.emptyFolder),
        title: Localization.empty_folder_title,
        message: ""
    )

    static let emptyComputerRootFolder = PlaceholderViewConfiguration(
        image: .type(.emptyComputerRootFolder),
        title: Localization.empty_computer_root_folder_title,
        message: Localization.empty_computer_root_folder_message
    )

    static let trash = PlaceholderViewConfiguration(
        image: .type(.emptyTrash),
        title: Localization.trash_empty_title,
        message: Localization.trash_empty_message
    )

    static let shared = PlaceholderViewConfiguration(
        image: .type(.emptySharedByMe),
        title: Localization.share_empty_title,
        message: Localization.share_empty_message
    )

    static let sharedByMe = PlaceholderViewConfiguration(
        image: .type(.emptySharedByMe),
        title: Localization.shared_by_me_empty_title,
        message: Localization.shared_by_me_empty_message
    )

    static let sharedWithMe = PlaceholderViewConfiguration(
        image: .type(.emptySharedWithMe),
        title: Localization.shared_with_me_empty_title,
        message: Localization.shared_with_me_empty_message
    )

    static let offlineAvailable = PlaceholderViewConfiguration(
        image: .type(.offlineFiles),
        title: Localization.available_offline_empty_title,
        message: Localization.available_offline_empty_message
    )

    static let noConnection = PlaceholderViewConfiguration(
        image: .type(.genericError),
        title: Localization.disconnection_view_title,
        message: Localization.disconnection_folder_message
    )

    static let noConnectionInPhoto = PlaceholderViewConfiguration(
        image: .type(.genericError),
        title: Localization.disconnection_view_title,
        message: ""
    )

    static let computers = PlaceholderViewConfiguration(
        image: .type(.emptyComputers),
        title: Localization.computers_empty_title,
        message: Localization.computers_empty_message
    )

    static let emptyPhotos = PlaceholderViewConfiguration(
        image: .type(.emptyPhotos),
        title: Localization.empty_photos_title,
        message: ""
    )
}
#endif
