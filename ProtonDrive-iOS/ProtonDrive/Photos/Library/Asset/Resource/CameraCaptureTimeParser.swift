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

import Foundation
import ImageIO

struct CameraCaptureTimeParser {
    private static let defaultDateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return dateFormatter
    }()

    private let formatter: DateFormatter

    init(formatter: DateFormatter = Self.defaultDateFormatter) {
        self.formatter = formatter
    }

    /// In order of preference
    /// 1. DateTimeOriginal (time when the picture was actually taken)
    /// 2. DateTimeDigitized (time when the picture was converted from analog, but also known as CreateDate)
    /// 3. DateTime (what we currently have)
    /// 4. File modification time
    /// - Parameter exif: EXIF dictionary, dictionary[kCGImagePropertyExifDictionary]
    func parseCameraCaptureTime(fromExif exif: NSDictionary) -> (captureTime: Date?, modificationTime: Date?) {
        var modificationTime: Date?
        if let modificationTimeString = exif[kCGImagePropertyPNGModificationTime] as? String {
            modificationTime = formatter.date(from: modificationTimeString)
        }

        if let captureTimeString = exif[kCGImagePropertyExifDateTimeOriginal] as? String {
            return (formatter.date(from: captureTimeString), modificationTime)
        } else if let timeDigitized = exif[kCGImagePropertyExifDateTimeDigitized] as? String {
            return (formatter.date(from: timeDigitized), modificationTime)
        }
        return (nil, modificationTime)
    }
}
