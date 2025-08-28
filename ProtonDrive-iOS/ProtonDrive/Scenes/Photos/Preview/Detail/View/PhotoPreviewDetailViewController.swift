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
import Photos
import enum ProtonCoreUtilities.Either
import PDUIComponents

final class PhotoPreviewDetailViewController<ViewModel: PhotoPreviewDetailViewModelProtocol>: UIViewController, PhotosPreviewItemView {
    private let viewModel: ViewModel
    private let loadingViewController: UIViewController
    private var cancellables = Set<AnyCancellable>()
    private weak var rootViewController: UIViewController?
    private lazy var contentView = UIView()
    private weak var interactiveView: InteractiveImageView?
    private weak var videoViewController: UIViewController?
    private var isContentUpdateNeeded = false
    private var isFirstLoading = true
    private var gestureRecognizers = [UIGestureRecognizer]()
    private var displayMode: PhotosPreviewMode = .default {
        didSet { interactiveView?.updateCurrentDisplayMode(mode: displayMode) }
    }

    init(viewModel: ViewModel, loadingViewController: UIViewController) {
        self.viewModel = viewModel
        self.loadingViewController = loadingViewController
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        prepareView()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        prepareView()
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

    private func prepareView() {
        // Needs to be called asap from `viewDidLoad` or `viewWillAppear`, whichever is called first
        // They're not always called in correct order. 😱
        guard isFirstLoading else {
            return
        }

        isFirstLoading = false
        view.addSubview(contentView)
        contentView.fillSuperview()
        subscribeToUpdates()
        viewModel.viewDidLoad()
        subscribeAppTermination()
    }

    private func subscribeToUpdates() {
        subscribe(to: viewModel) { [weak self] in
            self?.handleUpdate()
        }
        .store(in: &cancellables)
        
        viewModel.mode
            .sink { [weak self] mode in
                self?.displayMode = mode
            }
            .store(in: &cancellables)
    }

    private func resetContent() {
        children.forEach { $0.remove() }
        contentView.subviews.forEach { $0.removeFromSuperview() }
        gestureRecognizers.forEach { view.removeGestureRecognizer($0) }
        videoViewController = nil
    }

    private func handleUpdate() {
        guard let state = viewModel.state else { return }

        switch state {
        case let .loading(loadingText):
            resetContent()
            addLoading(text: loadingText)
        case let .preview(fullPreview):
            addFullPreview(fullPreview)
        case let .error(title: title, text: text):
            resetContent()
            addError(title: title, text: text)
        }
    }

    private func addLoading(text: String) {
        let loadingView = LoadingWithTextView(text: text)
        contentView.addSubview(loadingView)
        loadingView.centerInSuperview()
        addDefaultGestureRecognizers()
    }

    private func setupImageView(with data: PreviewDataType) {
        if videoViewController != nil {
            resetContent()
        }
        if let imageView = interactiveView {
            imageView.setupLayout(with: data)
        } else {
            addInteractiveImageView(with: data)
        }
    }

    private func addInteractiveImageView(with data: PreviewDataType) {
        let loadingViewWrapper = UIView()
        loadingViewWrapper.backgroundColor = .clear
        let imageView = InteractiveImageView(data: data, displayMode: displayMode, parentViewController: self, loadingView: loadingViewWrapper)
        contentView.addSubview(imageView)
        imageView.fillSuperview()
        interactiveView = imageView
        add(loadingViewController, to: loadingViewWrapper)
        addDefaultGestureRecognizers()
    }

    private func addVideoView(with url: URL) {
        let viewController = VideoContentViewController(url: url)
        add(viewController, to: contentView)
        addVideoGestureRecognizers()
        videoViewController = viewController
    }

    private func addError(title: String, text: String) {
        let configuration = PlaceholderViewConfiguration(image: .type(.cloudError), title: title, message: text)
        let viewController = UIHostingController(rootView: PlaceholderView(viewModel: configuration))
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
            setupImageView(with: .thumbnail(data))
        case let .image(url):
            let data = (try? Data(contentsOf: url)) ?? Data()
            setupImageView(with: .image(data))
        case let .gif(url):
            let data = (try? Data(contentsOf: url)) ?? Data()
            setupImageView(with: .gif(data))
        case let .video(url):
            resetContent()
            addVideoView(with: url)
        case let .livePhoto(photoURL, videoURL, isLoading):
            setupImageView(with: .livePhoto(photoURL, videoURL, isLoading))
        case let .burstPhoto(photoURL, childrenURLs, isLoading):
            setupImageView(with: .burstPhoto(photoURL, childrenURLs, isLoading))
        }
    }

    @objc private func handleTap() {
        // Long press live photo can play it
        // Somehow if finger leaves device short enough, tap gesture will be triggered
        // This will toggle mode introduces bad UX
        // Use `isAfterLivePhotoPlayed` to debounce 
        let shouldDebounce = interactiveView?.isAfterLivePhotoPlayed ?? false
        if shouldDebounce { return }
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
    
    private func subscribeAppTermination() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillTerminate),
            name: UIApplication.willTerminateNotification,
            object: nil
        )
    }
    
    @objc
    private func appWillTerminate() {
        viewModel.cleanup()
    }

    // MARK: - PhotosPreviewItemView

    func setActive() {
        viewModel.setActive()
    }

    func share() {
        viewModel.share()
    }
}
