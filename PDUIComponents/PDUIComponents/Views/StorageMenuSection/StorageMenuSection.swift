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
import PDLocalization

public struct StorageMenuSection: View {
    public init(usedPercent: Binding<Double>, usedBreakdown: Binding<String>, highStorageUsageRatio: Double, isStoreKitReady: Bool) {
        self._usedPercent = usedPercent
        self._usedBreakdown = usedBreakdown
        self.highStorageUsageRatio = highStorageUsageRatio
        self.isStoreKitReady = isStoreKitReady
    }
    
    @Environment(\.menuTitleOffset) var titleOffset: CGFloat
    @Environment(\.menuIconSize) var iconSize: CGFloat
    @Binding var usedPercent: Double
    @Binding var usedBreakdown: String
    
    let highStorageUsageRatio: Double
    let isStoreKitReady: Bool
    
    private var isShortOnStorage: Bool {
        usedPercent > highStorageUsageRatio
    }
    
    public var body: some View {
        VStack(alignment: .leading) {
            HStack(alignment: .center) {
                IconProvider.cloud
                    .resizable()
                    .frame(width: iconSize, height: iconSize)
                    .foregroundColor(Color.IconWeak)
                
                Text(Localization.menu_text_total_usage)
                    .font(.body)
                
                Spacer()
                
                Text(usageString)
                    .font(.body)
            }
            .foregroundColor(.white)
            
            ProgressBar(
                value: $usedPercent,
                foregroundColor: isShortOnStorage ? Color.NotificationError : ColorProvider.InteractionNorm,
                backgroundColor: Color.SidebarSeparator
            )
                .frame(height: 8)
            
            Text(usedBreakdown)
                .font(.body)
                .foregroundColor(Color.SidebarTextNorm)
                .accessibilityIdentifier("StorageMenuSection.usedBreakdown")
        }
    }
    
    private var usageString: String {
        let formatter = StorageMenuSection.formatter
        return formatter.string(from: NSNumber(value: usedPercent)) ?? "?"
    }

    private static let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        return formatter
    }()
}

struct StorageMenuSection_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            StorageMenuSection(usedPercent: .constant(0.7), usedBreakdown: .constant("1.4 Gb of 3 Gb"), highStorageUsageRatio: 0.8, isStoreKitReady: false)
            
            StorageMenuSection(usedPercent: .constant(0.99), usedBreakdown: .constant("2.9 Gb of 3 Gb"), highStorageUsageRatio: 0.8, isStoreKitReady: true)
        }
        .previewLayout(.sizeThatFits)
    }
}
