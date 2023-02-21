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

import PDFKit

final class PDFThumbnailProvider: ThumbnailProvider {
    var next: ThumbnailProvider?

    func getThumbnail(from url: URL) -> Image? {
        guard MimeType(fromFileExtension: url.pathExtension) == .pdf else { return next?.getThumbnail(from: url) }

        let document = PDFDocument(url: url)?.page(at: .zero)
        let image = document?.thumbnail(of: self.maximumSize, for: .trimBox)

        #if os(iOS)
            return image?.cgImage
        #else
            return image?.cgImage(forProposedRect: nil, context: nil, hints: nil)
        #endif
    }
}
