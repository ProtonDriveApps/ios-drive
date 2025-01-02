// Copyright (c) 2024 Proton AG
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

public class Localization {
    private static let defaultLanguage = "en"
    private static let availableLanguages = [defaultLanguage]
    private static let preferredLanguages: [String] = {
        let current = Locale.current
        let region = current.regionCode ?? ""
        let preferredLanguages = Locale.preferredLanguages.map { fullLanguage in
            guard fullLanguage.contains(region) else { return fullLanguage }
            // e.g. en-TW, zh-Hant-TW
            var components = fullLanguage.split(separator: "-")
            components.removeLast()
            let lang = components.joined(separator: "-")
            return lang
        }
        
        return preferredLanguages
    }()
    
    private static let bundle: Bundle = {
        let main: Bundle = .module
        for language in preferredLanguages {
            guard
                availableLanguages.contains(language),
                let path = main.path(forResource: language, ofType: "lproj"),
                let bundle = Bundle(path: path)
            else { continue }
            return bundle
        }
        return enBundle
    }()
    
    private static let enBundle: Bundle = {
        let main: Bundle = .module
        guard
            let path = main.path(forResource: defaultLanguage, ofType: "lproj"),
            let bundle = Bundle(path: path)
        else { return main }
        return bundle
    }()
    
    static func localized(key: String) -> String {
        let str = String(localized: .init(key), bundle: bundle)
        if str == key {
            return String(localized: .init(key), bundle: enBundle)
        } else {
            return str
        }
    }
    /// "Alert title"
    /// "Account Deletion Error"
    public static var account_deletion_alert_title: String { localized(key: "account_deletion_alert_title") }

    /// "Alert message shown when user trying to trash files"
    /// "Are you sure you want to move this file to Trash?"
    public static func action_trash_files_alert_message(num: Int) -> String { String(format: localized(key: "action_trash_files_alert_message"), num) }

    /// "Alert message shown when user trying to trash folders"
    /// "Are you sure you want to move this folder to Trash?"
    public static func action_trash_folders_alert_message(num: Int) -> String { String(format: localized(key: "action_trash_folders_alert_message"), num) }

    /// "Alert message shown when user trying to trash items"
    /// "Are you sure you want to move this item to Trash?"
    public static func action_trash_items_alert_message(num: Int) -> String { String(format: localized(key: "action_trash_items_alert_message"), num) }

    /// "Text shown on the welcome page when user is not logged in "
    /// "The convenience of cloud storage and the security of encryption technology. Finally a cloud storage solution you can trust."
    public static var authentication_welcome_text: String { localized(key: "authentication_welcome_text") }

    /// "Text to indicate downloading"
    /// "Downloading files..."
    public static var available_offline_downloading_files: String { localized(key: "available_offline_downloading_files") }

    /// "Message of the available offline page when no items are available"
    /// "Tap “Make available offline” in a file’s or folder’s menu to access it without internet connection."
    public static var available_offline_empty_message: String { localized(key: "available_offline_empty_message") }

    /// "Title of the available offline page when no items are available"
    /// "No offline files or folders"
    public static var available_offline_empty_title: String { localized(key: "available_offline_empty_title") }

    /// "Title of available offline page"
    /// "Available offline"
    public static var available_offline_title: String { localized(key: "available_offline_title") }

    /// "Alert message displayed when required permissions are missing."
    /// "Change app permissions in Settings"
    public static var camera_permission_alert_message: String { localized(key: "camera_permission_alert_message") }

    /// "Alert title displayed when required permission is missing"
    /// "“ProtonDrive” Would Like to Access the Camera"
    public static var camera_permission_alert_title: String { localized(key: "camera_permission_alert_title") }

    /// "Error message"
    /// "Unable to fetch contacts. Please check your network connection and try again."
    public static var contact_error_unable_to_fetch: String { localized(key: "contact_error_unable_to_fetch") }

    /// "Button for creating new document"
    /// "Create document"
    public static var create_document_button: String { localized(key: "create_document_button") }

    /// "Generic document creation error alert"
    /// "Failed to create new document. Please try again later."
    public static var create_document_error: String { localized(key: "create_document_error") }

    /// "Placeholder of document name"
    /// "Document name"
    public static var create_document_placeholder: String { localized(key: "create_document_placeholder") }

    /// "View title"
    /// "Create document"
    public static var create_document_title: String { localized(key: "create_document_title") }

    /// "Placeholder of folder name"
    /// "Folder name"
    public static var create_folder_placeholder: String { localized(key: "create_folder_placeholder") }

    /// "View title"
    /// "Create folder"
    public static var create_folder_title: String { localized(key: "create_folder_title") }

    /// "Creating new document loading state"
    /// "Creating new document"
    public static var creating_new_document: String { localized(key: "creating_new_document") }

    /// "Title of setting action sheet"
    /// "Choose the screen opens by default"
    public static var default_home_tab_setting_sheet_title: String { localized(key: "default_home_tab_setting_sheet_title") }

    /// "View title"
    /// "Default home tab"
    public static var default_home_tab_title: String { localized(key: "default_home_tab_title") }

    /// "Message shown in the folder view when device is disconnected"
    /// "We cannot read contents of this folder"
    public static var disconnection_folder_message: String { localized(key: "disconnection_folder_message") }

    /// "Title shown in the view when device is disconnected"
    /// "Your device has no connection"
    public static var disconnection_view_title: String { localized(key: "disconnection_view_title") }

    /// "Placeholder of date picker"
    /// "Date"
    public static var edit_link_placeholder_date_picker: String { localized(key: "edit_link_placeholder_date_picker") }

    /// "Placeholder of password configuration"
    /// "Set password"
    public static var edit_link_placeholder_password: String { localized(key: "edit_link_placeholder_password") }

    /// "Section title"
    /// "Privacy settings"
    public static var edit_link_section_title: String { localized(key: "edit_link_section_title") }

    /// "Banner text shown after saving change"
    /// "Link settings updated"
    public static var edit_link_settings_updated: String { localized(key: "edit_link_settings_updated") }

    /// "Expiration Date configuration"
    /// "Set expiration date"
    public static var edit_link_title_expiration_date: String { localized(key: "edit_link_title_expiration_date") }

    /// "Password configuration"
    /// "Require password"
    public static var edit_link_title_password: String { localized(key: "edit_link_title_password") }

    /// "Rename file"
    public static var edit_node_title_rename_file: String { localized(key: "edit_node_title_rename_file") }

    /// "Rename folder"
    public static var edit_node_title_rename_folder: String { localized(key: "edit_node_title_rename_folder") }

    /// "Button to mark as available offline"
    /// "Make available offline"
    public static var edit_section_make_available_offline: String { localized(key: "edit_section_make_available_offline") }

    /// "Button to move an item"
    /// "Move to..."
    public static var edit_section_move_to: String { localized(key: "edit_section_move_to") }

    /// "Button to open document in browser"
    /// "Open in browser"
    public static var edit_section_open_in_browser: String { localized(key: "edit_section_open_in_browser") }

    /// "Button to move item to trash"
    /// "Move to trash"
    public static var edit_section_remove: String { localized(key: "edit_section_remove") }

    /// "Button to remove from available offline"
    /// "Remove from available offline"
    public static var edit_section_remove_from_available_offline: String { localized(key: "edit_section_remove_from_available_offline") }

    /// "Button to remove me from shared file or folder"
    /// "Remove me"
    public static var edit_section_remove_me: String { localized(key: "edit_section_remove_me") }

    /// "Button to open share via link"
    /// "Share via link"
    public static var edit_section_share_via_link: String { localized(key: "edit_section_share_via_link") }

    /// "Button to open sharing options"
    /// "Sharing options"
    public static var edit_section_sharing_options: String { localized(key: "edit_section_sharing_options") }

    /// "Show file details button"
    /// "Show file details"
    public static var edit_section_show_file_details: String { localized(key: "edit_section_show_file_details") }

    /// "Button to show folder details"
    /// "Show folder details"
    public static var edit_section_show_folder_details: String { localized(key: "edit_section_show_folder_details") }

    /// "Message shown in the empty folder view"
    /// "Tap the + button to upload files or create something new"
    public static var empty_folder_message: String { localized(key: "empty_folder_message") }

    /// "Title shown in the empty folder view"
    /// "Folder is empty"
    public static var empty_folder_title: String { localized(key: "empty_folder_title") }

