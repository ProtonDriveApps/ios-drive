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
import ProtonCore_UIFoundations
import UIKit

final class PhotoPreviewDetailViewController<ViewModel: PhotoPreviewDetailViewModelProtocol>: UIViewController, PhotosPreviewItemView {
    private let viewModel: ViewModel
    private var cancellables = Set<AnyCancellable>()
    private weak var rootViewController: UIViewController?
    private lazy var contentView = UIView()
    private var interactiveView: InteractiveImageView?

    init(viewModel: ViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        subscribeToUpdates()
        handleUpdate()
        viewModel.viewDidLoad()
    }

    private func subscribeToUpdates() {
        subscribe(to: viewModel) { [weak self] in
            self?.handleUpdate()
        }
        .store(in: &cancellables)
    }

    private func handleUpdate() {
        contentView.subviews.forEach { $0.removeFromSuperview() }
        if let thumbnail = viewModel.thumbnail {
            addThumbnailView(data: thumbnail)
        }
        if let loading = viewModel.loading {
            addLoading(text: loading)
        }
        if let fullPreview = viewModel.fullPreview {
            addFullPreview(fullPreview)
        }
    }

    private func setupView() {
        view.addSubview(contentView)
        contentView.fillSuperview()
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        tapGestureRecognizer.numberOfTapsRequired = 1
        view.addGestureRecognizer(tapGestureRecognizer)
        let doubleTapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap))
        doubleTapGestureRecognizer.numberOfTapsRequired = 2
        view.addGestureRecognizer(doubleTapGestureRecognizer)
        tapGestureRecognizer.require(toFail: doubleTapGestureRecognizer)
    }

    private func addThumbnailView(data: Data) {
        let imageView = BlurredImageView(data: data)
        contentView.addSubview(imageView)
        imageView.fillSuperview()
    }

    private func addLoading(text: String) {
        let loadingView = LoadingWithTextView(text: text)
        view.addSubview(loadingView)
        loadingView.centerInSuperview()
    }

    private func addInteractiveImageView(with data: Data) {
        let imageView = InteractiveImageView(data: data)
        contentView.addSubview(imageView)
        imageView.fillSuperview()
        interactiveView = imageView
    }

    private func addFullPreview(_ preview: PhotoFullPreview) {
        switch preview {
        case let .photo(data):
            addInteractiveImageView(with: data)
        case let .video(url):
            // TODO: next MR
            break
        }
    }

    @objc private func handleTap() {
        viewModel.toggleMode()
    }

    @objc private func handleDoubleTap() {
        interactiveView?.handleDoubleTap()
    }

    // MARK: - PhotosPreviewItemView

    func setActive() {
        viewModel.setActive()
    }

    func share() {
        viewModel.share()
    }
}
