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

import AVKit
import Combine
import PDCore
import PDUIComponents
import ProtonCoreUIFoundations
import SwiftUI
import UIKit

final class PhotosPreviewViewController<ViewModel: PhotosPreviewViewModelProtocol>: UIPageViewController, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
    private let viewModel: ViewModel
    private let actionViewModel: PhotosPreviewActionViewModel
    private let factory: PhotosPreviewDetailFactory
    private let actionViewController: UIViewController
    private var overflowBarButtonItem: UIBarButtonItem?
    private var cancellables = Set<AnyCancellable>()
    private var interactionController: UIPercentDrivenInteractiveTransition?
    private let customTransitionDelegate = PhotosPreviewModalTransitioningDelegate()
    private var actionViewHeightConstraint: NSLayoutConstraint?
    private var actionViewBottomConstraint: NSLayoutConstraint?
    private var actionViewTopConstraint: NSLayoutConstraint?

    init(
        viewModel: ViewModel,
        actionViewModel: PhotosPreviewActionViewModel,
        factory: PhotosPreviewDetailFactory,
        actionViewController: UIViewController
    ) {
        self.viewModel = viewModel
        self.actionViewModel = actionViewModel
        self.factory = factory
        self.actionViewController = actionViewController
        super.init(transitionStyle: .scroll, navigationOrientation: .horizontal)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        subscribeToUpdates()
        handleUpdate()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if UIDevice.current.userInterfaceIdiom == .phone {
            lockOrientationIfNeeded(in: .allButUpsideDown)
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        do {
            // Video items can configure the audio session and reset it when the preview is closed
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            Log.error("setting AVAudioSession active failed", error: error, domain: .photosUI)
        }
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        coordinator.animateAlongsideTransition(in: nil, animation: { [weak self] _ in
            self?.setupNavigationControls()
        })
    }

    private func subscribeToUpdates() {
        subscribe(to: viewModel) { [weak self] in
            self?.handleUpdate()
        }
        .store(in: &cancellables)

        actionViewModel.$actions
            .receive(on: DispatchQueue.main)
            .sink { [weak self] actions in
                self?.updateOverflowMenu(actions.more)
            }
            .store(in: &cancellables)

        viewModel.resetPreviewPublisher
            .sink { [weak self] direction in
                self?.resetFirstPreview(direction: direction)
            }
            .store(in: &cancellables)
    }

    private func handleUpdate() {
        title = viewModel.title
        let isDefaultLayout = viewModel.mode == .default
        view.backgroundColor = isDefaultLayout ? ColorProvider.BackgroundNorm : ColorProvider.Black
        setupNavigationControls()
    }

    // MARK: - Dismissal

    @objc func close() {
        resetOrientation()
        startAutomaticDismiss()
    }

    private func resetOrientation() {
        if UIDevice.current.userInterfaceIdiom == .phone {
            lockOrientationIfNeeded(in: .portrait)
        }
    }

    @objc private func handleTransition(_ gestureRecognizer: UIPanGestureRecognizer) {
        let translation = gestureRecognizer.translation(in: view).y
        let percentage = translation / view.frame.height

        switch gestureRecognizer.state {
        case .began:
            startInteractiveDismiss()
        case .changed:
            interactionController?.update(percentage)
        case .ended:
            if percentage > 0.3 { // The minimal portion of screen that needs to be swiped to invoke closing
                interactionController?.finish()
                resetOrientation()
            } else {
                interactionController?.cancel()
            }
        default:
            break
        }
    }

    private func startInteractiveDismiss() {
        interactionController = UIPercentDrivenInteractiveTransition()
        customTransitionDelegate.interactionController = interactionController
        navigationController?.transitioningDelegate = customTransitionDelegate
        navigationController?.modalPresentationStyle = .custom
        viewModel.close()
    }

    private func startAutomaticDismiss() {
        navigationController?.transitioningDelegate = nil
        navigationController?.modalPresentationStyle = .fullScreen
        viewModel.close()
    }

    // MARK: - UIPageViewControllerDataSource

    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        let item = viewModel.getPreviousItem()
        return makeViewController(with: item)
    }

    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        let item = viewModel.getNextItem()
        return makeViewController(with: item)
    }

    private func makeViewController(with item: PhotosPreviewItem?) -> UIViewController? {
        return item.map(factory.makeViewController)
    }

    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        updateCurrentItem()
    }

    private func updateCurrentItem() {
        getVisibleItem()?.setActive()
        viewModel.previewItemIsChanged()
    }

    private func getVisibleItem() -> PhotosPreviewItemView? {
        return viewControllers?.first as? PhotosPreviewItemView
    }
}