    /// "Text displayed on the file detail view to indicate the file extension"
    /// "Extension"
    public static var file_detail_extension: String { localized(key: "file_detail_extension") }

    /// "View title displayed on the file detail view when we can\'t recognize file type"
    /// "Details"
    public static var file_detail_general_title: String { localized(key: "file_detail_general_title") }

    /// "Text displayed on the file detail view to indicate the file path"
    /// "Location"
    public static var file_detail_location: String { localized(key: "file_detail_location") }

    /// "Text displayed on the file detail view to indicate the file modificated date"
    /// "Modified"
    public static var file_detail_modified: String { localized(key: "file_detail_modified") }

    /// "Text displayed on the file detail view to indicate the file name"
    /// "Name"
    public static var file_detail_name: String { localized(key: "file_detail_name") }

    /// "Text displayed on the file detail view to indicate the file is not sharing"
    /// "No"
    public static var file_detail_share_no: String { localized(key: "file_detail_share_no") }

    /// "Text displayed on the file detail view to indicate the file is sharing"
    /// "Yes"
    public static var file_detail_share_yes: String { localized(key: "file_detail_share_yes") }

    /// "Text displayed on the file detail view to indicate the file share status"
    /// "Shared"
    public static var file_detail_shared: String { localized(key: "file_detail_shared") }

    /// "Text displayed on the file detail view to indicate the file size"
    /// "Size"
    public static var file_detail_size: String { localized(key: "file_detail_size") }

    /// "Subtitle for file to represent file size and last modified date"
    /// "%@ | Moments ago"
    public static func file_detail_subtitle_moments_ago(size: String) -> String { String(format: localized(key: "file_detail_subtitle_moments_ago"), size) }

    /// "View title"
    /// "File details"
    public static var file_detail_title: String { localized(key: "file_detail_title") }

    /// "Text displayed on the file detail view to show who uploaded the file"
    /// "Uploaded by"
    public static var file_detail_uploaded_by: String { localized(key: "file_detail_uploaded_by") }

    /// "Indicate the file is uploaded by anonymous user"
    /// "Anonymous"
    public static var file_detail_uploaded_by_anonymous: String { localized(key: "file_detail_uploaded_by_anonymous") }

    /// "e.g. Failed to import 3 files: access denied"
    /// "Failed to import %@: %@"
    public static func file_pickup_error(files: String, error: String) -> String { String(format: localized(key: "file_pickup_error"), files, error) }

    /// "Concat with other string, e.g. Restore 4 files, Delete 1 file"
    /// "%d File"
    public static func file_plural_type_with_num(num: Int) -> String { String(format: localized(key: "file_plural_type_with_num"), num) }

    /// "Alert message shown when user try to open file provider when app is not logged in "
    /// "Please open the Proton Drive app to sign in to continue"
    public static var file_provider_signIn_alert_message: String { localized(key: "file_provider_signIn_alert_message") }

    /// "Alert title shown when user try to open file provider when app is not logged in "
    /// "Sign In to Proton Drive"
    public static var file_provider_signIn_alert_title: String { localized(key: "file_provider_signIn_alert_title") }

    /// "Alert message shown when user try to open file provider when app is locked"
    /// "While PIN or Face ID/Touch ID are enabled on Proton Drive the content is not accessible in Files"
    public static var file_provider_unlock_alert_message: String { localized(key: "file_provider_unlock_alert_message") }

    /// "Alert title shown when user try to open file provider when app is locked"
    /// "Proton Drive is Locked"
    public static var file_provider_unlock_alert_title: String { localized(key: "file_provider_unlock_alert_title") }

    /// "Notification text when files upload failed"
    /// "Some files didn’t upload. Try uploading them again."
    public static var file_upload_failed_notification: String { localized(key: "file_upload_failed_notification") }

    /// "Notification text when files upload paused"
    /// "File upload paused. Open the app to resume."
    public static var file_upload_paused_notification: String { localized(key: "file_upload_paused_notification") }

    /// "Alert text"
    /// "Failed to upload %d file"
    public static func file_upload_status_failed_message(failedUploads: Int) -> String { String(format: localized(key: "file_upload_status_failed_message"), failedUploads) }

    /// "Error text shown on the view when user try to open invalid folder"
    /// "Start Folder with insufficient context"
    public static var finder_coordinator_invalid_folder: String { localized(key: "finder_coordinator_invalid_folder") }

    /// "Error text shown on the view when user try to open move to page for invalid node"
    /// "Called Go-Move with insufficient context"
    public static var finder_coordinator_invalid_go_move: String { localized(key: "finder_coordinator_invalid_go_move") }

    /// "Error text shown on the view when user try to open invalid shared folder"
    /// "Started Shared Folder with insufficient context"
    public static var finder_coordinator_invalid_shared_folder: String { localized(key: "finder_coordinator_invalid_shared_folder") }

    /// "Error text shown on the view when user try to move invalid node"
    /// "Start Move with insufficient context"
    public static var finder_coordinator_move_invalid_node: String { localized(key: "finder_coordinator_move_invalid_node") }

    /// "View title"
    /// "Folder details"
    public static var folder_detail_title: String { localized(key: "folder_detail_title") }

    /// "Concat with other string, e.g. Restore 4 folders, Delete 1 folder"
    /// "%d Folder"
    public static func folder_plural_type_with_num(num: Int) -> String { String(format: localized(key: "folder_plural_type_with_num"), num) }

    /// "Date formate for this month"
    /// "This month"
    public static var format_month_this_month: String { localized(key: "format_month_this_month") }

    /// "Button title, apply change"
    /// "Apply"
    public static var general_apply: String { localized(key: "general_apply") }

    /// "Button title"
    /// "Cancel"
    public static var general_cancel: String { localized(key: "general_cancel") }

    /// "Copy image, text...etc"
    /// "Copy"
    public static var general_copy: String { localized(key: "general_copy") }

    /// "Decrypting..."
    public static var general_decrypting: String { localized(key: "general_decrypting") }

    /// "Decryption failed"
    public static var general_decryption_failed: String { localized(key: "general_decryption_failed") }

    /// "Button title"
    /// "Delete"
    public static var general_delete: String { localized(key: "general_delete") }

    /// "Button to deselect items in the list"
    /// "Deselect all"
    public static var general_deselect_all: String { localized(key: "general_deselect_all") }

    /// "Button title"
    /// "Disable"
    public static var general_disable: String { localized(key: "general_disable") }

    /// "Button to dismiss page, banner..etc"
    /// "Dismiss"
    public static var general_dismiss: String { localized(key: "general_dismiss") }

    /// "Button title"
    /// "Done"
    public static var general_done: String { localized(key: "general_done") }

    /// "Downloading"
    public static var general_downloading: String { localized(key: "general_downloading") }

    /// "Button title"
    /// "Enable"
    public static var general_enable: String { localized(key: "general_enable") }

    /// "Concat with other string, e.g. Restore file, Delete file"
    /// "File"
    public static var general_file_type: String { localized(key: "general_file_type") }

    /// "Concat with other string, e.g. Restore folder, Delete folder"
    /// "Folder"
    public static var general_folder_type: String { localized(key: "general_folder_type") }

    /// "Get more storage"
    public static var general_get_more_storage: String { localized(key: "general_get_more_storage") }

    /// "Button title"
    /// "Get storage"
    public static var general_get_storage: String { localized(key: "general_get_storage") }

    /// "Button title"
    /// "Go back"
    public static var general_go_back: String { localized(key: "general_go_back") }

    /// "Button title"
    /// "Got it"
    public static var general_got_it: String { localized(key: "general_got_it") }

    /// "Concat with other string, e.g. Restore item, Delete item"
    /// "Item"
    public static var general_item_type: String { localized(key: "general_item_type") }

    /// "Button title"
    /// "Learn more"
    public static var general_learn_more: String { localized(key: "general_learn_more") }

    /// "information text"
    /// "Link copied"
    public static var general_link_copied: String { localized(key: "general_link_copied") }

    /// "Loading..."
    public static var general_loading: String { localized(key: "general_loading") }

    /// "Button title"
    /// "Log out"
    public static var general_logout: String { localized(key: "general_logout") }

    /// "Next button"
    /// "Next"
    public static var general_next: String { localized(key: "general_next") }

    /// "Button title"
    /// "Not now"
    public static var general_not_now: String { localized(key: "general_not_now") }

    /// "Status label text to indicate that the feature is turned off, e.g., Backup: Off"
    /// "Off"
    public static var general_off: String { localized(key: "general_off") }

