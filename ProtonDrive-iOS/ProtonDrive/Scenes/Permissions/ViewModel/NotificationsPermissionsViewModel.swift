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

import Foundation
import PDLocalization

protocol NotificationsPermissionsViewModel {
    var data: NotificationsPermissionsViewData { get }
    func enable()
    func close()
}

struct NotificationsPermissionsViewData {
    let isNavigationVisible: Bool
    let title: String
    let description: String
    let enableButton: String
    let closeButton: String
}

final class NotificationsPermissionsViewModelImpl: NotificationsPermissionsViewModel {
    private let type: NotificationsPermissionsType
    private let controller: NotificationsPermissionsController
    private let flowController: NotificationsPermissionsFlowController

    lazy var data = makeViewData()
    
    init(type: NotificationsPermissionsType, controller: NotificationsPermissionsController, flowController: NotificationsPermissionsFlowController) {
        self.type = type
        self.controller = controller
        self.flowController = flowController
    }
    
    func enable() {
        controller.requestPermissions()
    }

    func close() {
        controller.skip()
        flowController.event.send(.close)
    }

    private func makeViewData() -> NotificationsPermissionsViewData {
        switch type {
        case .myFiles:
            return NotificationsPermissionsViewData(
                isNavigationVisible: true,
                title: Localization.notification_permission_files_title,
                description: Localization.notification_permission_files_description,
                enableButton: Localization.notification_permission_enable_button_title,
                closeButton: Localization.general_not_now
            )
        case .photos:
            return NotificationsPermissionsViewData(
                isNavigationVisible: false,
                title: Localization.notification_permission_photos_title,
                description: Localization.notification_permission_photos_description,
                enableButton: Localization.notification_permission_enable_button_title,
                closeButton: Localization.general_not_now
            )
        }
    }
}
