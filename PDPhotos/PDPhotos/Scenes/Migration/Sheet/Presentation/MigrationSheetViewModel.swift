// Copyright (c) 2025 Proton AG
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
import PDLocalization
import PDCore

struct MigrationSheetViewData {
    let headline: String
    let title: String
    let subtitle: String
    let startTitle: String
    let remindLaterTitle: String
}

protocol MigrationSheetViewModelProtocol: ObservableObject {
    var data: MigrationSheetViewData { get }
    func start()
    func remindLater()
    func close()
    func willCloseWithoutAction()
}

final class MigrationSheetViewModel: MigrationSheetViewModelProtocol {
    private let migrationController: PhotoVolumeMigrationControllerProtocol
    private let availableController: MigrationSheetAvailableControllerProtocol
    private let coordinator: MigrationSheetCoordinatorProtocol

    lazy var data: MigrationSheetViewData = makeData()

    init(
        migrationController: PhotoVolumeMigrationControllerProtocol,
        availableController: MigrationSheetAvailableControllerProtocol,
        coordinator: MigrationSheetCoordinatorProtocol
    ) {
        self.migrationController = migrationController
        self.availableController = availableController
        self.coordinator = coordinator
    }

    func start() {
        Log.info("[Migration] Start", domain: .userAction)
        migrationController.startMigration()
    }

    func remindLater() {
        Log.info("[Migration] Remind me later", domain: .userAction)
        availableController.markShown()
    }

    func close() {
        coordinator.close()
    }

    func willCloseWithoutAction() {
        Log.info("[Migration] Close without action", domain: .userAction)
        availableController.markShown()
    }

    private func makeData() -> MigrationSheetViewData {
        MigrationSheetViewData(
            headline: Localization.photo_migration_headline,
            title: Localization.photo_migration_title,
            subtitle: Localization.photo_migration_subtitle,
            startTitle: Localization.generic_start,
            remindLaterTitle: Localization.generic_remind_me_later
        )
    }
}
