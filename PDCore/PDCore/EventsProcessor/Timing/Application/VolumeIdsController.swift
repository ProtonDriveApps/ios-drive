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

import Combine

struct VolumesList {
    let ownVolumes: Set<VolumeID>
    let sharedVolumes: Set<SharedVolume>

    struct SharedVolume: Hashable {
        let id: VolumeID
        let isActive: Bool

        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
    }
}

public protocol SharedVolumeIdsController {
    func addSharedVolumes(ids: [VolumeID])
    func removeSharedVolumes(ids: [VolumeID])
    func setActiveSharedVolume(id: VolumeID)
    func resignActiveSharedVolume()
}

protocol VolumeIdsControllerProtocol: SharedVolumeIdsController {
    var update: AnyPublisher<Void, Never> { get }
    func getVolumes() -> VolumesList
    func setMainVolume(id: VolumeID)
    func setPhotoVolume(id: VolumeID)
}

final class VolumeIdsController: VolumeIdsControllerProtocol {
    private typealias SharedVolume = VolumesList.SharedVolume

    private let subject = PassthroughSubject<Void, Never>()
    private var mainVolumeId: VolumeID?
    private var photoVolumeId: VolumeID?
    private var sharedVolumes = Set<SharedVolume>() {
        didSet {
            if oldValue != sharedVolumes {
                subject.send()
            }
        }
    }

    var update: AnyPublisher<Void, Never> {
        subject.eraseToAnyPublisher()
    }

    func getVolumes() -> VolumesList {
        return VolumesList(
            ownVolumes: Set([mainVolumeId, photoVolumeId].compactMap { $0 }),
            sharedVolumes: sharedVolumes
        )
    }

    func setMainVolume(id: VolumeID) {
        mainVolumeId = id
        subject.send()
    }

    func setPhotoVolume(id: VolumeID) {
        photoVolumeId = id
        subject.send()
    }

    func addSharedVolumes(ids: [VolumeID]) {
        let newVolumes = ids.map {
            SharedVolume(id: $0, isActive: false)
        }
        sharedVolumes.formUnion(newVolumes)
    }

    func removeSharedVolumes(ids: [VolumeID]) {
        sharedVolumes = sharedVolumes.filter { volume in
            !ids.contains(volume.id)
        }
    }

    func setActiveSharedVolume(id: VolumeID) {
        Log.info("Shared volume became active", domain: .events)
        // Mark specific id active and inactive all other ones
        let mappedVolumes = sharedVolumes.map { volume in
            SharedVolume(id: volume.id, isActive: volume.id == id)
        }
        sharedVolumes = Set(mappedVolumes)
    }

    func resignActiveSharedVolume() {
        Log.info("Shared volume resigned active", domain: .events)
        // Mark all volumes inactive
        let mappedVolumes = sharedVolumes.map { volume in
            SharedVolume(id: volume.id, isActive: false)
        }
        sharedVolumes = Set(mappedVolumes)
    }
}
