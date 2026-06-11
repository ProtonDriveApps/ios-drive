// Copyright (c) 2026 Proton AG
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
import Foundation
import PDCore
import PDUIComponents
import ProtonCoreUtilities
import SwiftUI
import UIKit

final class DuplicateUploadHandler {
    private var cancellables = Set<AnyCancellable>()
    private let dependencies: Dependencies
    private var viewModel: DuplicationActionViewModel?
    private weak var presentedViewController: UIViewController?

    init(dependencies: Dependencies) {
        self.dependencies = dependencies
        subscribeToUpdates()
    }

    private func subscribeToUpdates() {
        dependencies.bootstrapStateController.bootstrappedPublisher
            .sink { [weak self] isBootstrapped in
                guard isBootstrapped else { return }
                self?.observeDuplication()
            }
            .store(in: &cancellables)
    }

    private func observeDuplication() {
        guard let uploader = dependencies.tower.getSdkFileUploader() else { return }
        Task { @MainActor in
            uploader.duplicated
                .sink { [weak self] duplication in
                    Task { @MainActor in
                        self?.handlePendingUploads(identifier: duplication.0, filename: duplication.1)
                    }
                }
                .store(in: &cancellables)
        }
    }
}

// MARK: - Sheet presenting
extension DuplicateUploadHandler {
    @MainActor
    private func presentSheet(viewModel: DuplicationActionViewModel) {
        let view = DuplicationActionView(viewModel: viewModel)
        let host = view.embeddedInTransparentHostingController()
        host.modalPresentationStyle = .overFullScreen
        UIApplication.shared.topViewController()?.present(host, animated: false)
        presentedViewController = host
    }

    @MainActor
    private func dismissSheet() {
        guard viewModel != nil else { return }
        viewModel?.onDismiss = nil
        viewModel = nil
        presentedViewController?.dismiss(animated: false)
        presentedViewController = nil
    }
}

// MARK: - Logic
extension DuplicateUploadHandler {
    @MainActor
    private func handlePendingUploads(identifier: AnyVolumeIdentifier, filename: String) {
        if presentedViewController == nil {
            viewModel = nil
        }

        if let viewModel = viewModel {
            viewModel.addDuplication(identifier, filename: filename)
        } else {
            let vm = DuplicationActionViewModel(items: [(identifier, filename)])
            vm.onAction = didSelectAction(for:action:)
            vm.onCancelAll = cancel(identifiers:)
            vm.onDismiss = dismissSheet
            self.viewModel = vm
            presentSheet(viewModel: vm)
        }
    }

    private func cancel(identifiers: [AnyVolumeIdentifier]) {
        guard
            !identifiers.isEmpty,
            let uploader = dependencies.tower.getSdkFileUploader()
        else { return }
        Task.detached {
            await identifiers.parallelForEach { try? await uploader.deleteUploadingFile(identifier: $0) }
        }
    }

    private func didSelectAction(for identifier: AnyVolumeIdentifier, action: DuplicateUploadAction) {
        guard let uploader = dependencies.tower.getSdkFileUploader() else {
            Log.warning("Can't find file uploader", domain: .uploader)
            assertionFailure()
            return
        }
        Task.detached {
            switch action {
            case .replace:
                _ = try await uploader.upload(identifier: identifier, duplicateAction: .replace)
            case .keepBoth:
                _ = try await uploader.upload(identifier: identifier, duplicateAction: .keepBoth)
            case .skip:
                try await uploader.deleteUploadingFile(identifier: identifier)
            }
        }
    }
}

extension DuplicateUploadHandler {
    struct Dependencies {
        let bootstrapStateController: BootstrapStateControllerProtocol
        let tower: Tower
    }
}
