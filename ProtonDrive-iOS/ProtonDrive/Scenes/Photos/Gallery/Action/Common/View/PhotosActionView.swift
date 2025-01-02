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
import PDUIComponents

struct PhotosActionView<ViewModel: PhotosActionViewModelProtocol>: View {
    @ObservedObject private var viewModel: ViewModel

    init(viewModel: ViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        if viewModel.isVisible {
            content
        } else {
            EmptyView()
        }
    }

    private var content: some View {
        ActionBar(onSelection: { model in
            makeAction(from: model).map(viewModel.handle)
        }, items: makeItems())
        .animation(.default, value: viewModel.actions)
        .dialogSheet(item: $viewModel.currentAction, model: viewModel.makeDialogModel())
    }

    private func makeItems() -> [ActionBarButtonViewModel] {
        return viewModel.actions.map(makeItem)
    }

    private func makeItem(from action: PhotosAction) -> ActionBarButtonViewModel {
        switch action {
        case .trash:
            return .trashMultiple
        case .share:
            return .share
        case .newShare:
            return .newShare
        case .shareNative:
            return .shareNative
        case .availableOffline:
            return .offlineAvailableMultiple
        case .info:
            return .info
        }
    }

    private func makeAction(from viewModel: ActionBarButtonViewModel?) -> PhotosAction? {
        switch viewModel {
        case .trashMultiple:
            return .trash
        case .share:
            return .share
        case .shareNative:
            return .shareNative
        case .offlineAvailableMultiple:
            return .availableOffline
        case .newShare:
            return .share
        case .info:
            return .info
        default:
            return nil
        }
    }
}