    /// "Button title"
    /// "OK"
    public static var general_ok: String { localized(key: "general_ok") }

    /// "Status label text to indicate that the feature is turned on, e.g., \'Backup: On."
    /// "On"
    public static var general_on: String { localized(key: "general_on") }

    /// "information text"
    /// "Password copied"
    public static var general_password_copied: String { localized(key: "general_password_copied") }

    /// "action to pause, e.g. pause upload"
    /// "Pause"
    public static var general_pause: String { localized(key: "general_pause") }

    /// "Button title"
    /// "Refresh"
    public static var general_refresh: String { localized(key: "general_refresh") }

    /// "Action to remove items , e.g. remove upload failed file"
    /// "Remove"
    public static var general_remove: String { localized(key: "general_remove") }

    /// "Alert button title"
    /// "Remove file"
    public static func general_remove_files(num: Int) -> String { String(format: localized(key: "general_remove_files"), num) }

    /// "Alert button title"
    /// "Remove folder"
    public static func general_remove_folders(num: Int) -> String { String(format: localized(key: "general_remove_folders"), num) }

    /// "Alert button title"
    /// "Remove item"
    public static func general_remove_items(num: Int) -> String { String(format: localized(key: "general_remove_items"), num) }

    /// "Button title"
    /// "Rename"
    public static var general_rename: String { localized(key: "general_rename") }

    /// "Button title"
    /// "Restore"
    public static var general_restore: String { localized(key: "general_restore") }

    /// "Button to retry action after failing "
    /// "Retry"
    public static var general_retry: String { localized(key: "general_retry") }

    /// "Button title"
    /// "Save"
    public static var general_save: String { localized(key: "general_save") }

    /// "Action to select item"
    /// "Select"
    public static var general_select: String { localized(key: "general_select") }

    /// "Button to select all items in the list"
    /// "Select all"
    public static var general_select_all: String { localized(key: "general_select_all") }

    /// "%d selected"
    public static func general_selected(num: Int) -> String { String(format: localized(key: "general_selected"), num) }

    /// "button title"
    /// "Settings"
    public static var general_settings: String { localized(key: "general_settings") }

    /// "Button title"
    /// "Share"
    public static var general_share: String { localized(key: "general_share") }

    /// "Signing out..."
    public static var general_signing_out: String { localized(key: "general_signing_out") }

    /// "button title"
    /// "Skip"
    public static var general_skip: String { localized(key: "general_skip") }

    /// "Syncing"
    public static var general_syncing: String { localized(key: "general_syncing") }

    /// "placeholder"
    /// "Unknown"
    public static var general_unknown: String { localized(key: "general_unknown") }

    /// "Button title, e.g. upgrade plan"
    /// "Upgrade"
    public static var general_upgrade: String { localized(key: "general_upgrade") }

    /// "Uploading"
    public static var general_uploading: String { localized(key: "general_uploading") }

    /// "Button for importing new file"
    /// "Import file"
    public static var import_file_button: String { localized(key: "import_file_button") }

    /// "Concat with other string, e.g. Restore 4 items, Delete 1 item"
    /// "%d Item"
    public static func item_plural_type_with_num(num: Int) -> String { String(format: localized(key: "item_plural_type_with_num"), num) }

    /// "Alert title shown when certificate validation failed"
    /// "Disable Validation"
    public static var launch_alert_title_disable_validation: String { localized(key: "launch_alert_title_disable_validation") }

    /// "Alert to user when force update is needed"
    /// "Update"
    public static var launch_alert_title_update: String { localized(key: "launch_alert_title_update") }

    /// "Banner text"
    /// "The app will keep your screen awake to ensure faster backups."
    public static var locking_banner_message: String { localized(key: "locking_banner_message") }

    /// "By logging out, all files saved for offline will be deleted from your device"
    public static var logout_alert_message: String { localized(key: "logout_alert_message") }

    /// "Alert title shown when user attempts to logout"
    /// "Are you sure?"
    public static var logout_alert_title: String { localized(key: "logout_alert_title") }

    /// "Side menu section title"
    /// "More"
    public static var menu_section_title_more: String { localized(key: "menu_section_title_more") }

    /// "Side menu section title"
    /// "Storage"
    public static var menu_section_title_storage: String { localized(key: "menu_section_title_storage") }

    /// "Report a problem"
    public static var menu_text_feedback: String { localized(key: "menu_text_feedback") }

    /// "Sign out"
    public static var menu_text_logout: String { localized(key: "menu_text_logout") }

    /// "My files"
    public static var menu_text_my_files: String { localized(key: "menu_text_my_files") }

    /// "Settings"
    public static var menu_text_settings: String { localized(key: "menu_text_settings") }

    /// "Shared by me items"
    /// "Shared by me"
    public static var menu_text_shared_by_me: String { localized(key: "menu_text_shared_by_me") }

    /// "Subscription"
    public static var menu_text_subscription: String { localized(key: "menu_text_subscription") }

    /// "Label text to show total drive storage usage "
    /// "Total usage"
    public static var menu_text_total_usage: String { localized(key: "menu_text_total_usage") }

    /// "Trash"
    public static var menu_text_trash: String { localized(key: "menu_text_trash") }

    /// "Action to open file in some app"
    /// "Open in..."
    public static var more_action_open_in: String { localized(key: "more_action_open_in") }

    /// "Button in the move settings to indicate moving the selected file here."
    /// "Move here"
    public static var move_action_move_here: String { localized(key: "move_action_move_here") }

    /// "Name for newly created document, timestamp is dynamic"
    /// "Untitled document %@"
    public static func new_document_title(timestamp: String) -> String { String(format: localized(key: "new_document_title"), timestamp) }

    /// "Message on new feature promotion popup to introduce doc feature "
    /// "Tap plus to create or collaborate on end-to-end encrypted documents on the go."
    public static var new_feature_doc_desc: String { localized(key: "new_feature_doc_desc") }

    /// "Title on new feature promotion popup to introduce doc feature "
    /// "Proton Docs on Mobile"
    public static var new_feature_doc_title: String { localized(key: "new_feature_doc_title") }

    /// "Message on new feature promotion popup to introduce sharing feature "
    /// "Invite others via email to view and edit your files, or create a public link for quick access"
    public static var new_feature_sharing_desc: String { localized(key: "new_feature_sharing_desc") }

    /// "Title on new feature promotion popup to introduce sharing feature "
    /// "Invite people to your files"
    public static var new_feature_sharing_title: String { localized(key: "new_feature_sharing_title") }

    /// "Title for new feature promotion popup"
    /// "What\'s new!"
    public static var new_feature_title: String { localized(key: "new_feature_title") }

    /// "Button to redirect to storage setting page"
    /// "Go to local storage settings"
    public static var no_space_open_storage_setting: String { localized(key: "no_space_open_storage_setting") }

    /// "No space warning"
    /// "Not enough storage space to upload. Please consider upgrading your account or contact our customer support."
    public static var no_space_subtitle_cloud_full: String { localized(key: "no_space_subtitle_cloud_full") }

    /// "No space warning"
    /// "There is not enough storage on your device to download all the files marked as offline available."
    public static var no_space_subtitle_device_full: String { localized(key: "no_space_subtitle_device_full") }

    /// "No space warning"
    /// "Your device is packed."
    public static var no_space_title_device_is_packed: String { localized(key: "no_space_title_device_is_packed") }

    /// "No space warning"
    /// "You reached the limit of your plan."
    public static var no_space_title_limit_of_plan: String { localized(key: "no_space_title_limit_of_plan") }

    /// "Button to expand text view for error deteail"
    /// "Details"
    public static var notification_details: String { localized(key: "notification_details") }

    /// "Error text"
    /// "There is %d issue"
    public static func notification_issues(num: Int) -> String { String(format: localized(key: "notification_issues"), num) }

    /// "Button to turn on notifications."
    /// "Allow notifications"
    public static var notification_permission_enable_button_title: String { localized(key: "notification_permission_enable_button_title") }

    /// "Message shown in the notification popup when files are uploading."
    /// "We’ll notify you if there are any interruptions to your uploads or downloads."
    public static var notification_permission_files_description: String { localized(key: "notification_permission_files_description") }

    /// "Title shown in the notification popup when files are uploading."
    /// "Turn on notifications"
    public static var notification_permission_files_title: String { localized(key: "notification_permission_files_title") }

