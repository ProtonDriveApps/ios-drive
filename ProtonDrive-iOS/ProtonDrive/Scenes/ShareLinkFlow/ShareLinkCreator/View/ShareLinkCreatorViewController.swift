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
import SwiftUI
import Combine
import PDUIComponents
import ProtonCore_UIFoundations

final class ShareLinkCreatorViewController: UIViewController {
    private let viewModel: ShareLinkCreatorViewModel
    private var closeButton: UIBarButtonItem!
    private let closeSubject: PassthroughSubject<Void, Never>

    var onClose: (() -> Void)?
    var didRetrieveSharedLink: (() -> Void)?

    init(viewModel: ShareLinkCreatorViewModel, closeSubject: PassthroughSubject<Void, Never>) {
        self.viewModel = viewModel
        self.closeSubject = closeSubject
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { nil }

    override func viewDidLoad() {
        super.viewDidLoad()

        closeButton = .close(on: self, action: #selector(closeTapped))
        navigationController?.navigationBar.isHidden = false
        navigationItem.setLeftBarButton(closeButton, animated: false)

        title = viewModel.title

        let view = ClosableLoadingView(
            message: viewModel.loadingMessage,
            closePublisher: closeSubject.eraseToAnyPublisher()
        )
        add(UIHostingController(rootView: view))
        viewModel.getSharedLink()
    }

    @objc private func closeTapped() {
        closeSubject.send(Void())
    }
}

private struct ClosableLoadingView: View {
    let message: String
    let closePublisher: AnyPublisher<Void, Never>

    @EnvironmentObject private var root: RootViewModel

    var body: some View {
        LoadingView(text: message)
            .onReceive(closePublisher) { _ in
                root.closeCurrentSheet.send()
            }
    }
}
