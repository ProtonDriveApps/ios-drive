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
import SwiftUI
import UIKit
import PDCore

struct BugDocumentPicker: UIViewControllerRepresentable {
    @Environment(\.presentationMode) var presentationMode
    let onPick: ([URL]) -> Void

    init(onPick: @escaping ([URL]) -> Void) {
        self.onPick = onPick
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var parent: BugDocumentPicker

        init(parent: BugDocumentPicker) {
            self.parent = parent
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            do {
                let destinationDirectory = PDFileManager.bugReportAttachmentsDirectory
                let fileManager = FileManager.default
                for url in urls {
                    let destinationURL = destinationDirectory.appendingPathComponent(url.lastPathComponent)
                    try? fileManager.removeItem(atPath: destinationURL.path)
                    try fileManager.moveItem(at: url, to: destinationURL)
                    parent.onPick([destinationURL])  // or pass an array
                }
            } catch {
                Log.error("Failed to import bug report attachment:", error: error, domain: .logs)
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item], asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = true
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
}