    /// "Message shown in the notification popup when photos are uploading."
    /// "We’ll only notify you if your action is required to complete backups and uploads."
    public static var notification_permission_photos_description: String { localized(key: "notification_permission_photos_description") }

    /// "Title shown in the  popup when photos are uploading."
    /// "Ensure seamless backups"
    public static var notification_permission_photos_title: String { localized(key: "notification_permission_photos_title") }

    /// "Notification text"
    /// "Check in with Proton Drive to confirm your photos are backed up and secure."
    public static var notification_text_confirm_backup_success: String { localized(key: "notification_text_confirm_backup_success") }

    /// "Button to restart application"
    /// "Update available. Click to restart Proton Drive."
    public static var notification_update_available: String { localized(key: "notification_update_available") }

    /// "Button title shown on the onboarding page"
    /// "Get started"
    public static var onboarding_button_get_started: String { localized(key: "onboarding_button_get_started") }

    /// "Button title shown on the onboarding page"
    /// "Next"
    public static var onboarding_button_next: String { localized(key: "onboarding_button_next") }

    /// "Message shown in the app onboarding view"
    /// "Upload and view your files on the go. Zero-access technology guarantees only you have access."
    public static var onboarding_file_text: String { localized(key: "onboarding_file_text") }

    /// "Title shown in the app onboarding view"
    /// "All files at your fingertips"
    public static var onboarding_file_title: String { localized(key: "onboarding_file_title") }

    /// "Message shown in the app onboarding view"
    /// "Ensure your memories are kept safe, private, and in their original quality for years to come."
    public static var onboarding_photo_text: String { localized(key: "onboarding_photo_text") }

    /// "Title shown in the app onboarding view"
    /// "Automatic photo backups"
    public static var onboarding_photo_title: String { localized(key: "onboarding_photo_title") }

    /// "Message shown in the app onboarding view"
    /// "Add password protection to make your shared files even more secure."
    public static var onboarding_share_text: String { localized(key: "onboarding_share_text") }

    /// "Title shown in the app onboarding view"
    /// "Secure sharing"
    public static var onboarding_share_title: String { localized(key: "onboarding_share_title") }

    /// "Description of one dollar upsell popup"
    /// "When you need a little more storage, but not a lot. Introducing Drive Lite, featuring 20 GB storage for only %@ a month."
    public static func one_dollar_upsell_desc(localPrice: String) -> String { String(format: localized(key: "one_dollar_upsell_desc"), localPrice) }

    /// "Get Drive Lite"
    public static var one_dollar_upsell_get_plan_button: String { localized(key: "one_dollar_upsell_get_plan_button") }

    /// "Title of one dollar upsell popup"
    /// "More storage for only %@"
    public static func one_dollar_upsell_title(localPrice: String) -> String { String(format: localized(key: "one_dollar_upsell_title"), localPrice) }

    /// "View title"
    /// "Change mailbox password"
    public static var password_change_mailbox_password_title: String { localized(key: "password_change_mailbox_password_title") }

    /// "Banner text shown after changing successfully"
    /// "Password changed successfully"
    public static var password_change_success_text: String { localized(key: "password_change_success_text") }

    /// "View title"
    /// "Change password"
    public static var password_change_title: String { localized(key: "password_change_title") }

    /// "PIN config rule text"
    /// "Enter a PIN code with min 4 characters and max 21 characters."
    public static var password_config_caption: String { localized(key: "password_config_caption") }

    /// "Button in the config page to move to next page"
    /// "Next"
    public static var password_config_next_step: String { localized(key: "password_config_next_step") }

    /// "Title of textfield"
    /// "Set your PIN code"
    public static var password_config_textfield_title: String { localized(key: "password_config_textfield_title") }

    /// "Use PIN code"
    public static var password_config_title_use_pin: String { localized(key: "password_config_title_use_pin") }

    /// "Action title in photos grid view"
    /// "Remove %d item"
    public static func photo_action_remove_item(num: Int) -> String { String(format: localized(key: "photo_action_remove_item"), num) }

    /// "Title shown in photo backup banner"
    /// "Backup in progress. This may take a while."
    public static var photo_backup_banner_in_progress: String { localized(key: "photo_backup_banner_in_progress") }

    /// "Title shown in photo backup banner"
    /// "End-to-end encrypted"
    public static var photo_backup_banner_title_e2ee: String { localized(key: "photo_backup_banner_title_e2ee") }

    /// "Are you sure you want to disable this feature? You can re-enable it later in settings if needed."
    public static var photo_feature_disable_alert_message: String { localized(key: "photo_feature_disable_alert_message") }

    /// "Disable photo backup feature"
    public static var photo_feature_disable_title: String { localized(key: "photo_feature_disable_title") }

    /// "Are you sure you want to enable this feature? The photo backup will be activated and displayed again."
    public static var photo_feature_enable_alert_message: String { localized(key: "photo_feature_enable_alert_message") }

    /// "Enable photo backup feature"
    public static var photo_feature_enable_title: String { localized(key: "photo_feature_enable_title") }

    /// "This will enable photo backup feature on this device. The Photos tab and feature settings will be displayed."
    public static var photo_feature_explanation: String { localized(key: "photo_feature_explanation") }

    /// "Failed to fetch photos. Please try again later."
    public static var photo_grid_error: String { localized(key: "photo_grid_error") }

    /// "Turn on backup"
    public static var photo_onboarding_button_enable: String { localized(key: "photo_onboarding_button_enable") }

    /// "Your photos are end-to-end encrypted, ensuring total privacy."
    public static var photo_onboarding_e2e: String { localized(key: "photo_onboarding_e2e") }

    /// "Effortless backups"
    public static var photo_onboarding_effortless_backups: String { localized(key: "photo_onboarding_effortless_backups") }

    /// "Photos are backed up over WiFi in their original quality."
    public static var photo_onboarding_keep_quality: String { localized(key: "photo_onboarding_keep_quality") }

    /// "Protect your memories"
    public static var photo_onboarding_protect_memories: String { localized(key: "photo_onboarding_protect_memories") }

    /// "Encrypt and back up your photos and videos"
    public static var photo_onboarding_title: String { localized(key: "photo_onboarding_title") }

    /// "Button shown in the notification popup when photos are uploading."
    /// "Give access"
    public static var photo_permission_alert_button: String { localized(key: "photo_permission_alert_button") }

    /// "Message shown in the popup when photos are uploading."
    /// "This ensures all your photos are backed up and available across your devices.\n\nIn the next screen, change your settings to allow Proton Drive access to All Photos."
    public static var photo_permission_alert_text: String { localized(key: "photo_permission_alert_text") }

    /// "Title shown in the notification popup when user doesn\'t grant proper permission"
    /// "Proton Drive needs full access to your photos"
    public static var photo_permission_alert_title: String { localized(key: "photo_permission_alert_title") }

    /// "Error text shown on the photo preview page"
    /// "There was an error loading this photo"
    public static var photo_preview_error_text: String { localized(key: "photo_preview_error_text") }

    /// "Error title shown on the photo preview page"
    /// "Could not load this photo"
    public static var photo_preview_error_title: String { localized(key: "photo_preview_error_title") }

    /// "Title displayed on the photo storage banner. Use ** to denote bold text; please retain this syntax."
    /// "Your storage is more than **80%** full"
    public static var photo_storage_eighty_percent_title: String { localized(key: "photo_storage_eighty_percent_title") }

    /// "Title displayed on the photo storage banner. Use ** to denote bold text; please retain this syntax."
    /// "Your storage is **50%** full"
    public static var photo_storage_fifty_percent_title: String { localized(key: "photo_storage_fifty_percent_title") }

    /// "Subtitle displayed on the photo storage banner. "
    /// "To continue the process you need to upgrade your plan."
    public static var photo_storage_full_subtitle: String { localized(key: "photo_storage_full_subtitle") }

    /// "Title displayed on the photo storage banner. "
    /// "Storage full"
    public static var photo_storage_full_title: String { localized(key: "photo_storage_full_title") }

    /// "Text shown on the photo storage banner, e.g. 3 items left, 1 item left"
    /// "%@ left"
    public static func photo_storage_item_left(items: String) -> String { String(format: localized(key: "photo_storage_item_left"), items) }

    /// "Notification text when photo is backing up but in the background"
    /// "Photo backup is slower in the background. Open the app for quicker uploads."
    public static var photo_upload_interrupted_notification: String { localized(key: "photo_upload_interrupted_notification") }

