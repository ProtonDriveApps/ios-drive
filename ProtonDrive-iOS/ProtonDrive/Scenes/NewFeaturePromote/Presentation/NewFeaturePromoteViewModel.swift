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

import Combine
import Foundation
import PDLocalization
import PDCore

struct NewFeatureModel {
    let id: String
    let illustration: String
    let title: String
    let description: String
}

struct NewFeatureButton {
    let title: String
    let action: Action

    enum Action {
        case next
        case close
    }
}

protocol NewFeaturePromoteViewModelProtocol: ObservableObject {
    var features: [NewFeatureModel] { get }
    var currentIndex: Int { get set }
    var button: NewFeatureButton { get }
    func didAppear()
    func showNext()
}

final class NewFeaturePromoteViewModel: NewFeaturePromoteViewModelProtocol {
    private let controller: NewFeaturePromoteFlowControllerProtocol
    private var cancellables = Set<AnyCancellable>()

    var features = [NewFeatureModel]()
    @Published var currentIndex = 0
    @Published var button = NewFeatureButton(title: Localization.general_got_it, action: .close)

    init(controller: NewFeaturePromoteFlowControllerProtocol) {
        self.controller = controller
        setupInitialValues()
        subscribeToUpdates()
    }

    func didAppear() {
        controller.markPromoted()
    }

    func showNext() {
        currentIndex += 1
    }

    // MARK: - Private

    private func setupInitialValues() {
        features = makeFeatures()
        updateButton(value: 0)
    }

    private func subscribeToUpdates() {
        _currentIndex.projectedValue.sink { [weak self] newValue in
            self?.updateButton(value: newValue)
        }.store(in: &cancellables)
    }

    private func updateButton(value: Int) {
        if value == features.count - 1 {
            button = NewFeatureButton(title: Localization.general_got_it, action: .close)
        } else {
            button = NewFeatureButton(title: Localization.general_next, action: .next)
        }
    }

    private func makeFeatures() -> [NewFeatureModel] {
        controller.getFeatures()
            .map(makeFeature)
    }

    private func makeFeature(from feature: NewFeature) -> NewFeatureModel {
        NewFeatureModel(
            id: feature.rawValue,
            illustration: makeIllustration(for: feature),
            title: makeTitle(for: feature),
            description: makeDescription(for: feature)
        )
    }

    private func makeIllustration(for feature: NewFeature) -> String {
        switch feature {
        case .doc:
            return "new_feature_docs"
        case .sharing:
            return "new_feature_sharing"
        }
    }

    private func makeTitle(for feature: NewFeature) -> String {
        switch feature {
        case .doc:
            return Localization.new_feature_doc_title
        case .sharing:
            return Localization.new_feature_sharing_title
        }
    }

    private func makeDescription(for feature: NewFeature) -> String {
        switch feature {
        case .doc:
            return Localization.new_feature_doc_desc
        case .sharing:
            return Localization.new_feature_sharing_desc
        }
    }
}
