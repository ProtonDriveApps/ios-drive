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

import SwiftUI
import ProtonCoreUIFoundations
import PDUIComponents

final class EditNodeViewController: UIViewController {
    private lazy var closeButton = makeCloseButton()
    private lazy var actionButton = makeRightBarButton()
    private lazy var textField = makeTextField()
    private lazy var caption = makeCaption()
    private lazy var spinner = UIHostingController(rootView: ProtonSpinner(size: .medium))
    private var didShowKeyboard = false

    var viewModel: EditNodeViewModel!
    var tfViewModel: NameFormattingViewModel!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ColorProvider.BackgroundSecondary

        setupNavigationBar()
        setupTextField()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        title = viewModel.title
        textField.attributedText = tfViewModel.attributed(viewModel.fullName)
        textField.placeholder = viewModel.placeHolder
        textField.setPadding(UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16))

        viewModel.onPerformingRequest = { [weak self] in
            self?.actionButton.isEnabled = false
            self?.textField.resignFirstResponder()
            self?.showSpinner()
        }

        viewModel.onSuccess = { [weak self] in
            DispatchQueue.main.async {
                self?.hideSpinner()
                self?.dismissViewController()
            }
        }
        
        viewModel.onError = { [weak self] error in
            DispatchQueue.main.async {
                self?.hideSpinner()
                self?.showError(error)
                self?.navigationItem.rightBarButtonItem?.isEnabled = true
            }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if !didShowKeyboard {
            textField.becomeFirstResponder()
            textField.markText(at: tfViewModel.preselectedRange())
            didShowKeyboard = true
        }
    }

    func setupNavigationBar() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(customView: closeButton)
        navigationItem.rightBarButtonItem = actionButton
        navigationItem.rightBarButtonItem?.isEnabled = false
    }

    private func showError(_ error: Error) {
        // Longer duration for UI test to prevent test failed due to banner dismiss too early
        let duration: TimeInterval = Constants.isUITest ? 90 : 4
        let banner = PMBanner(
            message: error.localizedDescription,
            style: PMBannerNewStyle.error,
            dismissDuration: duration
        )
        banner.accessibilityIdentifier = "EditNodeViewController.showError.errorToast"
        banner.show(at: .bottom, on: self)
    }

    private func showSpinner() {
        addChild(spinner)
        spinner.view.alpha = 0.5
        spinner.view.frame = view.frame
        view.addSubview(spinner.view)
        spinner.didMove(toParent: self)
    }

    private func hideSpinner() {
        spinner.removeFromParent()
        spinner.view.removeFromSuperview()
    }

    private func setupTextField() {
        view.addSubview(textField)
        view.addSubview(caption)

        NSLayoutConstraint.activate([
            textField.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            textField.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            textField.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            textField.heightAnchor.constraint(equalToConstant: 92),
            caption.topAnchor.constraint(equalTo: textField.bottomAnchor, constant: 8),
            caption.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            caption.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: 16),
        ])
    }

    @objc func dismissViewController() {
        // with this artificial delay the app looks more smooth and not so sharp
        DispatchQueue.main.async {
            self.textField.resignFirstResponder()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.dismiss(animated: true, completion: self.viewModel.close)
            }
        }
    }

    @objc func performButtonAction() {
        guard let text = textField.text else {
            return
        }
        viewModel.setName(to: text)
    }

    @objc func textFieldDidChange() {
        guard let newText = textField.text else { return }
        let validations = viewModel.validate(newText)
        navigationItem.rightBarButtonItem?.isEnabled = validations.isEmpty
        caption.text = validations.first?.message

        let currentPosition = textField.selectedTextRange?.end ?? textField.beginningOfDocument

        textField.attributedText = tfViewModel.attributed(newText)
        textField.selectedTextRange = textField.textRange(from: currentPosition, to: currentPosition)
    }
}

extension EditNodeViewController {
    static var nameAttributes: [NSAttributedString.Key: Any] {
        [.foregroundColor: UIColor(ColorProvider.TextNorm)]
    }

    static var extensionAttributes: [NSAttributedString.Key: Any] {
        [.foregroundColor: UIColor(ColorProvider.TextHint)]
    }
}

extension EditNodeViewController {
    private func makeCloseButton() -> UIButton {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(IconProvider.cross, for: .normal)
        button.tintColor = ColorProvider.TextNorm
        button.imageView?.setSizeContraint(height: 24, width: 24)
        button.addTarget(self, action: #selector(dismissViewController), for: .touchUpInside)
        button.accessibilityIdentifier = "EditNodeViewController.makeCloseButton.close"
        return button
    }

    private func makeRightBarButton() -> UIBarButtonItem {
        let button = UIBarButtonItem(title: viewModel.buttonText,
                                     style: .done,
                                     target: self,
                                     action: #selector(performButtonAction))
        button.setTitleTextAttributes([.font: UIFont.preferredFont(forTextStyle: .headline),
                                       .foregroundColor: UIColor(ColorProvider.TextAccent)],
                                      for: .normal)
        button.setTitleTextAttributes([.font: UIFont.preferredFont(forTextStyle: .headline),
                                       .foregroundColor: UIColor(ColorProvider.TextDisabled)],
                                      for: .disabled)
        button.accessibilityIdentifier = "EditNodeViewController.makeRightBarButton.Save"
        return button
    }

    private func makeTextField() -> UITextField {
        let textField = UITextField()
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.font = UIFont.preferredFont(forTextStyle: .title2)
        textField.textColor = ColorProvider.TextNorm
        textField.autocapitalizationType = .none
        textField.autocorrectionType = .no
        textField.backgroundColor = ColorProvider.BackgroundNorm
        textField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        textField.accessibilityIdentifier = "EditNodeViewController.makeTextField.ItemName"
        return textField
    }

    private func makeCaption() -> UILabel {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.preferredFont(forTextStyle: .footnote)
        label.textColor = ColorProvider.NotificationError
        label.adjustsFontForContentSizeCategory = true
        label.textAlignment = .left
        label.numberOfLines = 0
        label.accessibilityIdentifier = "EditNodeViewController.makeCaption.label"
        return label
    }
}

private extension UITextField {
    func setPadding(_ insets: UIEdgeInsets) {
        let height = frame.size.height - insets.top - insets.bottom
        let leftSize = CGSize(width: insets.left, height: height)
        let rightSize = CGSize(width: insets.right, height: height)
        let leftView = UIView(frame: CGRect(origin: .zero, size: leftSize))
        let rightView = UIView(frame: CGRect(origin: .zero, size: rightSize))
        self.leftView = leftView
        self.rightView = rightView

        leftViewMode = .always
        rightViewMode = .always
    }
}

extension UITextField {
    func markText(at range: NSRange?) {
        guard let range = range,
            let endPosition = position(from: beginningOfDocument, offset: range.length) else {
            return
        }
        selectedTextRange = textRange(from: beginningOfDocument, to: endPosition)
    }
}
