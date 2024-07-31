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

struct PhotosBackupStatesInput: Equatable {
    let progress: PhotosBackupProgress?
    let failures: Int
    let isComplete: Bool
    let isLibraryLoading: Bool
    let isBackupEnabled: Bool
    let permissions: PhotoLibraryPermissions
    let networkConstraint: NetworkConstraint?
    let isQuotaConstrained: Bool
    let isStorageConstrained: Bool
    let isFeatureFlagConstrained: Bool
    let isApplicationStateConstrained: Bool
}

protocol PhotosBackupStateStrategy {
    func map(input: PhotosBackupStatesInput) -> PhotosBackupState
}

final class PrioritizedPhotosBackupStateStrategy: PhotosBackupStateStrategy {
    func map(input: PhotosBackupStatesInput) -> PhotosBackupState {
        guard input.isBackupEnabled else {
            return .disabled
        }

        guard input.permissions == .full else {
            return .restrictedPermissions
        }
        
        guard !input.isFeatureFlagConstrained else {
            return .featureFlag
        }

        if let constraint = input.networkConstraint {
            return .networkConstrained(constraint)
        }

        guard !input.isStorageConstrained else {
            return .storageConstrained
        }

        guard !input.isQuotaConstrained else {
            return .quotaConstrained
        }

        guard !input.isApplicationStateConstrained else {
            return .applicationStateConstrained
        }

        guard !input.isLibraryLoading else {
            return .libraryLoading
        }

        guard !input.isComplete else {
            if input.failures > 0 {
                return .completeWithFailures(input.failures)
            } else {
                return .complete
            }
        }

        if let progress = input.progress, !progress.isCompleted {
            return .inProgress(progress)
        } else {
            return .empty
        }
    }
}