    /// "Subtitle shown on the photo upsell popup"
    /// "Upgrade now and keep all your memories encrypted and safe."
    public static var photo_upsell_subtitle: String { localized(key: "photo_upsell_subtitle") }

    /// "Title shown on the photo upsell popup"
    /// "Never run out of storage"
    public static var photo_upsell_title: String { localized(key: "photo_upsell_title") }

    /// "Warning text displayed in the photo picker."
    /// "Importing the files. Please keep the app open to avoid interruptions."
    public static var photos_picker_warning: String { localized(key: "photos_picker_warning") }

    /// "Text indicating that data is loading."
    /// "Getting things ready..."
    public static var populate_loading_text: String { localized(key: "populate_loading_text") }

    /// "Cancel"
    public static var prepare_preview_cancel: String { localized(key: "prepare_preview_cancel") }

    /// "The text displayed in the badge at the top left when previewing burst"
    /// "Burst"
    public static var preview_burst_badge_text: String { localized(key: "preview_burst_badge_text") }

    /// "A text label to indicate the image is cover of this burst"
    /// "Cover"
    public static var preview_burst_cover: String { localized(key: "preview_burst_cover") }

    /// "%d photo in total"
    public static func preview_burst_gallery_subtitle(num: Int) -> String { String(format: localized(key: "preview_burst_gallery_subtitle"), num) }

    /// "The text displayed in the badge at the top left when previewing a live photo"
    /// "LIVE"
    public static var preview_livePhoto_badge_text: String { localized(key: "preview_livePhoto_badge_text") }

    /// "The text displayed in the badge at the top left while the asset is loading during the preview."
    /// "Loading"
    public static var preview_loading_badge_text: String { localized(key: "preview_loading_badge_text") }

    /// "Text shown with progress bar"
    /// "%@ downloaded"
    public static func progress_status_downloaded(percent: String) -> String { String(format: localized(key: "progress_status_downloaded"), percent) }

    /// "Text to indicate this file is downloading"
    /// "Downloading..."
    public static var progress_status_downloading: String { localized(key: "progress_status_downloading") }

    /// "Banner text shown on photo backup page to indicate how many photos left e.g. 350+ items left"
    /// "%d%@ item left"
    public static func progress_status_item_left(items: Int, roundingSign: String) -> String { String(format: localized(key: "progress_status_item_left"), items, roundingSign) }

    /// "Text to indicate this file is downloading"
    /// "Paused"
    public static var progress_status_paused: String { localized(key: "progress_status_paused") }

    /// "Upload failed"
    public static var progress_status_upload_failed: String { localized(key: "progress_status_upload_failed") }

    /// "Text shown with progress bar"
    /// "%@ uploaded..."
    public static func progress_status_uploaded(percent: String) -> String { String(format: localized(key: "progress_status_uploaded"), percent) }

    /// "Text to indicate this file is uploading"
    /// "Uploading..."
    public static var progress_status_uploading: String { localized(key: "progress_status_uploading") }

    /// "Waiting..."
    public static var progress_status_waiting: String { localized(key: "progress_status_waiting") }

    /// "Information banner shown on protection setting page "
    /// "Enabling auto-lock stops background processes unless set to \"After launch.\""
    public static var protection_info_banner_text: String { localized(key: "protection_info_banner_text") }

    /// "Text field caption"
    /// "Repeat your PIN to confirm."
    public static var protection_pin_caption_repeat_pin_code: String { localized(key: "protection_pin_caption_repeat_pin_code") }

    /// "Text field title"
    /// "Repeat your PIN code"
    public static var protection_pin_title_repeat_pin_code: String { localized(key: "protection_pin_title_repeat_pin_code") }

    /// "Section footer for pin&faceID setting"
    /// "Turn this feature on to auto-lock and use a PIN code or biometric sensor to unlock it."
    public static var protection_section_footer_protection: String { localized(key: "protection_section_footer_protection") }

    /// "Section header for pin&faceID setting"
    /// "Protection"
    public static var protection_section_header_protection: String { localized(key: "protection_section_header_protection") }

    /// "Section footer of protection auto lock setting"
    /// "The PIN code will be required after some minutes of the app being in the background or after exiting the app."
    public static var protection_timing_section_footer: String { localized(key: "protection_timing_section_footer") }

    /// "Section header of protection auto lock setting"
    /// "Timings"
    public static var protection_timings_section_header: String { localized(key: "protection_timings_section_header") }

    /// "Option title to choose biometry as protection"
    /// "Use Biometry"
    public static var protection_use_biometry: String { localized(key: "protection_use_biometry") }

    /// "e.g. use FaceID, use TouchID"
    /// "Use %@"
    public static func protection_use_use_technology(tech: String) -> String { String(format: localized(key: "protection_use_use_technology"), tech) }

    /// "Failed to download file"
    public static var proton_docs_download_error: String { localized(key: "proton_docs_download_error") }

    /// "Failed to open document editor"
    public static var proton_docs_opening_error: String { localized(key: "proton_docs_opening_error") }

    /// "Text shown with loading spinner"
    /// "Last updated: %@"
    public static func refresh_last_update(time: String) -> String { String(format: localized(key: "refresh_last_update"), time) }

    /// "Error message displayed on the photo backup issue page"
    /// "Unable to connect to iCloud"
    public static var retry_error_explainer_cannot_connect_icloud: String { localized(key: "retry_error_explainer_cannot_connect_icloud") }

    /// "Error message displayed on the photo backup issue page"
    /// "Network connection error"
    public static var retry_error_explainer_connection_error: String { localized(key: "retry_error_explainer_connection_error") }

    /// "Error message displayed on the photo backup issue page"
    /// "Device storage full"
    public static var retry_error_explainer_device_storage_full: String { localized(key: "retry_error_explainer_device_storage_full") }

    /// "Error message displayed on the photo backup issue page"
    /// "Encryption failed"
    public static var retry_error_explainer_encryption_error: String { localized(key: "retry_error_explainer_encryption_error") }

    /// "Error message displayed on the photo backup issue page"
    /// "Failed to load resource"
    public static var retry_error_explainer_failed_to_load_resource: String { localized(key: "retry_error_explainer_failed_to_load_resource") }

    /// "Error message displayed on the photo backup issue page"
    /// "Can\'t access the original file."
    public static var retry_error_explainer_invalid_asset: String { localized(key: "retry_error_explainer_invalid_asset") }

    /// "Error message displayed on the photo backup issue page"
    /// "Missing permissions"
    public static var retry_error_explainer_missing_permissions: String { localized(key: "retry_error_explainer_missing_permissions") }

    /// "Error message displayed on the photo backup issue page"
    /// "Name validation failed"
    public static var retry_error_explainer_name_validation: String { localized(key: "retry_error_explainer_name_validation") }

    /// "Error message displayed on the photo backup issue page"
    /// "Drive storage full"
    public static var retry_error_explainer_quote_exceeded: String { localized(key: "retry_error_explainer_quote_exceeded") }

    /// "Message shown when a user attempts to skip a photo that failed to back up."
    /// "Are you sure you want to skip photos that haven\'t been backed up? They will not be backed up."
    public static var retry_skip_alert_message: String { localized(key: "retry_skip_alert_message") }

    /// "Title shown when a user attempts to skip a photo that failed to back up."
    /// "Skip backup for these photos?"
    public static var retry_skip_alert_title: String { localized(key: "retry_skip_alert_title") }

    /// "Button title"
    /// "Retry all"
    public static var retry_view_button_retry_all: String { localized(key: "retry_view_button_retry_all") }

    /// "Subtitle shown on the backup retry view"
    /// "%d item failed to backup"
    public static func retry_view_items_failed_to_backup(count: Int) -> String { String(format: localized(key: "retry_view_items_failed_to_backup"), count) }

    /// "Title shown on the backup retry view"
    /// "Backup issues"
    public static var retry_view_title: String { localized(key: "retry_view_title") }

    /// "Account setting section title"
    /// "Account"
    public static var setting_account: String { localized(key: "setting_account") }

    /// "Button title"
    /// "Manage account"
    public static var setting_account_manage_account: String { localized(key: "setting_account_manage_account") }

    /// "Biometry protection setting title"
    /// "Biometry"
    public static var setting_biometry: String { localized(key: "setting_biometry") }

    /// "Setting option to clear local cache"
    /// "Clear local cache"
    public static var setting_clear_local_cache: String { localized(key: "setting_clear_local_cache") }

