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

import Foundation
import Combine
import PDCore

final class FeatureFlagConstraintController<Store: PhotosUploadDisabledFeatureFlagStore>: PhotoBackupConstraintController where Store: NSObject {
    private let resource: Store
    private let keyPath: KeyPath<Store, Bool>
    private let subject = CurrentValueSubject<Bool, Never>(false)
    private var cancellables = Set<AnyCancellable>()
    
    var constraint: AnyPublisher<Bool, Never> {
        subject.eraseToAnyPublisher()
    }
    
    init(resource: Store, keyPath: KeyPath<Store, Bool>) {
        self.resource = resource
        self.keyPath = keyPath
        subscribeToUpdates()
    }
    
    private func subscribeToUpdates() {
        resource.publisher(for: keyPath)
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isDisabled in
                Log.info("🇨🇭 Changed .photosUploadDisabled feature flag state to: \(isDisabled)", domain: .application)
                self?.subject.send(isDisabled)
            }
            .store(in: &cancellables)
    }
}