// MARK: - View setup
extension PhotosPreviewViewController {
    private func setupView() {
        setupActionView()
        delegate = self
        dataSource = self
        setUpCloseButton(showCloseButton: true, action: #selector(close))
        setupFirstPreview()
        addPanGestureRecognizer()
    }

    private func setupActionView() {
        addChild(actionViewController)
        view.addSubview(actionViewController.view)
        actionViewController.didMove(toParent: self)
        actionViewController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            actionViewController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            actionViewController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        actionViewBottomConstraint = actionViewController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        actionViewTopConstraint = actionViewController.view.topAnchor.constraint(equalTo: view.bottomAnchor)
    }

    private func setupNavigationControls() {
        let isNavigationBarHidden = viewModel.mode == .default
        navigationController?.setNavigationBarHidden(!isNavigationBarHidden, animated: true)
        updateBottomActionView(isVisible: isNavigationBarHidden)
        updateOverflowMenu(actionViewModel.actions.more)
    }

    private func updateOverflowMenu(_ actions: [PhotosAction]?) {
        guard let actions, !actions.isEmpty else {
            navigationItem.rightBarButtonItem = nil
            return
        }

        let menuActions = PhotosActionBarMapping.makeUIActions(from: actions) { [weak self] action in
            self?.actionViewModel.handle(action: action)
        }
        let menu = UIMenu(children: menuActions)

        if overflowBarButtonItem == nil {
            let barButtonItem = UIBarButtonItem(image: IconProvider.threeDotsHorizontal, menu: menu)
            barButtonItem.accessibilityIdentifier = "PhotosPreview.Button.MoreSingle"
            barButtonItem.tintColor = ColorProvider.IconNorm
            overflowBarButtonItem = barButtonItem
        } else {
            overflowBarButtonItem?.menu = menu
        }

        navigationItem.rightBarButtonItem = overflowBarButtonItem
    }

    private func setupFirstPreview() {
        guard let item = viewModel.getCurrentItem() else {
            dismiss(animated: true)
            return
        }
        let viewController = factory.makeViewController(with: item)
        setViewControllers([viewController], direction: .forward, animated: false)
        updateCurrentItem()
    }

    private func resetFirstPreview(direction: PreviewDirection) {
        guard let item = viewModel.getCurrentItem(), direction != .dismiss else {
            dismiss(animated: true)
            return
        }
        let dir: UIPageViewController.NavigationDirection = direction == .forward ? .forward : .reverse
        let viewController = factory.makeViewController(with: item)
        setViewControllers([viewController], direction: dir, animated: true)
        updateCurrentItem()
    }

    private func addPanGestureRecognizer() {
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handleTransition(_:)))
        navigationController?.view.addGestureRecognizer(panGesture)
    }

    private func updateBottomActionView(isVisible: Bool) {
        guard let actionViewBottomConstraint, let actionViewTopConstraint else {
            return
        }
        guard actionViewBottomConstraint.isActive != isVisible || actionViewTopConstraint.isActive == isVisible else {
            return
        }
        UIView.animate(withDuration: 0.25) {
            actionViewBottomConstraint.isActive = isVisible
            actionViewTopConstraint.isActive = !isVisible
            self.view.layoutIfNeeded()
        }
    }
}
