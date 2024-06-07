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

import CoreData

final class StreamRevisionEncryptorOperationFactory: DiscreteRevisionEncryptorOperationFactory {

    // TODO: Make use of the progress in the FileProvider
    override func makeBlocksRevisionEncryptor(progress: Progress, moc: NSManagedObjectContext, digestBuilder: DigestBuilder) -> RevisionEncryptor {
        return StreamRevisionEncryptor(signersKitFactory: signersKitFactory, maxBlockSize: maxBlockSize(), moc: moc, digestBuilder: digestBuilder)
    }
    
    override func makeThumbnailProvider() -> ThumbnailProvider {
        /*
         For some PDF files with a certain structure, `PDFThumbnailProvider` (specifically, underlying `PDFPage.thumbnail(of:for:)` call) exceeds memory limit of FileProvider extension on iOS.
         That does not seem to depend on characteristics of requested thumbnail, only on inner structure of exact PDF file.
         
         So in FileProvider extensions we do not support thumbnail provider for PDFs for now.

         Edit: For large image files the memory limit is also exceeded.
         So now we only support video thumbnails.
        */

        VideoThumbnailProvider()
    }

}
