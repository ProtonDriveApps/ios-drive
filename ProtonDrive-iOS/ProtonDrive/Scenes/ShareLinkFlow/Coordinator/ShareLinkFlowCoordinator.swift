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

import UIKit
import PDCore
import Combine
import SwiftUI
import PDUIComponents

final class ShareLinkFlowCoordinator {
    typealias Context = (node: Node, tower: Tower)

    @discardableResult
    func start(_ context: Context) -> some View {
        return AuxiliaryView(node: context.node, tower: context.tower)
    }

    private func makeEditLinkSection(vm: EditLinkViewModel) -> EditLinkView {
        EditLinkView(vm: vm)
    }
}

private struct AuxiliaryView: View {
    let node: Node
    let tower: Tower

    var body: some View {
        RepresentableShareLinkViewController(node: node, tower: tower)
            .ignoresSafeArea(.all)
    }
}

private struct RepresentableShareLinkViewController: UIViewControllerRepresentable {
    typealias UIViewControllerType = UINavigationController
    private let node: Node
    private let tower: Tower

    init(node: Node, tower: Tower) {
        self.node = node
        self.tower = tower
    }

    func makeUIViewController(context: Context) -> UIViewControllerType {
        let vc = makeShareLinkViewController()
        return UINavigationController(rootViewController: vc)
    }

    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) { }

    // MARK: - Share Link

    private func makeShareLinkViewModel(
        closeScreenSubject: PassthroughSubject<Void, Never>
    ) -> ShareLinkCreatorViewModel {
        let vm = ShareLinkCreatorViewModel(node: node, sharedLinkRepository: tower)
        vm.onErrorSharing = { closeScreenSubject.send(Void()) }
        return vm
    }

    func makeShareLinkViewController() -> ShareLinkCreatorViewController {
        let closeSubject = PassthroughSubject<Void, Never>()
        let viewModel = makeShareLinkViewModel(closeScreenSubject: closeSubject)
        let viewController = ShareLinkCreatorViewController(viewModel: viewModel, closeSubject: closeSubject)

        let coordinator = ShareLinkCreatorCoordinator(
            view: viewController,
            sharedViewControllerFactory: makeSharedLinkViewController
        )

        viewModel.onSharedLinkObtained = coordinator.goSharedLink
        return viewController
    }

    // MARK: - Shared Link
    func makeSharedLinkViewController(shareURL: ShareURL) -> UIViewController {
        let closeScreenSubject = PassthroughSubject<Void, Never>()
        let saveSubject = PassthroughSubject<Void, Never>()
        let canSavePublisher = CurrentValueSubject<Bool, Never>(false)
        let viewModel = makeSharedLinkEditorViewModel(closeScreenSubject, saveSubject, canSavePublisher.eraseToAnyPublisher())

        do  {
            let sharedLink = try SharedLink(shareURL: shareURL)
            let sharedLinkSubject = CurrentValueSubject<SharedLink, Never>(sharedLink)

            return SharedLinkEditorViewController(viewModel: viewModel) {
                UIHostingController(rootView: getShareLinkView(shareURL, closeScreenSubject, saveSubject, canSavePublisher, sharedLinkSubject))
            }
        } catch {
            let model = ShareLinkDecryptionErrorModel(shareURL: shareURL, repository: tower)
            let vm = ShareLinkDecryptionErrorViewModel(closeScreenSubject: closeScreenSubject.eraseToAnyPublisher(), model: model)
            return SharedLinkEditorViewController(viewModel: viewModel) {
                UIHostingController(rootView: ShareLinkDecryptionErrorView(vm: vm))
            }
        }
    }

    private func makeSharedLinkEditorViewModel(
        _ closeScreenSubject: PassthroughSubject<Void, Never>,
        _ saveChangesSubject: PassthroughSubject<Void, Never>,
        _ isSaveEnabledPublisher: AnyPublisher<Bool, Never>
    ) -> SharedLinkEditorViewModel {
        SharedLinkEditorViewModel(
            closeScreenSubject: closeScreenSubject,
            saveChangesSubject: saveChangesSubject,
            isSaveEnabledPublisher: isSaveEnabledPublisher
        )
    }

    private func getShareLinkView(
        _ shareURL: ShareURL,
        _ closeScreenSubject: PassthroughSubject<Void, Never>,
        _ saveChangesSubject: PassthroughSubject<Void, Never>,
        _ isSaveEnabledPublisher: CurrentValueSubject<Bool, Never>,
        _ sharedLinkSubject: CurrentValueSubject<SharedLink, Never>
    ) -> ShareLinkView<SharedLinkView<EditLinkView>> {
        let shareURL = tower.moveToMainContext(shareURL)
        let model = ShareLinkModel(node: node, sharedLinkSubject: sharedLinkSubject, shareURL: shareURL, repository: tower)
        let editingLinkSubject = CurrentValueSubject<EditableData, Never>(model.editable)

        let vm = ShareLinkViewModel(
            model: model,
            closeScreenSubject: closeScreenSubject.eraseToAnyPublisher(),
            saveChangesSubject: saveChangesSubject.eraseToAnyPublisher(),
            editingLinkSubject: editingLinkSubject.eraseToAnyPublisher(),
            isEditingSubject: isSaveEnabledPublisher
        )

        return ShareLinkView(vm: vm) {
            sharedLinkView(model, sharedLinkSubject, editingLinkSubject)
        }
    }

    private func sharedLinkView(
        _ model: ShareLinkModel,
        _ sharedLinkSubject: CurrentValueSubject<SharedLink, Never>,
        _ savingSubjectWritter: CurrentValueSubject<EditableData, Never>
    ) -> SharedLinkView<EditLinkView> {
        let editViewViewModel = EditLinkViewModel(
            model: model,
            savingSubjectWritter: savingSubjectWritter
        )
        let editView = EditLinkView(vm: editViewViewModel)

        let vm = SharedLinkViewModel(
            model: model,
            sharedLinkSubject: sharedLinkSubject,
            onCopyToClipboard: { UIPasteboard.general.string = $0 }
        )
        return SharedLinkView(vm: vm, editingView: editView)
    }
}
