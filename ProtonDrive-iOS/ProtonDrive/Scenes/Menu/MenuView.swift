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
import PDCore
import ProtonCoreUIFoundations
import PDUIComponents

struct MenuView: View {
    @ObservedObject var vm: MenuViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                userSection

                filesSection

                moreSection
                
                #if HAS_QA_FEATURES
                qaSection
                #endif
                
                spacer
                
                storageSection

                appVersion
            }
            .padding()
        }
        .background(ColorProvider.SidebarBackground.edgesIgnoringSafeArea(.all))
    }

    private var userSection: some View {
        AccountHeaderView(vm: vm.accountHeaderViewModel())
            .frame(maxHeight: 60)
            .background(ColorProvider.SidebarInteractionWeakNorm)
            .cornerRadius(.huge)
    }

    private var filesSection: some View {
        VStack(alignment: .leading) {
            MenuCell(item: .myFiles)
                .background(ColorProvider.SidebarBackground)
                .onTapGesture { vm.go(to: .myFiles) }

            MenuCell(item: .trash)
                .background(ColorProvider.SidebarBackground)
                .onTapGesture { vm.go(to: .trash) }

            ProgressMenuSectionGeneric<OfflineSaver>(progressObserver: vm.downloads)
                .background(ColorProvider.SidebarBackground)
                .onTapGesture { vm.go(to: .offlineAvailable) }
        }
    }

    private var moreSection: some View {
        VStack(alignment: .leading) {
            sectionHeader(title: "More")
            
            #if HAS_PAYMENTS
            
            MenuCell(item: .servicePlans)
                .background(ColorProvider.SidebarBackground)
                .onTapGesture { vm.go(to: .servicePlans) }
            
            #endif
            
            MenuCell(item: .settings)
                .background(ColorProvider.SidebarBackground)
                .onTapGesture { vm.go(to: .settings) }

            MenuCell(item: .feedback)
                .background(ColorProvider.SidebarBackground)
                .onTapGesture { vm.go(to: .feedback) }

            MenuCell(item: .logout)
                .background(ColorProvider.SidebarBackground)
                .onTapGesture { vm.go(to: .logout) }
        }
        
    }
    
    #if HAS_QA_FEATURES
    private var qaSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "QA Section")

            Button("Send event to Sentry") {
                let error = DriveError(NSError(domain: "SENTRY TELEMETRY", code: 420))
                Log.error(error, domain: .application)
            }
            
            Button("Crash") {
                fatalError("Forced crash to check crash reporting")
            }
        }
        .font(.body)
        .foregroundColor(ColorProvider.SidebarTextNorm)
    }
    #endif

    private var spacer: some View {
        Spacer()
            .frame(maxHeight: .infinity)
    }

    private var storageSection: some View {
        VStack(alignment: .leading) {
            sectionHeader(title: "Storage")

            // Online storage
            StorageMenuSection(
                usedPercent: $vm.usagePercent,
                usedBreakdown: $vm.usageBreakdown,
                highStorageUsageRatio: Constants.highStorageUsageRatio,
                isStoreKitReady: Constants.isStoreKitReady
            )
            .onAppear(perform: vm.subscribeToUserInfoChanges)

            #if HAS_PAYMENTS
            storageButton
            #endif
        }
    }

    @ViewBuilder
    private var storageButton: some View {
        if vm.isStorageButtonAvailable {
            GradientButton(title: "Get more storage") {
                vm.go(to: .servicePlans)
            }
            .accessibilityIdentifier("MenuView.storageButton")
        }
    }

    private var appVersion: some View {
        Text(vm.appVersion)
            .font(.subheadline)
            .foregroundColor(ColorProvider.SidebarTextWeak)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 32)
            .accessibilityIdentifier("MenuView.appVersion")
    }

    private func sectionHeader(title: String) -> some View {
        VStack(alignment: .leading) {
            Divider()
                .foregroundColor(ColorProvider.SidebarSeparator)

            Text(title)
                .font(.subheadline)
                .foregroundColor(ColorProvider.SidebarTextWeak)
        }
        .frame(height: 32)
    }
}
