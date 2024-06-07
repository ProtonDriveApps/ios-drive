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
import PDUIComponents

public final class StartViewController: UIViewController {
    private var cancellables: Set<AnyCancellable> = []

    let launchView = UILaunchView()

    private lazy var spinner: UIView = ViewHosting {
        SpinnerTextView(text: "Signing out...")
    }

    private let loggingOutLabel = UILabel()

    public var viewModel: StartViewModel!
    public var onLoggingOut: (() -> Void)?
    public var onAuthenticated: (() -> Void)?
    public var onNonAuthenticated: (() -> Void)?

    override public func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ColorProvider.BackgroundNorm
        setupLoggingOutUI()

        viewModel.isSignedInPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isSignedIn in
                isSignedIn ? self?.performAuthenticated() : self?.performNonAuthenticated()
            }
            .store(in: &cancellables)
        
        viewModel.restartAppPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.performAuthenticated()
            }
            .store(in: &cancellables)

        viewModel.showLoggingOutPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.performLoggingOut()
            }
            .store(in: &cancellables)

        view.addSubview(launchView)
        launchView.fillSuperview()
    }

    private func performAuthenticated() {
        onAuthenticated?()
    }

    private func performNonAuthenticated() {
        onNonAuthenticated?()
    }

    private func performLoggingOut() {
        onLoggingOut?()
        showLoggingOutUI()
    }

    private func setupLoggingOutUI() {
        view.addSubview(spinner)
        spinner.centerInSuperview()
        spinner.isHidden = true
    }

    private func showLoggingOutUI() {
        launchView.isHidden = true
        spinner.isHidden = false
    }

    private func hideLoggingOutUI() {
        launchView.isHidden = false
        spinner.isHidden = true
    }
}
