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
import ProtonCoreUIFoundations

#if os(iOS)
public struct ProgressMenuSectionGeneric<ProgressProviderType>: View where ProgressProviderType: NSObject, ProgressProviderType: ProgressFractionCompletedProvider {
    
    public init(progressObserver: ProgressMenuSectionViewModelGeneric<ProgressProviderType>) {
        self.progressObserver = progressObserver
    }
    
    @Environment(\.menuTitleOffset) var titleOffset: CGFloat
    @Environment(\.menuIconSize) var iconSize: CGFloat
    @State var progressCompleted: Double = 0
    @State var showSpinner: Bool = false
    @State var showAnimation: Bool = false
    @ObservedObject var progressObserver: ProgressMenuSectionViewModelGeneric<ProgressProviderType>

    public var body: some View {
        VStack(alignment: .leading) {
            // The Rectangle is for padding between this and `MenuCell`
            Rectangle()
                .frame(height: 3)
                .foregroundStyle(Color.clear)
            HStack {
                ZStack {
                    Image(self.progressObserver.iconName)
                        .resizable()
                        .frame(width: self.iconSize, height: self.iconSize)
                        .padding(.vertical, 4)
                        .foregroundColor(ColorProvider.SidebarIconWeak)

                    ProtonDone(borderThickness: 1.0)
                        .frame(width: self.iconSize - 6, height: self.iconSize - 6)
                        .opacity(showAnimation ? 1 : 0)
                        .animation(Animation.easeIn(duration: 0.5))
                        .opacity(showAnimation ? 0 : 1)
                        .animation(Animation.easeOut(duration: 0.5).delay(2.0))
                        .onReceive(self.progressObserver.$state) { state in
                            self.showAnimation = (state == .finished)
                        }

                    ProtonSpinner(size: .custom(Double(self.iconSize) - 6), style: .inverted)
                        .frame(width: self.iconSize, height: self.iconSize)
                        .background(ColorProvider.SidebarBackground)
                        .opacity(showSpinner ? 1 : 0)
                        .animation(Animation.linear(duration: 0.5))
                        .onReceive(self.progressObserver.$state) { state in
                            self.showSpinner = (state == .inProgress)
                        }
                }
                
                Text(progressObserver.title)
                    .font(.body)
                    .foregroundColor(ColorProvider.SidebarTextNorm)
                
                Spacer()
                
                Text(percentString)
                    .font(.footnote)
                    .foregroundColor(ColorProvider.SidebarIconWeak)
                    .opacity(progressObserver.state == .inProgress ? 1.0 : 0.0)
            }
            
            Wrap(self.progressObserver.makeProgressBar(), updater: {
                switch self.progressObserver.state {
                case .initial, .finished:
                    $0.progressTintColor = UIColor.clear
                    $0.trackTintColor = UIColor.clear
                case .inProgress:
                    $0.progressTintColor = ColorProvider.BrandNorm
                    $0.trackTintColor = ColorProvider.SeparatorNorm
                }
            })
                .frame(maxWidth: .infinity)
                .scaleEffect(.init(width: 1, height: 0.3)) // same height as Divider()
        }
    }
    
    private var percentString: String {
        let percentFormatter = ProgressMenuSectionGenericFormatter.percentFormatter
        return percentFormatter.string(from: progressObserver.progressCompleted as NSNumber) ?? ""
    }
}

/// Static variables are not supported in generic types (ProgressMenuSectionGeneric), so it needs to be wrapped in standalone declaration.
private struct ProgressMenuSectionGenericFormatter {
    static let percentFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.multiplier = 100
        formatter.maximumFractionDigits = 0
        return formatter
    }()
}

struct ProcessMenuSection_Previews: PreviewProvider {
    static var progress: Progress = {
        let progress = Progress()
        progress.totalUnitCount = 100
        progress.completedUnitCount = 42
        return progress
    }()
    
    static var previews: some View {
        ProgressMenuSectionGeneric(progressObserver: .init(progressProvider: self.progress,
                                                           steadyTitle: "Offline available",
                                                           inProgressTitle: "Downloading files...",
                                                           iconName: "ic-availableoffline"))
    }
}
#endif
