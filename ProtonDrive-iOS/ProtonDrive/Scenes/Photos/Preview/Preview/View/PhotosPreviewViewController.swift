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
import UIKit

final class PhotosPreviewViewController<ViewModel: PhotosPreviewViewModelProtocol>: UIPageViewController, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
    private let viewModel: ViewModel
    private let factory: PhotosPreviewDetailFactory
    private var cancellables = Set<AnyCancellable>()
    private var interactionController: UIPercentDrivenInteractiveTransition?
    private let customTransitionDelegate = PhotosPreviewModalTransitioningDelegate()

    init(viewModel: ViewModel, factory: PhotosPreviewDetailFactory) {
        self.viewModel = viewModel
        self.factory = factory
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

    private func setupView() {
        toolbarItems = makeBarButtons()
        delegate = self
        dataSource = self
        setUpCloseButton(showCloseButton: true, action: #selector(close))
        setupFirstPreview()
        addPanGestureRecognizer()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if UIDevice.current.userInterfaceIdiom == .phone {
            (UIApplication.shared.delegate as? AppDelegate)?.lockOrientationIfNeeded(in: .allButUpsideDown)
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
    }

    private func handleUpdate() {
        title = viewModel.title
        let isDefaultLayout = viewModel.mode == .default
        view.backgroundColor = isDefaultLayout ? ColorProvider.BackgroundNorm : ColorProvider.Black
        setupNavigationControls()
    }

    private func setupNavigationControls() {
        let isDefaultLayout = viewModel.mode == .default
        let isLandscape = UIDevice.current.orientation.isLandscape
        let isToolbarHidden = !isDefaultLayout || isLandscape
        navigationItem.rightBarButtonItems = isLandscape ? makeBarButtons() : []
        navigationController?.setNavigationBarHidden(!isDefaultLayout, animated: true)
        navigationController?.setToolbarHidden(isToolbarHidden, animated: true)
    }

    private func setupFirstPreview() {
        let viewController = factory.makeViewController(with: viewModel.getCurrentItem())
        setViewControllers([viewController], direction: .forward, animated: false)
        updateCurrentItem()
    }

    private func makeBarButtons() -> [UIBarButtonItem] {
        let shareButton = UIBarButtonItem(image: IconProvider.arrowUpFromSquare, style: .plain, target: self, action: #selector(share))
        shareButton.accessibilityIdentifier = "PhotoPreviewDetail.ShareButton"
        let buttons = [shareButton]
        buttons.forEach { $0.tintColor = ColorProvider.IconNorm }
        return buttons
    }

    @objc private func share() {
        getVisibleItem()?.share()
    }

    // MARK: - Dismissal

    @objc override func close() {
        resetOrientation()
        startAutomaticDismiss()
    }

    private func resetOrientation() {
        if UIDevice.current.userInterfaceIdiom == .phone {
            (UIApplication.shared.delegate as? AppDelegate)?.lockOrientationIfNeeded(in: .portrait)
        }
    }

    private func addPanGestureRecognizer() {
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handleTransition(_:)))
        navigationController?.view.addGestureRecognizer(panGesture)
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
    }

    private func getVisibleItem() -> PhotosPreviewItemView? {
        return viewControllers?.first as? PhotosPreviewItemView
    }
}
