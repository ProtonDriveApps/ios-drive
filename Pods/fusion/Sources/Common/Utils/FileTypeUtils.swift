//
//  FileTypeUtils.swift
//
//  ProtonMail - Created on 28.01.22.
//
//  The MIT License
//
//  Copyright (c) 2020 Proton Technologies AG
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

import UniformTypeIdentifiers
import CoreServices
import AVFoundation

public struct UTTypeProvider {

    public static func provideGifUTTypeIdentifier() -> CFString {
        let utTypeGif: CFString
        if #available(iOS 14.0, *) {
            utTypeGif = UTType.gif.identifier as CFString
        } else {
            utTypeGif = kUTTypeGIF
        }
        return utTypeGif
    }
}

public struct AVFileTypeProvider {

    public static func provideMp4AVFileType() -> AVFileType {
        AVFileType.mp4
    }
}

public struct FileExtensionProvider {

    public static func provideFileExtension(utTypeIdentifier: CFString) -> String? {
        if #available(iOS 14.0, *) {
            return UTType(utTypeIdentifier as String)?.preferredFilenameExtension
        } else {
            let preferredTag = UTTypeCopyPreferredTagWithClass(utTypeIdentifier as CFString, kUTTagClassFilenameExtension)
            let extractedExtension = preferredTag?.takeRetainedValue() as String?
            return extractedExtension
        }
    }

    public static func provideFileExtension(avFileType: AVFileType) -> String? {
        provideFileExtension(utTypeIdentifier: avFileType.rawValue as CFString)
    }
}
