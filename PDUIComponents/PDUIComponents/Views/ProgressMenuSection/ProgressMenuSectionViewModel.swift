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
import Combine
import ProtonCoreUIFoundations

#if canImport(UIKit)
import UIKit
#endif

#if os(iOS)
public class ProgressMenuSectionViewModelGeneric<ProgressProviderType>: ObservableObject where ProgressProviderType: NSObject, ProgressProviderType: ProgressFractionCompletedProvider {
   
    enum State {
        case initial, inProgress, finished
    }
    
    @Published var state: State = .initial
    @Published var progressCompleted: Double = 0
    @Published var title: String
    let iconName: String
    
    private var progressCancellable: AnyCancellable!
    private var progressProvider: ProgressProviderType
    private lazy var progress: Progress = .init(totalUnitCount: 100)
    private let steadyTitle: String
    private let inProgressTitle: String
    private let threshold = 0.01 // update Published stuff only when Progress increment exceeds this value
    
    public init(progressProvider: ProgressProviderType, steadyTitle: String, inProgressTitle: String, iconName: String) {
        self.progressProvider = progressProvider
        self.title = steadyTitle
        self.steadyTitle = steadyTitle
        self.inProgressTitle = inProgressTitle
        self.iconName = iconName
    }
    
    func makeProgressBar() -> UIProgressView {
        let progressView = UIProgressView(progressViewStyle: .bar)
        progressView.observedProgress = self.progress
        progressView.progressTintColor = ColorProvider.BrandNorm
        progressView.trackTintColor = .clear
        
        self.progressCancellable = self.progressProvider.publisher(for: \.fractionCompleted)
        .receive(on: DispatchQueue.main)
        .filter { [unowned self] in
            abs(self.progressCompleted - $0) >= self.threshold
        }.sink { [unowned self] completed in
            self.progress.completedUnitCount = Int64(completed * 100)
            self.progressCompleted = completed
            self.state = (self.threshold ..< 1.0 - self.threshold).contains(completed) ? .inProgress : .finished
            self.title = self.state == .inProgress ? self.inProgressTitle : self.steadyTitle
        }
        
        return progressView
    }
}

@objc public protocol ProgressFractionCompletedProvider: AnyObject {
    @objc dynamic var fractionCompleted: Double { get }
}

extension Progress: ProgressFractionCompletedProvider {}
#endif
