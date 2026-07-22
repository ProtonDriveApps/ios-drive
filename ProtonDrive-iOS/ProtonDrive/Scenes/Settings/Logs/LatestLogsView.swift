// Copyright (c) 2024 Proton AG
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
import PDLocalization
import ProtonCoreUIFoundations

final class LatestLogsView: UIView {
    private static let matchHighlightColor = UIColor.systemYellow.withAlphaComponent(0.4)
    private static let currentMatchHighlightColor = UIColor.systemOrange.withAlphaComponent(0.6)
    var onSearchTextChanged: (() -> Void)?
    var onPreviousMatch: (() -> Void)?
    var onNextMatch: (() -> Void)?
    var onScrollToBottomTapped: (() -> Void)?
    var onScrollViewDidScroll: ((UIScrollView) -> Void)?

    private(set) lazy var textView: UITextView = {
        let textView = UITextView()
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.isEditable = false
        textView.font = .monospacedSystemFont(ofSize: UIFont.preferredFont(forTextStyle: .body).pointSize, weight: .regular)
        textView.delegate = self
        return textView
    }()

    var searchText: String? { searchTextField.text }

    private let findBarContainer = UIView()
    private let searchTextField = UITextField()
    private let previousMatchButton = UIButton(type: .system)
    private let nextMatchButton = UIButton(type: .system)
    private let matchCountLabel = UILabel()
    private let matchCountContainer = UIView()
    private let scrollToBottomButton = UIButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupFindBar()
        setupTextView()
        setupScrollToBottomButton()
    }

    required init?(coder: NSCoder) {
        nil
    }

    func configure(with state: LatestLogsViewState) {
        textView.attributedText = Self.makeAttributedLogText(from: state, textView: textView)

        matchCountLabel.isHidden = !state.showsMatchCount
        matchCountLabel.text = state.matchCountText
        previousMatchButton.isEnabled = state.isPreviousMatchEnabled
        nextMatchButton.isEnabled = state.isNextMatchEnabled
        updateMatchCountRightViewSize()
    }

    private static func makeAttributedLogText(from state: LatestLogsViewState, textView: UITextView) -> NSAttributedString {
        let baseFont = textView.font ?? .preferredFont(forTextStyle: .body)
        let baseColor = textView.textColor ?? .label
        let baseAttributes: [NSAttributedString.Key: Any] = [
            .font: baseFont,
            .foregroundColor: baseColor
        ]

        guard state.showsMatchCount, !state.matchRanges.isEmpty else {
            return NSAttributedString(string: state.logText, attributes: baseAttributes)
        }

        let attributed = NSMutableAttributedString(string: state.logText, attributes: baseAttributes)
        for (index, range) in state.matchRanges.enumerated() {
            let color = index == state.currentMatchIndex ? currentMatchHighlightColor : matchHighlightColor
            attributed.addAttribute(.backgroundColor, value: color, range: range)
        }
        return attributed
    }

    func setScrollToBottomButtonHidden(_ isHidden: Bool) {
        scrollToBottomButton.isHidden = isHidden
    }

    func scrollToMatch(_ range: NSRange) {
        textView.scrollRangeToVisible(range)
    }

    func scrollToEndOfLog() {
        let length = (textView.text as NSString).length
        guard length > 0 else { return }
        textView.scrollRangeToVisible(NSRange(location: length - 1, length: 1))
    }

    private func setupFindBar() {
        findBarContainer.translatesAutoresizingMaskIntoConstraints = false
        addSubview(findBarContainer)

        searchTextField.translatesAutoresizingMaskIntoConstraints = false
        searchTextField.borderStyle = .roundedRect
        searchTextField.clearButtonMode = .whileEditing
        searchTextField.placeholder = Localization.logs_search_placeholder
        searchTextField.returnKeyType = .search
        searchTextField.autocorrectionType = .no
        searchTextField.autocapitalizationType = .none
        searchTextField.accessibilityIdentifier = "LatestLogsView.searchTextField"
        searchTextField.addTarget(self, action: #selector(searchTextDidChange), for: .editingChanged)
        searchTextField.delegate = self
        findBarContainer.addSubview(searchTextField)

        configureNavigationButton(previousMatchButton, systemName: "chevron.up", action: #selector(didTapPreviousMatch))
        configureNavigationButton(nextMatchButton, systemName: "chevron.down", action: #selector(didTapNextMatch))
        findBarContainer.addSubview(previousMatchButton)
        findBarContainer.addSubview(nextMatchButton)

        setupMatchCountRightView()

        NSLayoutConstraint.activate([
            findBarContainer.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
            findBarContainer.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 8),
            findBarContainer.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -8),
            findBarContainer.heightAnchor.constraint(equalToConstant: 44),

            searchTextField.leadingAnchor.constraint(equalTo: findBarContainer.leadingAnchor),
            searchTextField.trailingAnchor.constraint(equalTo: previousMatchButton.leadingAnchor, constant: -8),
            searchTextField.centerYAnchor.constraint(equalTo: findBarContainer.centerYAnchor),

            nextMatchButton.trailingAnchor.constraint(equalTo: findBarContainer.trailingAnchor),
            nextMatchButton.centerYAnchor.constraint(equalTo: findBarContainer.centerYAnchor),
            nextMatchButton.widthAnchor.constraint(equalToConstant: 36),
            nextMatchButton.heightAnchor.constraint(equalToConstant: 36),

            previousMatchButton.trailingAnchor.constraint(equalTo: nextMatchButton.leadingAnchor, constant: -4),
            previousMatchButton.centerYAnchor.constraint(equalTo: findBarContainer.centerYAnchor),
            previousMatchButton.widthAnchor.constraint(equalToConstant: 36),
            previousMatchButton.heightAnchor.constraint(equalToConstant: 36)
        ])
    }

    private func setupMatchCountRightView() {
        matchCountLabel.translatesAutoresizingMaskIntoConstraints = false
        matchCountLabel.font = .preferredFont(forTextStyle: .caption1)
        matchCountLabel.textColor = ColorProvider.TextHint
        matchCountLabel.setContentHuggingPriority(.required, for: .horizontal)
        matchCountLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        matchCountLabel.isHidden = true

        matchCountContainer.translatesAutoresizingMaskIntoConstraints = false
        matchCountContainer.addSubview(matchCountLabel)
        NSLayoutConstraint.activate([
            matchCountLabel.topAnchor.constraint(equalTo: matchCountContainer.topAnchor),
            matchCountLabel.bottomAnchor.constraint(equalTo: matchCountContainer.bottomAnchor),
            matchCountLabel.leadingAnchor.constraint(equalTo: matchCountContainer.leadingAnchor, constant: 4),
            matchCountLabel.trailingAnchor.constraint(equalTo: matchCountContainer.trailingAnchor, constant: -8)
        ])

        searchTextField.rightView = matchCountContainer
        searchTextField.rightViewMode = .never
    }

    private func updateMatchCountRightViewSize() {
        guard !matchCountLabel.isHidden else {
            searchTextField.rightViewMode = .never
            return
        }

        let size = matchCountContainer.systemLayoutSizeFitting(
            UIView.layoutFittingCompressedSize,
            withHorizontalFittingPriority: .fittingSizeLevel,
            verticalFittingPriority: .fittingSizeLevel
        )
        matchCountContainer.frame = CGRect(origin: .zero, size: CGSize(width: max(size.width, 48), height: 36))
        searchTextField.rightView = matchCountContainer
        searchTextField.rightViewMode = .always
    }

    private func setupTextView() {
        addSubview(textView)

        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: findBarContainer.bottomAnchor, constant: 4),
            textView.leadingAnchor.constraint(equalTo: leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: trailingAnchor),
            textView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    private func setupScrollToBottomButton() {
        scrollToBottomButton.translatesAutoresizingMaskIntoConstraints = false
        scrollToBottomButton.setImage(UIImage(systemName: "chevron.down"), for: .normal)
        scrollToBottomButton.tintColor = UIColor(ColorProvider.IconNorm)
        scrollToBottomButton.backgroundColor = UIColor(ColorProvider.BackgroundNorm)
        scrollToBottomButton.layer.cornerRadius = 28
        scrollToBottomButton.layer.shadowColor = UIColor.black.cgColor
        scrollToBottomButton.layer.shadowOpacity = 0.2
        scrollToBottomButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        scrollToBottomButton.layer.shadowRadius = 4
        scrollToBottomButton.accessibilityLabel = "Scroll to bottom"
        scrollToBottomButton.accessibilityIdentifier = "LatestLogsView.scrollToBottomButton"
        scrollToBottomButton.addTarget(self, action: #selector(didTapScrollToBottom), for: .touchUpInside)
        addSubview(scrollToBottomButton)

        NSLayoutConstraint.activate([
            scrollToBottomButton.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -16),
            scrollToBottomButton.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -16),
            scrollToBottomButton.widthAnchor.constraint(equalToConstant: 56),
            scrollToBottomButton.heightAnchor.constraint(equalToConstant: 56)
        ])
    }

    private func configureNavigationButton(_ button: UIButton, systemName: String, action: Selector) {
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: systemName), for: .normal)
        button.tintColor = UIColor(ColorProvider.IconNorm)
        button.addTarget(self, action: action, for: .touchUpInside)
        button.isEnabled = false
        button.accessibilityIdentifier = "LatestLogsView.\(systemName.replacingOccurrences(of: ".", with: ""))"
    }

    @objc private func searchTextDidChange() {
        onSearchTextChanged?()
    }

    @objc private func didTapPreviousMatch() {
        onPreviousMatch?()
    }

    @objc private func didTapNextMatch() {
        onNextMatch?()
    }

    @objc private func didTapScrollToBottom() {
        onScrollToBottomTapped?()
    }
}

extension LatestLogsView: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        onNextMatch?()
        return true
    }
}

extension LatestLogsView: UITextViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        onScrollViewDidScroll?(scrollView)
    }
}
