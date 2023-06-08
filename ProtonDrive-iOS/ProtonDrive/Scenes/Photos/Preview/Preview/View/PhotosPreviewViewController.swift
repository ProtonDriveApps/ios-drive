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

final class PhotosPreviewViewController<ViewModel: PhotosPreviewViewModelProtocol>: UIPageViewController, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
    private let viewModel: ViewModel
    private let factory: PhotosPreviewDetailFactory
    private var cancellables = Set<AnyCancellable>()

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
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if UIDevice.current.userInterfaceIdiom == .phone {
            (UIApplication.shared.delegate as? AppDelegate)?.lockOrientationIfNeeded(in: .allButUpsideDown)
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        if UIDevice.current.userInterfaceIdiom == .phone {
            (UIApplication.shared.delegate as? AppDelegate)?.lockOrientationIfNeeded(in: .portrait)
        }
        super.viewWillDisappear(animated)
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
        if let viewController = factory.makeViewController(with: viewModel.getCurrentItem()) {
            setViewControllers([viewController], direction: .forward, animated: false)
            updateCurrentItem()
        }
    }

    private func makeBarButtons() -> [UIBarButtonItem] {
        let buttons = [
            UIBarButtonItem(image: IconProvider.arrowUpFromSquare, style: .plain, target: self, action: #selector(share)),
        ]
        buttons.forEach { $0.tintColor = ColorProvider.IconNorm }
        return buttons
    }

    @objc private func close() {
        viewModel.close()
    }

    @objc private func share() {
        getVisibleItem()?.share()
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
        if let item = item {
            return factory.makeViewController(with: item)
        } else {
            return nil
        }
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