    /// "Setting option to export log"
    /// "Export logs"
    public static var setting_export_logs: String { localized(key: "setting_export_logs") }

    /// "Get help section title"
    /// "Get help"
    public static var setting_get_help: String { localized(key: "setting_get_help") }

    /// "This is markdown text\nPlease move [support website](%@) together"
    /// "You will find additional help on our [support website](%@)"
    public static func setting_help_additional_help(link: String) -> String { String(format: localized(key: "setting_help_additional_help"), link) }

    /// "Label text to encourage user report issue"
    /// "If you are facing any problems, please report the issue."
    public static var setting_help_report_encourage_text: String { localized(key: "setting_help_report_encourage_text") }

    /// "Button title"
    /// "Report an issue"
    public static var setting_help_report_issue: String { localized(key: "setting_help_report_issue") }

    /// "Button title"
    /// "Show logs"
    public static var setting_help_show_logs: String { localized(key: "setting_help_show_logs") }

    /// "Version %@"
    public static func setting_mac_version(version: String) -> String { String(format: localized(key: "setting_mac_version"), version) }

    /// "Setting option to photo backup"
    /// "Photos backup"
    public static var setting_photo_backup: String { localized(key: "setting_photo_backup") }

    /// "PIN protection setting title"
    /// "PIN"
    public static var setting_pin: String { localized(key: "setting_pin") }

    /// "Storage setting section title"
    /// "Storage"
    public static var setting_storage: String { localized(key: "setting_storage") }

    /// "Out of storage"
    public static var setting_storage_out_of_storage: String { localized(key: "setting_storage_out_of_storage") }

    /// "Syncing has been paused. Please upgrade or free up space to resume syncing."
    public static var setting_storage_out_of_storage_warning: String { localized(key: "setting_storage_out_of_storage_warning") }

    /// "\\(currentStorage) of \\(maxStorage) used"
    /// "%@ of %@ used"
    public static func setting_storage_usage_info(currentStorage: String, maxStorage: String) -> String { String(format: localized(key: "setting_storage_usage_info"), currentStorage, maxStorage) }

    /// "System setting section title"
    /// "System"
    public static var setting_system: String { localized(key: "setting_system") }

    /// "Information text"
    /// "Checking for update ..."
    public static var setting_system_checking_update: String { localized(key: "setting_system_checking_update") }

    /// "Information text"
    /// "Downloading new version ..."
    public static var setting_system_downloading: String { localized(key: "setting_system_downloading") }

    /// "Toggle title"
    /// "Launch on startup"
    public static var setting_system_launch_on_startup: String { localized(key: "setting_system_launch_on_startup") }

    /// "Information text"
    /// "New version available"
    public static var setting_system_new_version_available: String { localized(key: "setting_system_new_version_available") }

    /// "Information text"
    /// "Proton Drive is up to date: v%@"
    public static func setting_system_up_to_date(version: String) -> String { String(format: localized(key: "setting_system_up_to_date"), version) }

    /// "Button title"
    /// "Update now"
    public static var setting_system_update_button: String { localized(key: "setting_system_update_button") }

    /// "Terms and Conditions"
    public static var setting_terms_and_condition: String { localized(key: "setting_terms_and_condition") }

    /// "Title of default home tab setting"
    /// "Default home tab"
    public static var settings_default_home_tab: String { localized(key: "settings_default_home_tab") }

    /// "The action for coping share link"
    /// "Copy link"
    public static var share_action_copy_link: String { localized(key: "share_action_copy_link") }

    /// "The action for copying a password used to protect a shared item"
    /// "Copy password"
    public static var share_action_copy_password: String { localized(key: "share_action_copy_password") }

    /// "The action for opening setting page"
    /// "Link settings"
    public static var share_action_link_settings: String { localized(key: "share_action_link_settings") }

    /// "Action to save burst photo"
    /// "Save Burst"
    public static var share_action_save_burst_photo: String { localized(key: "share_action_save_burst_photo") }

    /// "Action to save image"
    /// "Save Image"
    public static var share_action_save_image: String { localized(key: "share_action_save_image") }

    /// "Action to save live photo"
    /// "Save Live Photo"
    public static var share_action_save_live_photo: String { localized(key: "share_action_save_live_photo") }

    /// "The action for showing system share sheet"
    /// "Share"
    public static var share_action_share: String { localized(key: "share_action_share") }

    /// "The action for stopping sharing item"
    /// "Stop sharing"
    public static var share_action_stop_sharing: String { localized(key: "share_action_stop_sharing") }

    /// "Information text for stop sharing"
    /// "Delete link and remove access for everyone"
    public static var share_action_stop_sharing_desc: String { localized(key: "share_action_stop_sharing_desc") }

    /// "Message of the share page when no items are shared"
    /// "Create links and share files with others"
    public static var share_empty_message: String { localized(key: "share_empty_message") }

    /// "Title of the share page when no items are shared"
    /// "Share files with links"
    public static var share_empty_title: String { localized(key: "share_empty_title") }

    /// "Append the item name, for example: Share a.png, Share sample folder."
    /// "Share %@"
    public static func share_item(name: String) -> String { String(format: localized(key: "share_item"), name) }

    /// "Warning text"
    /// "This link was created with an old Drive version and can not be modified. Delete this link and create a new one to change the settings."
    public static var share_legacy_link_warning: String { localized(key: "share_legacy_link_warning") }

    /// "Button displayed on the screen in case of failure"
    /// "Delete Link"
    public static var share_link_button_delete_link: String { localized(key: "share_link_button_delete_link") }

    /// "Action text shown in the unsaved changes alert"
    /// "Leave without saving"
    public static var share_link_drop_unsaved_change_action: String { localized(key: "share_link_drop_unsaved_change_action") }

    /// "Error message displayed on the screen in case of failure"
    /// "Failed to generate a secure link. Try again later."
    public static var share_link_error_message: String { localized(key: "share_link_error_message") }

    /// "Please select an expiration date in the future"
    public static var share_link_past_date_error: String { localized(key: "share_link_past_date_error") }

    /// "Action text shown in the unsaved changes alert"
    /// "Save changes"
    public static var share_link_save_changes: String { localized(key: "share_link_save_changes") }

    /// "Banner text"
    /// "Sharing settings updated"
    public static var share_link_settings_updated: String { localized(key: "share_link_settings_updated") }

    /// "Alert title shown in the unsaved changes alert"
    /// "Your unsaved changes will be lost."
    public static var share_link_unsaved_change_alert_title: String { localized(key: "share_link_unsaved_change_alert_title") }

    /// "Label text"
    /// "Updating Settings"
    public static var share_link_updating_title: String { localized(key: "share_link_updating_title") }

    /// "Section header title for set public share link"
    /// "Link options"
    public static var share_section_link_options: String { localized(key: "share_section_link_options") }

    /// "Button title"
    /// "Stop sharing"
    public static var share_stop_sharing: String { localized(key: "share_stop_sharing") }

    /// "This will delete the link and remove access to your file or folder for anyone with the link. You can’t undo this action."
    public static var share_stop_sharing_alert_message: String { localized(key: "share_stop_sharing_alert_message") }

    /// "Message shown in the share setting page"
    /// "Anyone with the link and password can access the file/folder "
    public static var share_via_custom_password_message: String { localized(key: "share_via_custom_password_message") }

    /// "Message shown in the share setting page"
    /// "Anyone with this link can access your file/folder"
    public static var share_via_default_password_message: String { localized(key: "share_via_default_password_message") }

    /// "Preparing secure link for sharing"
    /// "Preparing secure link"
    public static var share_via_prepare_secure_link: String { localized(key: "share_via_prepare_secure_link") }

    /// "Files and folders that you share with others will appear here"
    public static var shared_by_me_empty_message: String { localized(key: "shared_by_me_empty_message") }

    /// "Shared by me"
    public static var shared_by_me_empty_title: String { localized(key: "shared_by_me_empty_title") }

    /// "Shared by me"
    public static var shared_by_me_screen_title: String { localized(key: "shared_by_me_screen_title") }

    /// "Shared"
    public static var shared_screen_title: String { localized(key: "shared_screen_title") }

    /// "Shared with me empty message"
    /// "Files and folders that others shared with you will appear here"
    public static var shared_with_me_empty_message: String { localized(key: "shared_with_me_empty_message") }

    /// "Shared with me empty title"
    /// "Shared with me"
    public static var shared_with_me_empty_title: String { localized(key: "shared_with_me_empty_title") }

