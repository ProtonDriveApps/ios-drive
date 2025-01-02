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

import FileProvider

#if os(iOS)
public extension PostLoginServices {

    static func removeFileProvider() async throws {
        do {
            let domains = try await NSFileProviderManager.domains()

            var finalError: DomainOperationErrors?
            await domains.forEach { domain in
                Log.debug("Removing domain \(domain.displayName)", domain: .fileProvider)

                do {
                    try await NSFileProviderManager.remove(domain)

                    Log.info("Removed domain", domain: .fileProvider)
                } catch {
                    let domainError = DomainOperationErrors.removeDomainFailed(error)
                    let errorMessage: String = domainError.errorDescription ?? ""
                    Log.error(errorMessage, domain: .fileProvider)
                    finalError = domainError
                }
            }

            if let finalError {
                throw finalError
            }
        } catch {
            let domainError = DomainOperationErrors.getDomainsFailed(error)
            Log.error(domainError.errorDescription ?? "", domain: .fileProvider)
            throw domainError
        }
    }
}
#endif
