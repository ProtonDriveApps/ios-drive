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

/// Tracking upload of a single file, mainly its duration plus size in kilobytes and mediaType
/// Since we want to track only real execution time, isolating from any queue interruptions / suspensions, the upload can be resumed and suspended multiple times. No `start` is implemented due to that, `resume` will either kick off the upload time measurement or will start adding to already tracked duration.
/// To record additional data we should call `set(kilobytes:mediaType:)` once before succeeding / failing
public protocol PhotoUploadMeasurementRepository {
    func resume()
    func pause()
    func succeed()
    func fail()
    func set(kilobytes: Double, mimeType: MimeType)
}