    /// "Alert title shown when user attempts to remove his access to the file or folder"
    /// "You are about to leave \"%@\". You will not be able to access it again until the owner shares it with you. Are you sure you want to proceed?"
    public static func shared_with_me_remove_me(item: String) -> String { String(format: localized(key: "shared_with_me_remove_me"), item) }

    /// "Leave"
    public static var shared_with_me_remove_me_confirmation: String { localized(key: "shared_with_me_remove_me_confirmation") }

    /// "Placeholder text of invitation message"
    /// "Add a message"
    public static var sharing_invitation_message_placeholder: String { localized(key: "sharing_invitation_message_placeholder") }

    /// "Banner text is shown when user try to invite address has invited"
    /// "Already a member of this share."
    public static var sharing_invite_duplicated_member_error: String { localized(key: "sharing_invite_duplicated_member_error") }

    /// "Banner text shown after removing user\'s access"
    /// "Access removed"
    public static var sharing_member_access_removed: String { localized(key: "sharing_member_access_removed") }

    /// "Banner text shown after updating the invitee\'s access permissions."
    /// "Access updated and shared"
    public static var sharing_member_access_updated: String { localized(key: "sharing_member_access_updated") }

    /// "Title of public link component to indicate that anyone with the link can edit or view."
    /// "Anyone with the link"
    public static var sharing_member_anyone_with_link: String { localized(key: "sharing_member_anyone_with_link") }

    /// "Action title"
    /// "Copy invite link"
    public static var sharing_member_copy_invite_link: String { localized(key: "sharing_member_copy_invite_link") }

    /// "Banner text when added editor success"
    /// "%d editor added"
    public static func sharing_member_editor_added(num: Int) -> String { String(format: localized(key: "sharing_member_editor_added"), num) }

    /// "Error message"
    /// "The invitee has already been invited."
    public static var sharing_member_error_already_invited: String { localized(key: "sharing_member_error_already_invited") }

    /// "Error message"
    /// "Group sharing is not supported at the moment."
    public static var sharing_member_error_group_not_support: String { localized(key: "sharing_member_error_group_not_support") }

    /// "You’ve hit the limit for invites and members in this share. Consider removing someone to expand the share limit."
    public static var sharing_member_error_insufficient_invitation_quota: String { localized(key: "sharing_member_error_insufficient_invitation_quota") }

    /// "Error message"
    /// "This user is part of too many shares. Please ask them to leave a share before inviting them."
    public static var sharing_member_error_insufficient_share_joined_quota: String { localized(key: "sharing_member_error_insufficient_share_joined_quota") }

    /// "Error message"
    /// "The invitee’s email is not associated with a Proton account, or you’re trying to invite yourself. Please check the email and try again."
    public static var sharing_member_error_invalid_address: String { localized(key: "sharing_member_error_invalid_address") }

    /// "Error message"
    /// "Your email doesn’t match the one used to share this content."
    public static var sharing_member_error_invalid_inviter_address: String { localized(key: "sharing_member_error_invalid_inviter_address") }

    /// "Error message"
    /// "Invalid key packet detected. Please contact customer support"
    public static var sharing_member_error_invalid_key_packet: String { localized(key: "sharing_member_error_invalid_key_packet") }

    /// "Error message"
    /// "Invalid key packet signature. Please contact customer support"
    public static var sharing_member_error_invalid_key_packet_signature: String { localized(key: "sharing_member_error_invalid_key_packet_signature") }

    /// "Error message"
    /// "The user is already in this share with a different email."
    public static var sharing_member_error_invited_with_different_email: String { localized(key: "sharing_member_error_invited_with_different_email") }

    /// "Error message"
    /// "We couldn’t find the email address or key for the invitee."
    public static var sharing_member_error_missing_key: String { localized(key: "sharing_member_error_missing_key") }

    /// "Error message"
    /// "The current user does not have admin permission on this share"
    public static var sharing_member_error_not_allowed: String { localized(key: "sharing_member_error_not_allowed") }

    /// "Error message"
    /// "The invitation does not exist"
    public static var sharing_member_error_not_exist: String { localized(key: "sharing_member_error_not_exist") }

    /// "Error message"
    /// "Sharing is temporarily disabled. Please try again later."
    public static var sharing_member_error_temporarily_disabled: String { localized(key: "sharing_member_error_temporarily_disabled") }

    /// "Include message and file name in invite email"
    public static var sharing_member_include_message: String { localized(key: "sharing_member_include_message") }

    /// "Information text"
    /// "Message and file name are stored with zero access encryption when included in the invite email."
    public static var sharing_member_include_message_info: String { localized(key: "sharing_member_include_message_info") }

    /// "Text to indicate invite message is not included"
    /// "not included"
    public static var sharing_member_include_message_not_included: String { localized(key: "sharing_member_include_message_not_included") }

    /// "Section title to set invite message"
    /// "Message for recipient"
    public static var sharing_member_include_message_section_title: String { localized(key: "sharing_member_include_message_section_title") }

    /// "Button title to invite people to access file"
    /// "Add people or group to share"
    public static var sharing_member_invite_button: String { localized(key: "sharing_member_invite_button") }

    /// "Banner text shown after coping invite link"
    /// "Invite link copied"
    public static var sharing_member_invite_link_copied: String { localized(key: "sharing_member_invite_link_copied") }

    /// "Invitation has been sent to the invitee."
    /// "Invite sent"
    public static var sharing_member_invite_send: String { localized(key: "sharing_member_invite_send") }

    /// "Section header of invitee list"
    /// "Shared with"
    public static var sharing_member_invitee_section_header: String { localized(key: "sharing_member_invitee_section_header") }

    /// "Banner text shown after creating public share link"
    /// "Link to this item created"
    public static var sharing_member_link_created: String { localized(key: "sharing_member_link_created") }

    /// "The invitation is still pending as the invitee has not yet responded."
    /// "Pending"
    public static var sharing_member_pending: String { localized(key: "sharing_member_pending") }

    /// "Text to indicate invitee has write permission"
    /// "Can edit"
    public static var sharing_member_permission_can_edit: String { localized(key: "sharing_member_permission_can_edit") }

    /// "Text to indicate invitee has read permission"
    /// "Can view"
    public static var sharing_member_permission_can_view: String { localized(key: "sharing_member_permission_can_view") }

    /// "Section title to set access permission"
    /// "Permission"
    public static var sharing_member_permission_section_title: String { localized(key: "sharing_member_permission_section_title") }

    /// "Placeholder of text field"
    /// "Add people or group"
    public static var sharing_member_placeholder: String { localized(key: "sharing_member_placeholder") }

    /// "Section header"
    /// "Sharing options"
    public static var sharing_member_public_link_header: String { localized(key: "sharing_member_public_link_header") }

    /// "Action title"
    /// "Remove access"
    public static var sharing_member_remove_access: String { localized(key: "sharing_member_remove_access") }

    /// "Banner text shown after resending invitation"
    /// "Invitation\'s email was sent again"
    public static var sharing_member_resend_invitation: String { localized(key: "sharing_member_resend_invitation") }

    /// "Action title to resend invitation"
    /// "Resend invite"
    public static var sharing_member_resend_invite: String { localized(key: "sharing_member_resend_invite") }

    /// "The role of the sharing member is an editor"
    /// "Editor"
    public static var sharing_member_role_editor: String { localized(key: "sharing_member_role_editor") }

    /// "The role of the sharing member is a viewer."
    /// "Viewer"
    public static var sharing_member_role_viewer: String { localized(key: "sharing_member_role_viewer") }

    /// "Action sheet title for enable/disable invitation message "
    /// "Message setting"
    public static var sharing_member_title_message_setting: String { localized(key: "sharing_member_title_message_setting") }

    /// "Information about how many people is invited"
    /// "Sharing with %d person"
    public static func sharing_member_total_invitee(num: Int) -> String { String(format: localized(key: "sharing_member_total_invitee"), num) }

    /// "Banner text when added editor success"
    /// "%d viewer added"
    public static func sharing_member_viewer_added(num: Int) -> String { String(format: localized(key: "sharing_member_viewer_added"), num) }

    /// "How many members in the group"
    /// "%d member"
    public static func sharing_members(num: Int) -> String { String(format: localized(key: "sharing_members"), num) }

    /// "Start using Proton Drive"
    public static var sign_up_succeed_text: String { localized(key: "sign_up_succeed_text") }

