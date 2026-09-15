// Copyright (c) 2026 Proton AG
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

import PDCore
import PDCoreIOS
import PDLocalization
import PDSDKCore
import PDUIComponents
import ProtonCoreUIFoundations
import SwiftUI
import UIKit

struct IIncomingFilesReviewView: View {
    @ObservedObject var viewModel: IIncomingFilesReviewViewModel
    let onCancel: () -> Void
    let onUploadFinished: () -> Void

    init(
        viewModel: IIncomingFilesReviewViewModel,
        onCancel: @escaping () -> Void,
        onUploadFinished: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.onCancel = onCancel
        self.onUploadFinished = onUploadFinished
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            fileList
            destinationRow
        }
        .background(ColorProvider.BackgroundNorm.edgesIgnoringSafeArea(.all))
        .contentShape(Rectangle())
        .onTapGesture {
            _ = viewModel.commitEditingIfNeeded()
        }
        .onAppear {
            viewModel.onAppear()
        }
    }

    private var header: some View {
        HStack {
            Button(Localization.general_cancel) {
                viewModel.cancel()
                onCancel()
            }
            .foregroundStyle(ColorProvider.BrandNorm)
            .disabled(viewModel.isUploading)
            .accessibilityIdentifier("IncomingReview.button.cancel")

            Spacer()

            Button(Localization.general_upload) {
                viewModel.save(onDismiss: onUploadFinished)
            }
            .foregroundStyle(ColorProvider.BrandNorm)
            .fontWeight(.semibold)
            .disabled(!viewModel.canSave)
            .accessibilityIdentifier("IncomingReview.button.upload")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var fileList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.listedFiles) { listedFile in
                    row(for: listedFile)
                    Divider()
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
    }

    @ViewBuilder
    private func row(for listedFile: ListedIncomingFile) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Group {
                if let thumbnailData = viewModel.thumbnail(for: listedFile),
                   let uiImage = UIImage(data: thumbnailData) {
                    Image(uiImage: uiImage)
                        .resizable()
                } else {
                    FileAssetImageProvider.icon(for: listedFile.icon)
                        .resizable()
                }
            }
            .scaledToFill()
            .frame(width: 40, height: 40)
            .clipped()
            .fixedSize()
            .layoutPriority(1)
            .onAppear {
                viewModel.requestThumbnail(for: listedFile)
            }

            VStack(alignment: .leading, spacing: 2) {
                if viewModel.editingFileID == listedFile.id {
                    IISelectableTextField(
                        text: $viewModel.editingName,
                        selectAllToken: viewModel.selectAllToken,
                        onSubmit: {
                            _ = viewModel.commitEditingIfNeeded()
                        }
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .clipped()
                } else {
                    Text(listedFile.name)
                        .foregroundColor(ColorProvider.TextNorm)
                        .frame(height: 36)
                        .lineLimit(1)
                }

                Text(ByteCountFormatter.storageSizeString(forByteCount: listedFile.size))
                    .font(.footnote)
                    .foregroundColor(ColorProvider.TextWeak)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(0)
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.beginEditing(listedFile)
        }
        .accessibilityIdentifier("IncomingReview.fileList.row.\(listedFile.name)")
    }

    private var destinationRow: some View {
        VStack(spacing: 0) {
            Divider()
            Button {
                viewModel.requestPickDestination()
            } label: {
                HStack(alignment: .center, spacing: 10) {
                    FileAssetImageProvider.icon(for: .folder)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                        .foregroundColor(ColorProvider.IconNorm)
                    Text(Localization.share_action_save_to)
                        .font(.system(size: 14))
                        .foregroundColor(ColorProvider.TextNorm)
                    Spacer()

                    Text(viewModel.currentDestinationName)
                        .font(.system(size: 14))
                        .foregroundColor(ColorProvider.TextWeak)
                        .lineLimit(1)
                        .accessibilityIdentifier("IncomingReview.text.currentDestination.name.\(viewModel.currentDestinationName)")
                    IconProvider.chevronRight
                        .font(.system(size: 14))
                        .foregroundColor(ColorProvider.IconWeak)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .disabled(viewModel.isUploading)
            .accessibilityIdentifier("IncomingReview.destinationRow")
        }
    }
}

private struct IISelectableTextField: UIViewRepresentable {
    @Binding var text: String
    let selectAllToken: Int
    let onSubmit: () -> Void

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.borderStyle = .none
        textField.returnKeyType = .done
        textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        textField.clipsToBounds = true
        textField.delegate = context.coordinator
        textField.addTarget(context.coordinator, action: #selector(Coordinator.textChanged(_:)), for: .editingChanged)
        return textField
    }

    func updateUIView(_ textField: UITextField, context: Context) {
        if textField.text != text {
            textField.text = text
        }

        if context.coordinator.lastSelectAllToken != selectAllToken {
            context.coordinator.lastSelectAllToken = selectAllToken
            DispatchQueue.main.async {
                textField.becomeFirstResponder()
                let text = textField.text ?? ""
                let selectedLength = context.coordinator.filenameSelectionLength(in: text)
                if let endPosition = textField.position(from: textField.beginningOfDocument, offset: selectedLength) {
                    textField.selectedTextRange = textField.textRange(from: textField.beginningOfDocument, to: endPosition)
                } else {
                    textField.selectedTextRange = textField.textRange(from: textField.beginningOfDocument, to: textField.endOfDocument)
                }
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onSubmit: onSubmit)
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        @Binding var text: String
        let onSubmit: () -> Void
        var lastSelectAllToken = -1

        init(text: Binding<String>, onSubmit: @escaping () -> Void) {
            self._text = text
            self.onSubmit = onSubmit
        }

        @objc func textChanged(_ textField: UITextField) {
            text = textField.text ?? ""
        }

        func filenameSelectionLength(in text: String) -> Int {
            let utf16Length = text.fileName.utf16.count
            return utf16Length > 0 ? utf16Length : text.utf16.count
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            onSubmit()
            return true
        }
    }
}
