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

import Foundation
import PDCore
import UIKit
import PDClient
import ProtonCoreServices
import SwiftUI
import ProtonCoreUIFoundations
import PDLocalization
import PDCoreIOS

public protocol BugReportFactoryProtocol {
    func makeBugReportViewController() -> UIViewController
}

public final class BugReportFactory: BugReportFactoryProtocol {

    private let apiService: PMAPIService
    private let sessionVault: SessionVault?

    public init(apiService: PMAPIService, sessionVault: SessionVault?) {
        self.apiService = apiService
        self.sessionVault = sessionVault
    }

    public func makeBugReportViewController() -> UIViewController {
        let service = BugReportService(api: apiService)
        let vm = ReportBugViewModel(service: service, sessionVault: sessionVault)
        let vc = ReportBugView(viewModel: vm).embeddedInHostingController()
        vc.title = Localization.report_bug_button
        vc.view.backgroundColor = ColorProvider.BackgroundNorm
        vc.modalPresentationStyle = .overFullScreen

        let nav = ModalNavigationViewController(rootViewController: vc)
        return nav
    }

}
