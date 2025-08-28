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

#if os(iOS)
import SwiftUI
import ProtonCoreUIFoundations
import PDLocalization

public struct PlaceholderView<Header: View, Footer: View>: View {
    let viewModel: PlaceholderViewConfiguration
    let header: () -> Header
    let footer: () -> Footer

    public init(viewModel: PlaceholderViewConfiguration, header: @escaping () -> Header, footer: @escaping () -> Footer) {
        self.viewModel = viewModel
        self.header = header
        self.footer = footer
    }

    public var body: some View {
        VStack(alignment: .center, spacing: 32) {
            header()

            illustration()
                .resizable()
                .scaledToFit()
                .frame(maxHeight: maxImageHeight)
                .foregroundStyle(viewModel.imageColor)
                .padding(.horizontal, 24)
                .accessibilityIdentifier("placeholderView-illustration-\(viewModel.accessibilityIdentifier)")

            VStack(spacing: 16) {
                Text(viewModel.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(ColorProvider.TextNorm)
                    .accessibilityIdentifier("placeholderView-title-\(viewModel.accessibilityIdentifier)")

                Text(viewModel.message)
                    .font(.title3)
                    .fontWeight(.regular)
                    .foregroundColor(ColorProvider.TextWeak)
                    .accessibilityIdentifier("placeholderView-desc-\(viewModel.accessibilityIdentifier)")
            }
            .fixedSize(horizontal: false, vertical: true)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)

            footer()
        }
    }

    private func illustration() -> Image {
        switch viewModel.image {
        case .type(let imageType):
            let imageName = viewModel.imageName(type: imageType)
            return Image(imageName, bundle: .module)
        case .image(let image, _, _):
            return image
        }
    }
    
    // Throw away specific sizes when we have new standardized illustrations.
    private var maxImageHeight: CGFloat {
        switch viewModel.image {
        case .type(let type):
            switch type {
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
        case .image(_, let height, _):
            return height
        }
    }
}

public extension PlaceholderView where Footer == Spacer, Header == Spacer {
    init(viewModel: PlaceholderViewConfiguration) {
        self.init(viewModel: viewModel, header: { Spacer.init() }, footer: { Spacer.init() })
    }
}

public extension PlaceholderView where Footer == Spacer {
    init(viewModel: PlaceholderViewConfiguration, header: @escaping () -> Header) {
        self.init(viewModel: viewModel, header: header, footer: { Spacer.init() })
    }
}

public extension PlaceholderView where Header == Spacer {
    init(viewModel: PlaceholderViewConfiguration, footer: @escaping () -> Footer) {
        self.init(viewModel: viewModel, header: { Spacer.init() }, footer: footer)
    }
}
#endif
