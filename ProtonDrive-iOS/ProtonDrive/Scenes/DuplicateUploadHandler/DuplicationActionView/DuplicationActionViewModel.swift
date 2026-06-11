// Copyright (c) 2026 Proton AG
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

import PDCore
import SwiftUI
import PDLocalization

struct DuplicationItem: Identifiable {
    var id: String { identifier.id }
    let identifier: AnyVolumeIdentifier
    let filename: String
}

@MainActor
final class DuplicationActionViewModel: ObservableObject {
    @Published var currentItem: DuplicationItem?
    @Published var selectedAction: DuplicateUploadAction = .replace
    @Published var applyToAll: Bool = false

    private var queue: [DuplicationItem] = []

    var onAction: ((AnyVolumeIdentifier, DuplicateUploadAction) -> Void)?
    var onCancelAll: (([AnyVolumeIdentifier]) -> Void)?
    var onDismiss: (() -> Void)?

    let title = Localization.duplication_handler_view_title
    let applyToAllTitle = Localization.duplication_handler_action_apply_all
    let continueTitle = Localization.duplication_handler_action_title_continue
    let cancelTitle = Localization.general_cancel

    var subtitle: String {
        let filename = currentItem?.filename ?? "Unknown"
        return Localization.duplication_handler_view_subtitle(filename: filename)
    }

    init(items: [(AnyVolumeIdentifier, String)]) {
        let duplicationItems = items.map { DuplicationItem(identifier: $0, filename: $1) }
        self.currentItem = duplicationItems.first
        self.queue = duplicationItems.count > 1 ? Array(duplicationItems.dropFirst()) : []
    }

    func addDuplication(_ identifier: AnyVolumeIdentifier, filename: String) {
        let item = DuplicationItem(identifier: identifier, filename: filename)
        if currentItem == nil {
            currentItem = item
        } else {
            queue.append(item)
        }
    }

    func continueAction() {
        guard let current = currentItem else { return }
        onAction?(current.identifier, selectedAction)

        if applyToAll {
            for item in queue {
                onAction?(item.identifier, selectedAction)
            }
            queue.removeAll()
            currentItem = nil
            onDismiss?()
        } else {
            dequeueNext()
        }
    }

    func cancelAllUploads() {
        let identifiers: [AnyVolumeIdentifier] = queue.map { $0.identifier } + [currentItem?.identifier].compactMap { $0 }
        onCancelAll?(identifiers)
        queue.removeAll()
        currentItem = nil
        onDismiss?()
    }

    private func dequeueNext() {
        selectedAction = .replace
        if queue.isEmpty {
            currentItem = nil
            onDismiss?()
        } else {
            currentItem = queue.removeFirst()
        }
    }
}
