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

import PDCore
import SwiftUI
import UIKit

struct LocalNotificationsFactory {
    func makeNotificationsController() -> LocalNotificationsController {
        let applicationRunningResource = ApplicationRunningStateResourceImpl()
        let notificationsResource = UNUserNotificationsResource()
        let notifier = UploadFileLocalNotificationNotifier(
            didFindIssueOnFileUploadPublisher: NotificationCenter.default.mappedPublisher(for: .didFindIssueOnFileUpload),
            didChangeAppRunningStatePublisher: applicationRunningResource.state,
            notificationsResource: notificationsResource
        )
        return LocalNotificationsController(notificationsResource, notifier)
    }
    
    func makeFlowController() -> NotificationsPermissionsFlowController {
        NotificationsPermissionsFlowControllerImpl()
    }
    
    func makePermissionsController(tower: Tower, flowController: NotificationsPermissionsFlowController) -> NotificationsPermissionsController {
        return NotificationsPermissionsControllerImpl(
            flowController: flowController,
            resource: UNUserNotificationsResource(),
            uploadInteractor: UploadOperationInteractor(interactor: tower.fileUploader),
            localSettings: tower.localSettings
        )
    }
    
    func makePermissionsCoordinator(controller: NotificationsPermissionsController, flowController: NotificationsPermissionsFlowController) -> NotificationsPermissionsCoordinator {
        return NotificationsPermissionsCoordinator(controller: flowController) {
            makePermissionsView(controller: controller, flowController: flowController)
        }
    }
    
    private func makePermissionsView(controller: NotificationsPermissionsController, flowController: NotificationsPermissionsFlowController) -> UIViewController {
        let viewModel = NotificationsPermissionsViewModelImpl(controller: controller, flowController: flowController)
        let view = NotificationsPermissionsView(viewModel: viewModel)
        return NotificationsPermissionsHostingViewController(viewModel: viewModel, rootView: view)
    }
}
