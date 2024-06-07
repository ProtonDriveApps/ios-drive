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

import Combine
import ProtonCoreUIFoundations
import SwiftUI
import UIKit

final class PhotoPreviewDetailViewController<ViewModel: PhotoPreviewDetailViewModelProtocol>: UIViewController, PhotosPreviewItemView {
    private let viewModel: ViewModel
    private var cancellables = Set<AnyCancellable>()
    private weak var rootViewController: UIViewController?
    private lazy var contentView = UIView()
    private weak var interactiveView: InteractiveImageView?
    private var isContentUpdateNeeded = true
    private var gestureRecognizers = [UIGestureRecognizer]()

    init(viewModel: ViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(contentView)
        contentView.fillSuperview()
        subscribeToUpdates()
        viewModel.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if isContentUpdateNeeded {
            handleUpdate()
            isContentUpdateNeeded = false
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        isContentUpdateNeeded = true
        resetContent()
    }

    private func subscribeToUpdates() {
        subscribe(to: viewModel) { [weak self] in
            self?.handleUpdate()
        }
        .store(in: &cancellables)
    }

    private func resetContent() {
        children.forEach { $0.remove() }
        contentView.subviews.forEach { $0.removeFromSuperview() }
        gestureRecognizers.forEach { view.removeGestureRecognizer($0) }
    }

    private func handleUpdate() {
        resetContent()

        guard let state = viewModel.state else {
            return
        }

        switch state {
        case let .loading(loadingText, thumbnail):
            thumbnail.map { addThumbnailView(data: $0) }
            addLoading(text: loadingText)
        case let .preview(fullPreview):
            addFullPreview(fullPreview)
        case let .error(title: title, text: text):
            addError(title: title, text: text)
        }
    }

    private func addThumbnailView(data: Data) {
        let imageView = BlurredImageView(data: data)
        contentView.addSubview(imageView)
        imageView.fillSuperview()
    }

    private func addLoading(text: String) {
        let loadingView = LoadingWithTextView(text: text)
        contentView.addSubview(loadingView)
        loadingView.centerInSuperview()
        addDefaultGestureRecognizers()
    }

    private func addInteractiveImageView(with data: Data) {
        let imageView = InteractiveImageView(data: data)
        imageView.accessibilityIdentifier = "PhotoPreviewDetail.Image"
        contentView.addSubview(imageView)
        imageView.fillSuperview()
        interactiveView = imageView
        addDefaultGestureRecognizers()
    }

    private func addVideoView(with url: URL) {
        let viewController = VideoContentViewController(url: url)
        add(viewController, to: contentView)
        addVideoGestureRecognizers()
    }

    private func addError(title: String, text: String) {
        let configuration = EmptyViewConfiguration(image: .cloudError, title: title, message: text)
        let viewController = UIHostingController(rootView: EmptyFolderView(viewModel: configuration))
        add(viewController, to: contentView)
    }

    private func setChildViewController(_ viewController: UIViewController) {
        addChild(viewController)
        contentView.addSubview(viewController.view)
        viewController.view.fillSuperview()
    }

    private func addDefaultGestureRecognizers() {
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        tapGestureRecognizer.numberOfTapsRequired = 1
        let doubleTapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap))
        doubleTapGestureRecognizer.numberOfTapsRequired = 2
        tapGestureRecognizer.require(toFail: doubleTapGestureRecognizer)
        gestureRecognizers = [tapGestureRecognizer, doubleTapGestureRecognizer]
        gestureRecognizers.forEach { view.addGestureRecognizer($0) }
    }

    private func addVideoGestureRecognizers() {
        let tapGestureRecognizer = SimultaneousTapGestureRecognizer(target: self, action: #selector(handleTap))
        view.addGestureRecognizer(tapGestureRecognizer)
        gestureRecognizers = [tapGestureRecognizer]
    }

    private func addFullPreview(_ preview: PhotoFullPreview) {
        switch preview {
        case let .thumbnail(data):
            addInteractiveImageView(with: data)
        case let .image(url):
            let data = (try? Data(contentsOf: url)) ?? Data()
            addInteractiveImageView(with: data)
        case let .video(url):
            addVideoView(with: url)
        }
    }

    @objc private func handleTap() {
        viewModel.toggleMode()
    }

    @objc private func handleDoubleTap() {
        interactiveView?.handleDoubleTap()
    }

    private func showError(_ error: PhotoPreviewDetailError) {
        let alertController = UIAlertController(title: nil, message: error.message, preferredStyle: .alert)
        let action = UIAlertAction(title: error.button, style: .cancel)
        alertController.addAction(action)
        present(alertController, animated: true)
    }

    // MARK: - PhotosPreviewItemView

    func setActive() {
        viewModel.setActive()
    }

    func share() {
        viewModel.share()
    }
}
