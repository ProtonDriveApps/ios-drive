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

import Combine
import Foundation
import PDCore

public final class PhotoLeftoversCleaner {
    private let isEnabledPublisher: AnyPublisher<Bool, Never>
    private let scheduler: AnySchedulerOf<DispatchQueue>
    private let cleanPhotoLeftOvers: Command
    private var cancellables = Set<AnyCancellable>()
    
    private var _isEnabledMirror: Bool = true

    public init(isEnabledPublisher: AnyPublisher<Bool, Never>, scheduler: AnySchedulerOf<DispatchQueue>, cleanPhotoLeftOvers: Command) {
        self.isEnabledPublisher = isEnabledPublisher
        self.scheduler = scheduler
        self.cleanPhotoLeftOvers = cleanPhotoLeftOvers
        
        isEnabledPublisher
            .sink { [weak self] isEnabled in self?._isEnabledMirror = isEnabled }
            .store(in: &cancellables)

        isEnabledPublisher
            .removeDuplicates()
            .filter { !$0 }
            .debounce(for: .seconds(10), scheduler: scheduler)
            .compactMap { [weak self] _ in return self?._isEnabledMirror }
            .filter { !$0 }
            .sink { [weak self] _ in self?.cleanPhotoLeftOvers.execute() }
            .store(in: &cancellables)
    }
}

extension Publisher {
    func mapToVoid() -> Publishers.Map<Self, Void> {
        return self.map { _ in () }
    }

    func mapAndErase<OutputType>(_ transform: @escaping (Output) -> OutputType) -> AnyPublisher<OutputType, Failure> {
        self.map(transform)
            .eraseToAnyPublisher()
    }
}
