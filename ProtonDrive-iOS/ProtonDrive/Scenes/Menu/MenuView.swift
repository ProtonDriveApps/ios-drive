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
import PDCoreIOS
import ProtonCoreUIFoundations
import PDUIComponents
import PDLocalization

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

                #if HAS_QA_FEATURES
                if !vm.sdkFlags.isEmpty {
                    makeFlagsSection(from: vm.sdkFlags)
                }
                #endif
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
            MenuCell(item: .home)
                .background(ColorProvider.SidebarBackground)
                .onTapGesture { vm.go(to: .myFiles) }

            if vm.hasSharing {
                MenuCell(item: .sharedByMe)
                    .background(ColorProvider.SidebarBackground)
                    .onTapGesture { vm.go(to: .sharedByMe) }
            }

            MenuCell(item: .trash)
                .background(ColorProvider.SidebarBackground)
                .onTapGesture { vm.go(to: .trash) }

            ProgressMenuSectionGeneric(progressObserver: vm.downloads)
                .background(ColorProvider.SidebarBackground)
                .onTapGesture { vm.go(to: .offlineAvailable) }
        }
    }

    private var moreSection: some View {
        VStack(alignment: .leading) {
            sectionHeader(title: Localization.menu_section_title_more)

            if Constants.buildFeatures.hasPayments {
                MenuCell(item: .servicePlans)
                    .background(ColorProvider.SidebarBackground)
                    .onTapGesture { vm.go(to: .servicePlans) }
            }

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
                Log.error(error: error, domain: .application)
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
            sectionHeader(title: Localization.menu_section_title_storage)

            if vm.hasStoragePromoButton {
                MenuCell(item: .storageBonusPromo)
                    .menuCellHighlighted(true)
                    .menuCellHasFadeAnimation(true)
                    .background(ColorProvider.SidebarBackground)
                    .onTapGesture { vm.go(to: .storageBonusPromo) }
                    .padding(.vertical, 3)
            }

            // Online storage
            StorageMenuSection(
                usedPercent: $vm.usagePercent,
                usedBreakdown: $vm.usageBreakdown,
                highStorageUsageRatio: Constants.highStorageUsageRatio,
                isStoreKitReady: Constants.isStoreKitReady
            )
            .onAppear(perform: vm.subscribeToUserInfoChanges)

            if Constants.buildFeatures.hasPayments {
                storageButton
            }
        }
    }

    @ViewBuilder
    private var storageButton: some View {
        if vm.isStorageButtonAvailable {
            GradientButton(title: Localization.general_get_more_storage) {
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
            .onMultiTap(requiredTaps: 5, within: 3) {
                vm.toggleDebugMode()
            }
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

    private func makeFlagsSection(from flags: SDKMenuFlags) -> some View {
        Text(makeTexts(from: flags))
            .font(.subheadline)
            .foregroundColor(ColorProvider.SidebarTextWeak)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 32)
    }

    private func makeTexts(from flags: SDKMenuFlags) -> String {
        let usedFlags = makeString(from: flags)
        let usingText = "Using SDK for:\n\(usedFlags)"
        let unusedFlags = makeString(from: Set(SDKMenuFlag.allCases).subtracting(flags))
        let notUsingText = "Not using SDK for:\n\(unusedFlags)"
        return "\(usingText)\n\n\(notUsingText)"
    }

    private func makeString(from flags: Set<SDKMenuFlag>) -> String {
        return flags
            .map { "- " + makeString(from: $0) }
            .sorted(by: { $0 < $1 })
            .joined(separator: "\n")
    }

    private func makeString(from flag: SDKMenuFlag) -> String {
        switch flag {
        case .isUsingSDKMainVolumeUpload:
            "Main volume upload"
        case .isUsingSDKMainVolumeThumbnails:
            "Main volume thumbnails"
        case .isUsingSDKMainVolumeDownload:
            "Main volume download"
        case .isUsingSDKPhotoVolumeUpload:
            "Photo volume upload"
        case .isUsingSDKPhotoVolumeDownload:
            "Photo volume download (stream & album)"
        case .isUsingSDKPhotoVolumeThumbnails:
            "Photo volume thumbnails (stream & album)"
        case .isUsingSDKNodeOperations:
            "Node operations"
        }
    }
}