    /// "Label text, sort files by file type"
    /// "File type"
    public static var sort_type_file_type: String { localized(key: "sort_type_file_type") }

    /// "Label text, sort files by last modified date"
    /// "Last modified"
    public static var sort_type_last_modified: String { localized(key: "sort_type_last_modified") }

    /// "Label text, sort files by file name"
    /// "Name"
    public static var sort_type_name: String { localized(key: "sort_type_name") }

    /// "Label text, sort files by file size"
    /// "Size"
    public static var sort_type_size: String { localized(key: "sort_type_size") }

    /// "Banner text on the state banner"
    /// "Your account is at risk of deletion"
    public static var state_at_risk_of_deletion: String { localized(key: "state_at_risk_of_deletion") }

    /// "To avoid data loss, ask your admin to upgrade."
    public static var state_at_risk_of_deletion_desc: String { localized(key: "state_at_risk_of_deletion_desc") }

    /// "Text shown on the state banner"
    /// "Backing up..."
    public static var state_backing_up: String { localized(key: "state_backing_up") }

    /// "Banner text on the state banner when backup complete"
    /// "Backup complete"
    public static var state_backup_complete_title: String { localized(key: "state_backup_complete_title") }

    /// "Banner text on the state banner when backup is disabled"
    /// "Backup is disabled"
    public static var state_backup_disabled_title: String { localized(key: "state_backup_disabled_title") }

    /// "Text shown when user enable cellular"
    /// "Photos backup is now allowed also on mobile data"
    public static var state_cellular_is_enabled: String { localized(key: "state_cellular_is_enabled") }

    /// "Banner text on the state banner when device doesn\'t have connection"
    /// "No internet connection"
    public static var state_disconnection_title: String { localized(key: "state_disconnection_title") }

    /// "Banner text on the state banner"
    /// "Your Drive storage is full"
    public static var state_drive_storage_full: String { localized(key: "state_drive_storage_full") }

    /// "Text shown on the state banner"
    /// "Encrypting..."
    public static var state_encrypting: String { localized(key: "state_encrypting") }

    /// "Banner text on the state banner when backup issues detected "
    /// "Backup: issues detected"
    public static var state_issues_detected_title: String { localized(key: "state_issues_detected_title") }

    /// "Banner text on the state banner"
    /// "Your Mail storage is full"
    public static var state_mail_storage_full: String { localized(key: "state_mail_storage_full") }

    /// "To send or receive emails, free up space or upgrade for more storage."
    public static var state_mail_storage_full_desc: String { localized(key: "state_mail_storage_full_desc") }

    /// "Banner text on the state banner when device doesn\'t connect to wifi"
    /// "Wi-Fi needed for backup"
    public static var state_need_wifi_title: String { localized(key: "state_need_wifi_title") }

    /// "Banner text on the state banner when lacking permission to access photos"
    /// "Permission required for backup"
    public static var state_permission_required_title: String { localized(key: "state_permission_required_title") }

    /// "Getting ready to back up"
    public static var state_ready_title: String { localized(key: "state_ready_title") }

    /// "Button text on the state banner for retrying the backup"
    /// "Retry"
    public static var state_retry_button: String { localized(key: "state_retry_button") }

    /// "Button text on the state banner for opening permission settings"
    /// "Settings"
    public static var state_settings_button: String { localized(key: "state_settings_button") }

    /// "Banner text on the state banner "
    /// "Your storage is full"
    public static var state_storage_full: String { localized(key: "state_storage_full") }

    /// "To upload files, free up space or upgrade for more storage."
    public static var state_storage_full_desc: String { localized(key: "state_storage_full_desc") }

    /// "Banner text on the state banner when storage full"
    /// "Device storage full"
    public static var state_storage_full_title: String { localized(key: "state_storage_full_title") }

    /// "Banner text on the state banner to indicate subscription is expired"
    /// "Your subscription has ended"
    public static var state_subscription_has_ended: String { localized(key: "state_subscription_has_ended") }

    /// "Upgrade to restore full access and to avoid data loss."
    public static var state_subscription_has_ended_desc: String { localized(key: "state_subscription_has_ended_desc") }

    /// "Banner text on the state banner when backend has problems "
    /// "The upload of photos is temporarily unavailable"
    public static var state_temp_unavailable_title: String { localized(key: "state_temp_unavailable_title") }

    /// "Button text on the state banner for turning on backup"
    /// "Turn on"
    public static var state_turnOn_button: String { localized(key: "state_turnOn_button") }

    /// "Button text on the state banner for enabling cellular"
    /// "Use Cellular"
    public static var state_use_cellular_button: String { localized(key: "state_use_cellular_button") }

    /// "Alert message"
    /// "This will delete the link and remove access to your file or folder for anyone with the link. You can’t undo this action."
    public static var stop_sharing_alert_message: String { localized(key: "stop_sharing_alert_message") }

    /// "Alert title"
    /// "Stop sharing"
    public static var stop_sharing_alert_title: String { localized(key: "stop_sharing_alert_title") }

    /// "Banner text"
    /// "Sharing removed"
    public static var stop_sharing_success_text: String { localized(key: "stop_sharing_success_text") }

    /// "Tab bar title"
    /// "Files"
    public static var tab_bar_title_files: String { localized(key: "tab_bar_title_files") }

    /// "Tab bar title"
    /// "Photos"
    public static var tab_bar_title_photos: String { localized(key: "tab_bar_title_photos") }

    /// "Tab bar title"
    /// "Shared"
    public static var tab_bar_title_shared: String { localized(key: "tab_bar_title_shared") }

    /// "Tab bar title"
    /// "Shared with me"
    public static var tab_bar_title_shared_with_me: String { localized(key: "tab_bar_title_shared_with_me") }

    /// "Button for creating new photo"
    /// "Take new photo"
    public static var take_new_photo_button: String { localized(key: "take_new_photo_button") }

    /// "label text"
    /// "Something gone wrong, please try again later"
    public static var technical_error_placeholder: String { localized(key: "technical_error_placeholder") }

    /// "Button title for deleting item. e.g. Delete file, Delete item, Delete folder..etc"
    /// "Delete %@"
    public static func trash_action_delete_file_button(type: String) -> String { String(format: localized(key: "trash_action_delete_file_button"), type) }

    /// "Alert title shown when user attempts to delete file"
    /// "%@ will be deleted permanently.\nDelete anyway?"
    public static func trash_action_delete_permanently_confirmation_title(type: String) -> String { String(format: localized(key: "trash_action_delete_permanently_confirmation_title"), type) }

    /// "Button title"
    /// "Empty trash"
    public static var trash_action_empty_trash: String { localized(key: "trash_action_empty_trash") }

    /// "The type will be specified afterwards, e.g., \'Restore file,\' \'Restore 2 folders,\' etc."
    /// "Restore %@"
    public static func trash_action_restore(type: String) -> String { String(format: localized(key: "trash_action_restore"), type) }

    /// "Action to restore all trashed files"
    /// "Restore all files"
    public static var trash_action_restore_all_files: String { localized(key: "trash_action_restore_all_files") }

    /// "Action to restore all trashed files"
    /// "Restore all folders"
    public static var trash_action_restore_all_folders: String { localized(key: "trash_action_restore_all_folders") }

    /// "Action to restore all trashed items"
    /// "Restore all items"
    public static var trash_action_restore_all_items: String { localized(key: "trash_action_restore_all_items") }

    /// "The type will be specified afterwards, e.g., \'Restore selected 2 files,\' \'Restore selected 1 folder,\' etc."
    /// "Restore selected %@"
    public static func trash_action_restore_selected(type: String) -> String { String(format: localized(key: "trash_action_restore_selected"), type) }

    /// "Message of the empty trash screen"
    /// "Items moved to the trash will stay here until deleted"
    public static var trash_empty_message: String { localized(key: "trash_empty_message") }

    /// "Title of the share folder when no items are trashed"
    /// "Trash is empty"
    public static var trash_empty_title: String { localized(key: "trash_empty_title") }

    /// "View title shown on unlock app page "
    /// "Unlock App"
    public static var unlock_app_title: String { localized(key: "unlock_app_title") }

    /// "Information text shown when user uploading files"
    /// "For uninterrupted uploads, keep the app open. Uploads will pause when the app is in the background."
    public static var upload_disclaimer: String { localized(key: "upload_disclaimer") }

    /// "Button for uploading new photo"
    /// "Upload a photo"
    public static var upload_photo_button: String { localized(key: "upload_photo_button") }

}