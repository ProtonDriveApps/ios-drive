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
import ProtonCoreNetworking
import ProtonCoreServices
import PMEventsManager

public typealias UserSettings = PMEventsManager.UserSettings

public final class GeneralSettings {
    @SecureStorage(label: "userSettings") private(set) var userSettings: UserSettings?
    private let network: ProtonCoreServices.APIService
    private let localSettings: LocalSettings
    
    init(mainKeyProvider: MainKeyProvider, network: ProtonCoreServices.APIService, localSettings: LocalSettings) {
        self.network = network
        self.localSettings = localSettings
        self._userSettings.configure(with: mainKeyProvider)
    }

    public var currentUserSettings: UserSettings? {
        userSettings
    }

    func fetchUserSettings() {
        let route = UserSettingsAPIRoutes.Router.getGeneralSettings
        network.exec(route: route) { (task: URLSessionDataTask?, result: Result<GetGeneralSettingsResponse, ResponseError>) in
            switch result {
            case let .success(response):
                self.storeUserSettings(response.userSettings)
            case .failure:
                break
            }
        }
    }
    
    func storeUserSettings(_ userSettings: UserSettings) {
        self.userSettings = userSettings
        
        self.localSettings.optOutFromTelemetry = userSettings.optOutFromTelementry
        self.localSettings.optOutFromCrashReports = userSettings.optOutFromCrashReports
    }

    func cleanUp() {
        try? _userSettings.wipeValue()
    }

}

extension GeneralSettings {
    struct GetGeneralSettingsResponse: Codable {
        let code: Int
        let userSettings: UserSettings
    }
    
    enum UserSettingsAPIRoutes {
        /// base route
        static let route: String = "/core/v4/settings"

        /// default user route version
        static let v_user_default: Int = 4

        enum Router: Request {
            case getGeneralSettings

            var path: String {
                switch self {
                case .getGeneralSettings:
                    return route
                }
            }

            var isAuth: Bool {
                true
            }

            var header: [String: Any] {
                [:]
            }

            var apiVersion: Int {
                v_user_default
            }

            var method: HTTPMethod {
                .get
            }

            var parameters: [String: Any]? {
                switch self {
                case .getGeneralSettings:
                    return [:]
                }
            }
        }
    }
}

extension UserSettings {
    var optOutFromTelementry: Bool {
        telemetry == 0
    }
    
    var optOutFromCrashReports: Bool {
        crashReports == 0
    }
}
