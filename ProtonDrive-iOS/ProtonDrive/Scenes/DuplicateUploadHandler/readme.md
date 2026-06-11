# Duplicate upload handler

When the SDK detects that an upload would collide with an existing file in the same location, it publishes that event.       
This scene listens for those events and presents a sheet so the user can choose what to do.

## Structure

| Path | Role |
|------|------|
| `DuplicateUploadHandler.swift` | Coordinator: subscribes to `SDKFileUploader.duplicated` after bootstrap, presents or reuses the sheet, forwards user choices to the uploader (replace / keep both / skip) or cancels uploads. |
| `DuplicationActionView/` | SwiftUI sheet UI and state for one duplicate at a time, with an internal queue for more. |

- **`DuplicationActionView`** — `SheetContainer` with header, radio rows for each `DuplicateUploadAction`, optional “Apply to all duplicated files”, Continue, and Cancel all uploads.
- **`DuplicationActionViewModel`** — Holds the current `DuplicationItem` and a queue; `addDuplication` appends while a sheet is already shown; `continueAction` applies the selected action (and optionally the same action to the whole queue), then advances or dismisses.

The enum **`DuplicateUploadAction`** (replace, keep both, skip) lives in **PDCore** (`DuplicateUploadAction.swift`); the handler calls `upload(..., duplicateAction:)` or `deleteUploadingFile` on the SDK uploader accordingly.

`DuplicateUploadHandler` is wired from the dependency container (`DC+Populate.swift`) and is constructed with `BootstrapStateController` and `Tower` to reach the file uploader.
