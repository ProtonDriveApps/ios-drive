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

#if os(iOS)

import Foundation

// We enable languages that have been translated for over 95%.
// In `PDLocalization/Resources/Localizable.xcstrings`

// To add/ remove new languages
// Update `ProtonDrive-iOS > PROJECT > Localizations`
// If you are adding new language
// Also need to update `ProtonDrive-iOS/ProtonDrive/Localizable`
// The new language must include at least one placeholder in order to appear in the list.

public class Localization {
    public static var isUITest = false
    public static var bundlePreferredLocalization: String? { Bundle.main.preferredLocalizations.first }
    private static let defaultLanguage = "en"
    public static let bundle: Bundle = {
        if isUITest {
            return enBundle
        }
        let preferredLanguage = Bundle.main.preferredLocalizations.first ?? defaultLanguage
        let main: Bundle = .module
        guard
            let path = main.path(forResource: preferredLanguage, ofType: "lproj"),
            let bundle = Bundle(path: path)
        else { return enBundle }
        return bundle
    }()
    
    private static let enBundle: Bundle = {
        let main: Bundle = .module
        guard
            let path = main.path(forResource: defaultLanguage, ofType: "lproj"),
            let bundle = Bundle(path: path)
        else { return main }
        return bundle
    }()
    
    static func localized(key: String, table: String) -> String {
        let str = String(localized: .init(key), table: table, bundle: bundle)
        if str == key {
            return String(localized: .init(key), table: table, bundle: enBundle)
        } else {
            return str
        }
    }
    /// "Show action menu for this file use for accessibility"
    /// "Open action menu for %@"
    public static func accessibility_more_menu_action(fileName: String) -> String { String(format: localized(key: "accessibility_more_menu_action", table: "iOS-Localizable"), fileName) }

    /// "Accessibility label to open file"
    /// "Open %@"
    public static func accessibility_open_file(fileName: String) -> String { String(format: localized(key: "accessibility_open_file", table: "iOS-Localizable"), fileName) }

    /// "Alert title"
    /// "Account Deletion Error"
    public static var account_deletion_alert_title: String { localized(key: "account_deletion_alert_title", table: "iOS-Localizable") }

    /// "Alert message shown when user trying to trash files"
    /// "Are you sure you want to move this file to Trash?"
    public static func action_trash_files_alert_message(num: Int) -> String { String(format: localized(key: "action_trash_files_alert_message", table: "iOS-Localizable"), num) }

    /// "Alert message shown when user trying to trash folders"
    /// "Are you sure you want to move this folder to Trash?"
    public static func action_trash_folders_alert_message(num: Int) -> String { String(format: localized(key: "action_trash_folders_alert_message", table: "iOS-Localizable"), num) }

    /// "Alert message shown when user trying to trash items"
    /// "Are you sure you want to move this item to Trash?"
    public static func action_trash_items_alert_message(num: Int) -> String { String(format: localized(key: "action_trash_items_alert_message", table: "iOS-Localizable"), num) }

    /// "Message shown in album without photos"
    /// "Photos that you or other members add will appear here"
    public static var album_empty_photo_desc: String { localized(key: "album_empty_photo_desc", table: "iOS-Localizable") }

    /// "Title of notification banner for new invitations"
    /// "New album Invitation"
    public static var album_invitations_banner_text: String { localized(key: "album_invitations_banner_text", table: "iOS-Localizable") }

    /// "Title of screen with invitations to shared albums"
    /// "Album invitations"
    public static var album_invitations_screen_title: String { localized(key: "album_invitations_screen_title", table: "iOS-Localizable") }

    /// "Description of shared album"
    /// "My shared album"
    public static var album_type_shared_by_me: String { localized(key: "album_type_shared_by_me", table: "iOS-Localizable") }

    /// "Description of shared with me album"
    /// "Shared with me"
    public static var album_type_shared_with_me: String { localized(key: "album_type_shared_with_me", table: "iOS-Localizable") }

    /// "Title of button for invitations status"
    /// "10+ albums shared with you"
    public static var albums_pending_invitations_many_title: String { localized(key: "albums_pending_invitations_many_title", table: "iOS-Localizable") }

    /// "Title of button for invitations status (explicit number)"
    /// "%d album shared with you"
    public static func albums_pending_invitations_specific_title(count: Int) -> String { String(format: localized(key: "albums_pending_invitations_specific_title", table: "iOS-Localizable"), count) }

    /// "Button to export all logs "
    /// "All logs"
    public static var all_logs_button: String { localized(key: "all_logs_button", table: "iOS-Localizable") }

    /// "Text shown on the welcome page when user is not logged in "
    /// "The convenience of cloud storage and the security of encryption technology. Finally a cloud storage solution you can trust."
    public static var authentication_welcome_text: String { localized(key: "authentication_welcome_text", table: "iOS-Localizable") }

    /// "Enable auto lock when app is launched "
    /// "After launch"
    public static var auto_lock_timeout_after_launch: String { localized(key: "auto_lock_timeout_after_launch", table: "iOS-Localizable") }

    /// "Always enable auto lock"
    /// "Always"
    public static var auto_lock_timeout_always: String { localized(key: "auto_lock_timeout_always", table: "iOS-Localizable") }

    /// "Text to indicate downloading"
    /// "Downloading files..."
    public static var available_offline_downloading_files: String { localized(key: "available_offline_downloading_files", table: "iOS-Localizable") }

    /// "Message of the available offline page when no items are available"
    /// "Tap “Make available offline” in a file’s or folder’s menu to access it without internet connection."
    public static var available_offline_empty_message: String { localized(key: "available_offline_empty_message", table: "iOS-Localizable") }

    /// "Title of the available offline page when no items are available"
    /// "No offline files or folders"
    public static var available_offline_empty_title: String { localized(key: "available_offline_empty_title", table: "iOS-Localizable") }

    /// "Title of available offline page"
    /// "Available offline"
    public static var available_offline_title: String { localized(key: "available_offline_title", table: "iOS-Localizable") }

    /// "Alert action for clearing locally cached files in the app"
    /// "Clear content cache"
    public static var cached_clear_content_action: String { localized(key: "cached_clear_content_action", table: "iOS-Localizable") }

    /// "Alert message for clearing locally cached files in the app"
    /// "Are you sure you want to clear content cache? This will also remove your offline available content."
    public static var cached_clear_content_message: String { localized(key: "cached_clear_content_message", table: "iOS-Localizable") }

    /// "Alert title for clearing locally cached files in the app"
    /// "Clear content cache"
    public static var cached_clear_content_title: String { localized(key: "cached_clear_content_title", table: "iOS-Localizable") }

    /// "Alert message displayed when required permissions are missing."
    /// "Change app permissions in Settings"
    public static var camera_permission_alert_message: String { localized(key: "camera_permission_alert_message", table: "iOS-Localizable") }

    /// "Alert title displayed when required permission is missing"
    /// "“ProtonDrive” Would Like to Access the Camera"
    public static var camera_permission_alert_title: String { localized(key: "camera_permission_alert_title", table: "iOS-Localizable") }

    /// "Sign in at [account.proton.me](https://account.proton.me/u/0/settings/recovery), then go to Settings --> Recovery."
    public static var checklist_recovery_description: String { localized(key: "checklist_recovery_description", table: "iOS-Localizable") }

    /// "Set a recovery method"
    public static var checklist_recovery_title: String { localized(key: "checklist_recovery_title", table: "iOS-Localizable") }

    /// "Select a file, folder, or album to share directly or with a link."
    public static var checklist_share_description: String { localized(key: "checklist_share_description", table: "iOS-Localizable") }

    /// "Share an item"
    public static var checklist_share_title: String { localized(key: "checklist_share_title", table: "iOS-Localizable") }

    /// "All your files will be encrypted."
    public static var checklist_upload_description: String { localized(key: "checklist_upload_description", table: "iOS-Localizable") }

    /// "Upload a file OR enable photo backup"
    public static var checklist_upload_title: String { localized(key: "checklist_upload_title", table: "iOS-Localizable") }

    /// "Computer details"
    public static var computer_details_title: String { localized(key: "computer_details_title", table: "iOS-Localizable") }

    /// "Created"
    public static var computers_details_created: String { localized(key: "computers_details_created", table: "iOS-Localizable") }

    /// "Created by"
    public static var computers_details_creator: String { localized(key: "computers_details_creator", table: "iOS-Localizable") }

    /// "Computer name"
    public static var computers_details_name: String { localized(key: "computers_details_name", table: "iOS-Localizable") }

    /// "Get the Desktop App to sync folders"
    public static var computers_empty_message: String { localized(key: "computers_empty_message", table: "iOS-Localizable") }

    /// "No computers syncing"
    public static var computers_empty_title: String { localized(key: "computers_empty_title", table: "iOS-Localizable") }

    /// "Unable to create folder here. To add a new folder, open the desktop app."
    public static var computers_error_new_folder: String { localized(key: "computers_error_new_folder", table: "iOS-Localizable") }

    /// "Details"
    public static var computers_menu_details: String { localized(key: "computers_menu_details", table: "iOS-Localizable") }

    /// "Remove Computer"
    public static var computers_menu_remove: String { localized(key: "computers_menu_remove", table: "iOS-Localizable") }

    /// "Rename"
    public static var computers_menu_rename: String { localized(key: "computers_menu_rename", table: "iOS-Localizable") }

    /// "Cancel"
    public static var computers_remove_computer_cancel_button: String { localized(key: "computers_remove_computer_cancel_button", table: "iOS-Localizable") }

    /// "Remove computer"
    public static var computers_remove_computer_remove_button: String { localized(key: "computers_remove_computer_remove_button", table: "iOS-Localizable") }

    /// "Are you sure you want to remove computer?"
    public static var computers_remove_computer_remove_message: String { localized(key: "computers_remove_computer_remove_message", table: "iOS-Localizable") }

    /// "Computers"
    public static var computers_screen_title: String { localized(key: "computers_screen_title", table: "iOS-Localizable") }

    /// "Tabbar item for Computers"
    /// "Computers"
    public static var computers_tab_buttonTittle: String { localized(key: "computers_tab_buttonTittle", table: "iOS-Localizable") }

    /// "Error message"
    /// "Unable to fetch contacts. Please check your network connection and try again."
    public static var contact_error_unable_to_fetch: String { localized(key: "contact_error_unable_to_fetch", table: "iOS-Localizable") }

    /// "Button for creating new document"
    /// "Create document"
    public static var create_document_button: String { localized(key: "create_document_button", table: "iOS-Localizable") }

    /// "Generic document creation error alert"
    /// "Failed to create new document. Please try again later."
    public static var create_document_error: String { localized(key: "create_document_error", table: "iOS-Localizable") }

    /// "Placeholder of document name"
    /// "Document name"
    public static var create_document_placeholder: String { localized(key: "create_document_placeholder", table: "iOS-Localizable") }

    /// "View title"
    /// "Create document"
    public static var create_document_title: String { localized(key: "create_document_title", table: "iOS-Localizable") }

    /// "Placeholder of folder name"
    /// "Folder name"
    public static var create_folder_placeholder: String { localized(key: "create_folder_placeholder", table: "iOS-Localizable") }

    /// "View title"
    /// "Create folder"
    public static var create_folder_title: String { localized(key: "create_folder_title", table: "iOS-Localizable") }

    /// "Button for creating new sheet"
    /// "Create spreadsheet"
    public static var create_sheet_button: String { localized(key: "create_sheet_button", table: "iOS-Localizable") }

    /// "Creating new document loading state"
    /// "Creating new document"
    public static var creating_new_document: String { localized(key: "creating_new_document", table: "iOS-Localizable") }

    /// "Creating new sheet loading state"
    /// "Creating new spreadsheet"
    public static var creating_new_sheet: String { localized(key: "creating_new_sheet", table: "iOS-Localizable") }

    /// "Title of setting action sheet"
    /// "Choose the screen opens by default"
    public static var default_home_tab_setting_sheet_title: String { localized(key: "default_home_tab_setting_sheet_title", table: "iOS-Localizable") }

    /// "View title"
    /// "Default home tab"
    public static var default_home_tab_title: String { localized(key: "default_home_tab_title", table: "iOS-Localizable") }

    /// "Message shown in the folder view when device is disconnected"
    /// "We cannot read contents of this folder"
    public static var disconnection_folder_message: String { localized(key: "disconnection_folder_message", table: "iOS-Localizable") }

    /// "Action title to apply selected action to all duplicated items "
    /// "Apply to all duplicates"
    public static var duplication_handler_action_apply_all: String { localized(key: "duplication_handler_action_apply_all", table: "iOS-Localizable") }

    /// "Action description"
    /// "Keep both items"
    public static var duplication_handler_action_desc_keep_both: String { localized(key: "duplication_handler_action_desc_keep_both", table: "iOS-Localizable") }

    /// "Action description"
    /// "Replace the existing item with the new one"
    public static var duplication_handler_action_desc_replace: String { localized(key: "duplication_handler_action_desc_replace", table: "iOS-Localizable") }

    /// "Action description"
    /// "Don’t upload this item"
    public static var duplication_handler_action_desc_skip: String { localized(key: "duplication_handler_action_desc_skip", table: "iOS-Localizable") }

    /// "Action for moving to the next duplicated item"
    /// "Continue"
    public static var duplication_handler_action_title_continue: String { localized(key: "duplication_handler_action_title_continue", table: "iOS-Localizable") }

    /// "Action title for keeping existing and new item"
    /// "Keep Both"
    public static var duplication_handler_action_title_keep_both: String { localized(key: "duplication_handler_action_title_keep_both", table: "iOS-Localizable") }

    /// "Action title for replacing an existing item with a new one"
    /// "Replace"
    public static var duplication_handler_action_title_replace: String { localized(key: "duplication_handler_action_title_replace", table: "iOS-Localizable") }

    /// "Action title for stopping upload new item"
    /// "Skip"
    public static var duplication_handler_action_title_skip: String { localized(key: "duplication_handler_action_title_skip", table: "iOS-Localizable") }

    /// "Action sheet subtitle"
    /// "An item named %1$(filename)@ already exists in this location"
    public static func duplication_handler_view_subtitle(filename: String) -> String { String(format: localized(key: "duplication_handler_view_subtitle", table: "iOS-Localizable"), filename) }

    /// "Action sheet title"
    /// "Duplicate found"
    public static var duplication_handler_view_title: String { localized(key: "duplication_handler_view_title", table: "iOS-Localizable") }

    /// "Placeholder of date picker"
    /// "Date"
    public static var edit_link_placeholder_date_picker: String { localized(key: "edit_link_placeholder_date_picker", table: "iOS-Localizable") }

    /// "Placeholder of password configuration"
    /// "Set password"
    public static var edit_link_placeholder_password: String { localized(key: "edit_link_placeholder_password", table: "iOS-Localizable") }

    /// "Section title"
    /// "Privacy settings"
    public static var edit_link_section_title: String { localized(key: "edit_link_section_title", table: "iOS-Localizable") }

    /// "Banner text shown after saving change"
    /// "Link settings updated"
    public static var edit_link_settings_updated: String { localized(key: "edit_link_settings_updated", table: "iOS-Localizable") }

    /// "Expiration Date configuration"
    /// "Set expiration date"
    public static var edit_link_title_expiration_date: String { localized(key: "edit_link_title_expiration_date", table: "iOS-Localizable") }

    /// "Password configuration"
    /// "Require password"
    public static var edit_link_title_password: String { localized(key: "edit_link_title_password", table: "iOS-Localizable") }

    /// "Rename computer"
    public static var edit_node_title_rename_computer: String { localized(key: "edit_node_title_rename_computer", table: "iOS-Localizable") }

    /// "Rename file"
    public static var edit_node_title_rename_file: String { localized(key: "edit_node_title_rename_file", table: "iOS-Localizable") }

    /// "Rename folder"
    public static var edit_node_title_rename_folder: String { localized(key: "edit_node_title_rename_folder", table: "iOS-Localizable") }

    /// "Button to copy the URL of a Bookmark"
    /// "Copy link"
    public static var edit_section_copy_link_bookmark: String { localized(key: "edit_section_copy_link_bookmark", table: "iOS-Localizable") }

    /// "Button to mark as available offline"
    /// "Make available offline"
    public static var edit_section_make_available_offline: String { localized(key: "edit_section_make_available_offline", table: "iOS-Localizable") }

    /// "Button to move an item"
    /// "Move to..."
    public static var edit_section_move_to: String { localized(key: "edit_section_move_to", table: "iOS-Localizable") }

    /// "Button to open document in browser"
    /// "Open in browser"
    public static var edit_section_open_in_browser: String { localized(key: "edit_section_open_in_browser", table: "iOS-Localizable") }

    /// "Button to move item to trash"
    /// "Move to trash"
    public static var edit_section_remove: String { localized(key: "edit_section_remove", table: "iOS-Localizable") }

    /// "Button to remove a bookmark"
    /// "Remove"
    public static var edit_section_remove_bookmark: String { localized(key: "edit_section_remove_bookmark", table: "iOS-Localizable") }

    /// "Button to remove from available offline"
    /// "Remove from available offline"
    public static var edit_section_remove_from_available_offline: String { localized(key: "edit_section_remove_from_available_offline", table: "iOS-Localizable") }

    /// "Button to remove me from shared file or folder"
    /// "Remove me"
    public static var edit_section_remove_me: String { localized(key: "edit_section_remove_me", table: "iOS-Localizable") }

    /// "Button to open share via link"
    /// "Share via link"
    public static var edit_section_share_via_link: String { localized(key: "edit_section_share_via_link", table: "iOS-Localizable") }

    /// "Button to open sharing options"
    /// "Sharing options"
    public static var edit_section_sharing_options: String { localized(key: "edit_section_sharing_options", table: "iOS-Localizable") }

    /// "Show file details button"
    /// "Show file details"
    public static var edit_section_show_file_details: String { localized(key: "edit_section_show_file_details", table: "iOS-Localizable") }

    /// "Button to show folder details"
    /// "Show folder details"
    public static var edit_section_show_folder_details: String { localized(key: "edit_section_show_folder_details", table: "iOS-Localizable") }

    /// "Action title shown in empty albums gallery"
    /// "Create album"
    public static var empty_albums_action: String { localized(key: "empty_albums_action", table: "iOS-Localizable") }

    /// "Message shown in empty albums gallery"
    /// "Albums that you create or join will appear here."
    public static var empty_albums_message: String { localized(key: "empty_albums_message", table: "iOS-Localizable") }

    /// "Title shown in empty albums gallery"
    /// "No albums"
    public static var empty_albums_title: String { localized(key: "empty_albums_title", table: "iOS-Localizable") }

    /// "Message shown in empty photos gallery"
    /// "Your photo bursts will appear here"
    public static var empty_bursts_message: String { localized(key: "empty_bursts_message", table: "iOS-Localizable") }

    /// "Title shown in empty photos gallery"
    /// "No bursts"
    public static var empty_bursts_title: String { localized(key: "empty_bursts_title", table: "iOS-Localizable") }

    /// "Folders you sync from computer will appear here"
    public static var empty_computer_root_folder_message: String { localized(key: "empty_computer_root_folder_message", table: "iOS-Localizable") }

    /// "No synced folders"
    public static var empty_computer_root_folder_title: String { localized(key: "empty_computer_root_folder_title", table: "iOS-Localizable") }

    /// "Message shown in empty photos gallery"
    /// "Your favorited photos will appear here"
    public static var empty_favorites_message: String { localized(key: "empty_favorites_message", table: "iOS-Localizable") }

    /// "Title shown in empty photos gallery"
    /// "No favorites"
    public static var empty_favorites_title: String { localized(key: "empty_favorites_title", table: "iOS-Localizable") }

    /// "Message shown in the empty folder view"
    /// "Tap the + button to upload files or create something new"
    public static var empty_folder_message: String { localized(key: "empty_folder_message", table: "iOS-Localizable") }

    /// "Title shown in the empty folder view"
    /// "Folder is empty"
    public static var empty_folder_title: String { localized(key: "empty_folder_title", table: "iOS-Localizable") }

    /// "Message shown in empty photos gallery"
    /// "Your Live Photos will appear here"
    public static var empty_live_photo_message: String { localized(key: "empty_live_photo_message", table: "iOS-Localizable") }

    /// "Title shown in empty photos gallery"
    /// "No Live Photos"
    public static var empty_live_photo_title: String { localized(key: "empty_live_photo_title", table: "iOS-Localizable") }

    /// "Message shown in empty albums gallery"
    /// "The albums that you create will appear here"
    public static var empty_my_albums_message: String { localized(key: "empty_my_albums_message", table: "iOS-Localizable") }

    /// "Message shown in empty photos gallery"
    /// "Your panorama photos will appear here"
    public static var empty_panoramas_message: String { localized(key: "empty_panoramas_message", table: "iOS-Localizable") }

    /// "Title shown in empty photos gallery"
    /// "No panoramas"
    public static var empty_panoramas_title: String { localized(key: "empty_panoramas_title", table: "iOS-Localizable") }

    /// "Title shown in empty photos gallery"
    /// "No photos"
    public static var empty_photos_title: String { localized(key: "empty_photos_title", table: "iOS-Localizable") }

    /// "Message shown in empty photos gallery"
    /// "Your portrait photos will appear here"
    public static var empty_portraits_message: String { localized(key: "empty_portraits_message", table: "iOS-Localizable") }

    /// "Title shown in empty photos gallery"
    /// "No portraits"
    public static var empty_portraits_title: String { localized(key: "empty_portraits_title", table: "iOS-Localizable") }

    /// "Message shown in empty photos gallery"
    /// "Your RAW photos will appear here"
    public static var empty_raw_message: String { localized(key: "empty_raw_message", table: "iOS-Localizable") }

    /// "Title shown in empty photos gallery"
    /// "No RAW"
    public static var empty_raw_title: String { localized(key: "empty_raw_title", table: "iOS-Localizable") }

    /// "Message shown in empty photos gallery"
    /// "Your screenshots will appear here"
    public static var empty_screenshots_message: String { localized(key: "empty_screenshots_message", table: "iOS-Localizable") }

    /// "Title shown in empty photos gallery"
    /// "No screenshots"
    public static var empty_screenshots_title: String { localized(key: "empty_screenshots_title", table: "iOS-Localizable") }

    /// "Message shown in empty photos gallery"
    /// "Your selfies will appear here"
    public static var empty_selfie_message: String { localized(key: "empty_selfie_message", table: "iOS-Localizable") }

    /// "Title shown in empty photos gallery"
    /// "No selfies"
    public static var empty_selfie_title: String { localized(key: "empty_selfie_title", table: "iOS-Localizable") }

    /// "Message shown in empty shared albums gallery"
    /// "Albums you\'ve shared will appear here"
    public static var empty_shared_album_message: String { localized(key: "empty_shared_album_message", table: "iOS-Localizable") }

    /// "Title shown in empty shared albums gallery"
    /// "No shared albums"
    public static var empty_shared_album_title: String { localized(key: "empty_shared_album_title", table: "iOS-Localizable") }

    /// "Message shown in empty shared with me album gallery"
    /// "Albums shared with you will appear here"
    public static var empty_shared_with_me_albums_message: String { localized(key: "empty_shared_with_me_albums_message", table: "iOS-Localizable") }

    /// "Title shown in empty albums gallery for shared with me tab"
    /// "No albums shared with me"
    public static var empty_shared_with_me_albums_title: String { localized(key: "empty_shared_with_me_albums_title", table: "iOS-Localizable") }

    /// "Message shown in empty photos gallery"
    /// "Your videos will appear here"
    public static var empty_videos_message: String { localized(key: "empty_videos_message", table: "iOS-Localizable") }

    /// "Title shown in empty photos gallery"
    /// "No videos"
    public static var empty_videos_title: String { localized(key: "empty_videos_title", table: "iOS-Localizable") }

    /// "Result of \"mark photo favorite\" action - photo have been copied to stream."
    /// "One photo was copied to stream and marked favorite there."
    public static func favoriting_result_copied(count: Int) -> String { String(format: localized(key: "favoriting_result_copied", table: "iOS-Localizable"), count) }

    /// "Successful result of \"mark photo favorite\""
    /// "One photo was marked as favorite."
    public static func favoriting_result_marked(count: Int) -> String { String(format: localized(key: "favoriting_result_marked", table: "iOS-Localizable"), count) }

    /// "Result of \"mark photo favorite\" action - skipping the photo/s."
    /// "One photo is already in your stream. Please mark it favorite there."
    public static func favoriting_result_skipped(count: Int) -> String { String(format: localized(key: "favoriting_result_skipped", table: "iOS-Localizable"), count) }

    /// "Result of \"unmark photo favorite\""
    /// "Unmarked one photo as favorite."
    public static func favoriting_result_unmarked(count: Int) -> String { String(format: localized(key: "favoriting_result_unmarked", table: "iOS-Localizable"), count) }

    /// "Text displayed on the file detail view to indicate the file extension"
    /// "Extension"
    public static var file_detail_extension: String { localized(key: "file_detail_extension", table: "iOS-Localizable") }

    /// "View title displayed on the file detail view when we can\'t recognize file type"
    /// "Details"
    public static var file_detail_general_title: String { localized(key: "file_detail_general_title", table: "iOS-Localizable") }

    /// "Text displayed on the file detail view to indicate the file path"
    /// "Location"
    public static var file_detail_location: String { localized(key: "file_detail_location", table: "iOS-Localizable") }

    /// "Text displayed on the file detail view to indicate the file modificated date"
    /// "Modified"
    public static var file_detail_modified: String { localized(key: "file_detail_modified", table: "iOS-Localizable") }

    /// "Text displayed on the file detail view to indicate the file name"
    /// "Name"
    public static var file_detail_name: String { localized(key: "file_detail_name", table: "iOS-Localizable") }

    /// "Text displayed on the file detail view to indicate the file is not sharing"
    /// "No"
    public static var file_detail_share_no: String { localized(key: "file_detail_share_no", table: "iOS-Localizable") }

    /// "Text displayed on the file detail view to indicate the file is sharing"
    /// "Yes"
    public static var file_detail_share_yes: String { localized(key: "file_detail_share_yes", table: "iOS-Localizable") }

    /// "Text displayed on the file detail view to indicate the file share status"
    /// "Shared"
    public static var file_detail_shared: String { localized(key: "file_detail_shared", table: "iOS-Localizable") }

    /// "Text displayed on the file detail view to indicate the file size"
    /// "Size"
    public static var file_detail_size: String { localized(key: "file_detail_size", table: "iOS-Localizable") }

    /// "Subtitle for file to represent file size and last modified date"
    /// "%@ | Moments ago"
    public static func file_detail_subtitle_moments_ago(size: String) -> String { String(format: localized(key: "file_detail_subtitle_moments_ago", table: "iOS-Localizable"), size) }

    /// "View title"
    /// "File details"
    public static var file_detail_title: String { localized(key: "file_detail_title", table: "iOS-Localizable") }

    /// "Text displayed on the file detail view to show who uploaded the file"
    /// "Uploaded by"
    public static var file_detail_uploaded_by: String { localized(key: "file_detail_uploaded_by", table: "iOS-Localizable") }

    /// "Indicate the file is uploaded by anonymous user"
    /// "Anonymous"
    public static var file_detail_uploaded_by_anonymous: String { localized(key: "file_detail_uploaded_by_anonymous", table: "iOS-Localizable") }

    /// "e.g. Failed to import 3 files: access denied"
    /// "Failed to import %@: %@"
    public static func file_pickup_error(files: String, error: String) -> String { String(format: localized(key: "file_pickup_error", table: "iOS-Localizable"), files, error) }

    /// "An error that occurs when the user tries to upload an unsupported file type"
    /// "The file type ”%@” is not supported"
    public static func file_pickup_unsupported(fileExtension: String) -> String { String(format: localized(key: "file_pickup_unsupported", table: "iOS-Localizable"), fileExtension) }

    /// "Concat with other string, e.g. Restore 4 files, Delete 1 file"
    /// "%d File"
    public static func file_plural_type_with_num(num: Int) -> String { String(format: localized(key: "file_plural_type_with_num", table: "iOS-Localizable"), num) }

    /// "Alert message shown when user try to open file provider when app is not logged in "
    /// "Please open the Proton Drive app to sign in to continue"
    public static var file_provider_signIn_alert_message: String { localized(key: "file_provider_signIn_alert_message", table: "iOS-Localizable") }

    /// "Alert title shown when user try to open file provider when app is not logged in "
    /// "Sign In to Proton Drive"
    public static var file_provider_signIn_alert_title: String { localized(key: "file_provider_signIn_alert_title", table: "iOS-Localizable") }

    /// "Alert message shown when user try to open file provider when app is locked"
    /// "While PIN or Face ID/Touch ID are enabled on Proton Drive the content is not accessible in Files"
    public static var file_provider_unlock_alert_message: String { localized(key: "file_provider_unlock_alert_message", table: "iOS-Localizable") }

    /// "Alert title shown when user try to open file provider when app is locked"
    /// "Proton Drive is Locked"
    public static var file_provider_unlock_alert_title: String { localized(key: "file_provider_unlock_alert_title", table: "iOS-Localizable") }

    /// "Notification text when files upload failed"
    /// "Some files didn’t upload. Try uploading them again."
    public static var file_upload_failed_notification: String { localized(key: "file_upload_failed_notification", table: "iOS-Localizable") }

    /// "Notification text when files upload paused"
    /// "File upload paused. Open the app to resume."
    public static var file_upload_paused_notification: String { localized(key: "file_upload_paused_notification", table: "iOS-Localizable") }

    /// "Alert text"
    /// "Failed to upload %d file"
    public static func file_upload_status_failed_message(failedUploads: Int) -> String { String(format: localized(key: "file_upload_status_failed_message", table: "iOS-Localizable"), failedUploads) }

    /// "Error text shown on the view when user try to open invalid folder"
    /// "Start Folder with insufficient context"
    public static var finder_coordinator_invalid_folder: String { localized(key: "finder_coordinator_invalid_folder", table: "iOS-Localizable") }

    /// "Error text shown on the view when user try to open move to page for invalid node"
    /// "Called Go-Move with insufficient context"
    public static var finder_coordinator_invalid_go_move: String { localized(key: "finder_coordinator_invalid_go_move", table: "iOS-Localizable") }

    /// "Error text shown on the view when user try to open invalid shared folder"
    /// "Started Shared Folder with insufficient context"
    public static var finder_coordinator_invalid_shared_folder: String { localized(key: "finder_coordinator_invalid_shared_folder", table: "iOS-Localizable") }

    /// "Error text shown on the view when user try to move invalid node"
    /// "Start Move with insufficient context"
    public static var finder_coordinator_move_invalid_node: String { localized(key: "finder_coordinator_move_invalid_node", table: "iOS-Localizable") }

    /// "View title"
    /// "Folder details"
    public static var folder_detail_title: String { localized(key: "folder_detail_title", table: "iOS-Localizable") }

    /// "Concat with other string, e.g. Restore 4 folders, Delete 1 folder"
    /// "%d Folder"
    public static func folder_plural_type_with_num(num: Int) -> String { String(format: localized(key: "folder_plural_type_with_num", table: "iOS-Localizable"), num) }

    /// "Date formate for this month"
    /// "This month"
    public static var format_month_this_month: String { localized(key: "format_month_this_month", table: "iOS-Localizable") }

    /// "Button title, apply change"
    /// "Apply"
    public static var general_apply: String { localized(key: "general_apply", table: "iOS-Localizable") }

    /// "Button title"
    /// "Cancel"
    public static var general_cancel: String { localized(key: "general_cancel", table: "iOS-Localizable") }

    /// "Copy image, text...etc"
    /// "Copy"
    public static var general_copy: String { localized(key: "general_copy", table: "iOS-Localizable") }

    /// "Decrypting..."
    public static var general_decrypting: String { localized(key: "general_decrypting", table: "iOS-Localizable") }

    /// "Decryption failed"
    public static var general_decryption_failed: String { localized(key: "general_decryption_failed", table: "iOS-Localizable") }

    /// "Button title"
    /// "Delete"
    public static var general_delete: String { localized(key: "general_delete", table: "iOS-Localizable") }

    /// "Button to deselect items in the list"
    /// "Deselect all"
    public static var general_deselect_all: String { localized(key: "general_deselect_all", table: "iOS-Localizable") }

    /// "Button title"
    /// "Disable"
    public static var general_disable: String { localized(key: "general_disable", table: "iOS-Localizable") }

    /// "Button to dismiss page, banner..etc"
    /// "Dismiss"
    public static var general_dismiss: String { localized(key: "general_dismiss", table: "iOS-Localizable") }

    /// "Button title"
    /// "Done"
    public static var general_done: String { localized(key: "general_done", table: "iOS-Localizable") }

    /// "Text to indicate a file is downloaded"
    /// "Downloaded"
    public static var general_downloaded: String { localized(key: "general_downloaded", table: "iOS-Localizable") }

    /// "Downloading"
    public static var general_downloading: String { localized(key: "general_downloading", table: "iOS-Localizable") }

    /// "Button title"
    /// "Enable"
    public static var general_enable: String { localized(key: "general_enable", table: "iOS-Localizable") }

    /// "Concat with other string, e.g. Restore file, Delete file"
    /// "File"
    public static var general_file_type: String { localized(key: "general_file_type", table: "iOS-Localizable") }

    /// "Concat with other string, e.g. Restore folder, Delete folder"
    /// "Folder"
    public static var general_folder_type: String { localized(key: "general_folder_type", table: "iOS-Localizable") }

    /// "Get more storage"
    public static var general_get_more_storage: String { localized(key: "general_get_more_storage", table: "iOS-Localizable") }

    /// "Button title"
    /// "Get storage"
    public static var general_get_storage: String { localized(key: "general_get_storage", table: "iOS-Localizable") }

    /// "Button title"
    /// "Go back"
    public static var general_go_back: String { localized(key: "general_go_back", table: "iOS-Localizable") }

    /// "Button title"
    /// "Got it"
    public static var general_got_it: String { localized(key: "general_got_it", table: "iOS-Localizable") }

    /// "Concat with other string, e.g. Restore item, Delete item"
    /// "Item"
    public static var general_item_type: String { localized(key: "general_item_type", table: "iOS-Localizable") }

    /// "Button title"
    /// "Learn more"
    public static var general_learn_more: String { localized(key: "general_learn_more", table: "iOS-Localizable") }

    /// "information text"
    /// "Link copied"
    public static var general_link_copied: String { localized(key: "general_link_copied", table: "iOS-Localizable") }

    /// "Loading..."
    public static var general_loading: String { localized(key: "general_loading", table: "iOS-Localizable") }

    /// "Button title"
    /// "Log out"
    public static var general_logout: String { localized(key: "general_logout", table: "iOS-Localizable") }

    /// "Next button"
    /// "Next"
    public static var general_next: String { localized(key: "general_next", table: "iOS-Localizable") }

    /// "Button title"
    /// "Not now"
    public static var general_not_now: String { localized(key: "general_not_now", table: "iOS-Localizable") }

    /// "Status label text to indicate that the feature is turned off, e.g., Backup: Off"
    /// "Off"
    public static var general_off: String { localized(key: "general_off", table: "iOS-Localizable") }

    /// "Button title"
    /// "OK"
    public static var general_ok: String { localized(key: "general_ok", table: "iOS-Localizable") }

    /// "Status label text to indicate that the feature is turned on, e.g., \'Backup: On."
    /// "On"
    public static var general_on: String { localized(key: "general_on", table: "iOS-Localizable") }

    /// "information text"
    /// "Password copied"
    public static var general_password_copied: String { localized(key: "general_password_copied", table: "iOS-Localizable") }

    /// "action to pause, e.g. pause upload"
    /// "Pause"
    public static var general_pause: String { localized(key: "general_pause", table: "iOS-Localizable") }

    /// "Button to quit application"
    /// "Quit"
    public static var general_quit: String { localized(key: "general_quit", table: "iOS-Localizable") }

    /// "Button title"
    /// "Refresh"
    public static var general_refresh: String { localized(key: "general_refresh", table: "iOS-Localizable") }

    /// "Action to remove items , e.g. remove upload failed file"
    /// "Remove"
    public static var general_remove: String { localized(key: "general_remove", table: "iOS-Localizable") }

    /// "Alert button title"
    /// "Remove file"
    public static func general_remove_files(num: Int) -> String { String(format: localized(key: "general_remove_files", table: "iOS-Localizable"), num) }

    /// "Alert button title"
    /// "Remove folder"
    public static func general_remove_folders(num: Int) -> String { String(format: localized(key: "general_remove_folders", table: "iOS-Localizable"), num) }

    /// "Alert button title"
    /// "Remove item"
    public static func general_remove_items(num: Int) -> String { String(format: localized(key: "general_remove_items", table: "iOS-Localizable"), num) }

    /// "Button title"
    /// "Rename"
    public static var general_rename: String { localized(key: "general_rename", table: "iOS-Localizable") }

    /// "Button title"
    /// "Restore"
    public static var general_restore: String { localized(key: "general_restore", table: "iOS-Localizable") }

    /// "Button to retry action after failing "
    /// "Retry"
    public static var general_retry: String { localized(key: "general_retry", table: "iOS-Localizable") }

    /// "Button title"
    /// "Save"
    public static var general_save: String { localized(key: "general_save", table: "iOS-Localizable") }

    /// "Button title"
    /// "Save all"
    public static var general_save_all: String { localized(key: "general_save_all", table: "iOS-Localizable") }

    /// "Action to select item"
    /// "Select"
    public static var general_select: String { localized(key: "general_select", table: "iOS-Localizable") }

    /// "Button to select all items in the list"
    /// "Select all"
    public static var general_select_all: String { localized(key: "general_select_all", table: "iOS-Localizable") }

    /// "%d selected"
    public static func general_selected(num: Int) -> String { String(format: localized(key: "general_selected", table: "iOS-Localizable"), num) }

    /// "button title"
    /// "Settings"
    public static var general_settings: String { localized(key: "general_settings", table: "iOS-Localizable") }

    /// "Button title"
    /// "Share"
    public static var general_share: String { localized(key: "general_share", table: "iOS-Localizable") }

    /// "Signing out..."
    public static var general_signing_out: String { localized(key: "general_signing_out", table: "iOS-Localizable") }

    /// "button title"
    /// "Skip"
    public static var general_skip: String { localized(key: "general_skip", table: "iOS-Localizable") }

    /// "Syncing"
    public static var general_syncing: String { localized(key: "general_syncing", table: "iOS-Localizable") }

    /// "placeholder"
    /// "Unknown"
    public static var general_unknown: String { localized(key: "general_unknown", table: "iOS-Localizable") }

    /// "Button title, e.g. upgrade plan"
    /// "Upgrade"
    public static var general_upgrade: String { localized(key: "general_upgrade", table: "iOS-Localizable") }

    /// "Button title. for example upload a file"
    /// "Upload"
    public static var general_upload: String { localized(key: "general_upload", table: "iOS-Localizable") }

    /// "Uploading"
    public static var general_uploading: String { localized(key: "general_uploading", table: "iOS-Localizable") }

    /// "Button title"
    /// "View"
    public static var general_view: String { localized(key: "general_view", table: "iOS-Localizable") }

    /// "Button title"
    /// "Remind me later"
    public static var generic_remind_me_later: String { localized(key: "generic_remind_me_later", table: "iOS-Localizable") }

    /// "Button title"
    /// "Start"
    public static var generic_start: String { localized(key: "generic_start", table: "iOS-Localizable") }

    /// "Button for importing new file"
    /// "Import file"
    public static var import_file_button: String { localized(key: "import_file_button", table: "iOS-Localizable") }

    /// "Concat with other string, e.g. Restore 4 items, Delete 1 item"
    /// "%d Item"
    public static func item_plural_type_with_num(num: Int) -> String { String(format: localized(key: "item_plural_type_with_num", table: "iOS-Localizable"), num) }

    /// "Alert title shown when certificate validation failed"
    /// "Disable Validation"
    public static var launch_alert_title_disable_validation: String { localized(key: "launch_alert_title_disable_validation", table: "iOS-Localizable") }

    /// "Alert to user when force update is needed"
    /// "Update"
    public static var launch_alert_title_update: String { localized(key: "launch_alert_title_update", table: "iOS-Localizable") }

    /// "Alert action title when user clicks save and leave album"
    /// "Save and leave"
    public static var leave_album_after_saving: String { localized(key: "leave_album_after_saving", table: "iOS-Localizable") }

    /// "Alert message shown when user clicks leave album"
    /// "You won\'t have access to these photos again unless reshared with you. If you want to keep any photos, save them to your device first."
    public static var leave_album_alert_message: String { localized(key: "leave_album_alert_message", table: "iOS-Localizable") }

    /// "Alert title shown when user clicks leave album"
    /// "Leaving %@"
    public static func leave_album_alert_title(name: String) -> String { String(format: localized(key: "leave_album_alert_title", table: "iOS-Localizable"), name) }

    /// "Alert action title when user clicks leave album"
    /// "Leave"
    public static var leave_album_without_saving_action: String { localized(key: "leave_album_without_saving_action", table: "iOS-Localizable") }

    /// "Banner text"
    /// "The app will keep your screen awake to ensure faster backups."
    public static var locking_banner_message: String { localized(key: "locking_banner_message", table: "iOS-Localizable") }

    /// "Alert action to confirm user wants to clear logs"
    /// "Clear"
    public static var log_clear_alert_action: String { localized(key: "log_clear_alert_action", table: "iOS-Localizable") }

    /// "Alert message to confirm user wants to clear logs"
    /// "Are you sure you want to clear the logs?"
    public static var log_clear_alert_message: String { localized(key: "log_clear_alert_message", table: "iOS-Localizable") }

    /// "Alert title to confirm user wants to clear logs"
    /// "Clear logs"
    public static var log_clear_alert_title: String { localized(key: "log_clear_alert_title", table: "iOS-Localizable") }

    /// "By logging out, all files saved for offline will be deleted from your device"
    public static var logout_alert_message: String { localized(key: "logout_alert_message", table: "iOS-Localizable") }

    /// "Alert title shown when user attempts to logout"
    /// "Are you sure?"
    public static var logout_alert_title: String { localized(key: "logout_alert_title", table: "iOS-Localizable") }

    /// "Placeholder for search field in latest logs"
    /// "Search logs"
    public static var logs_search_placeholder: String { localized(key: "logs_search_placeholder", table: "iOS-Localizable") }

    /// "Side menu section title"
    /// "More"
    public static var menu_section_title_more: String { localized(key: "menu_section_title_more", table: "iOS-Localizable") }

    /// "Side menu section title"
    /// "Storage"
    public static var menu_section_title_storage: String { localized(key: "menu_section_title_storage", table: "iOS-Localizable") }

    /// "Report a problem"
    public static var menu_text_feedback: String { localized(key: "menu_text_feedback", table: "iOS-Localizable") }

    /// "Home"
    public static var menu_text_home: String { localized(key: "menu_text_home", table: "iOS-Localizable") }

    /// "Sign out"
    public static var menu_text_logout: String { localized(key: "menu_text_logout", table: "iOS-Localizable") }

    /// "My files"
    public static var menu_text_my_files: String { localized(key: "menu_text_my_files", table: "iOS-Localizable") }

    /// "Settings"
    public static var menu_text_settings: String { localized(key: "menu_text_settings", table: "iOS-Localizable") }

    /// "Shared by me items"
    /// "Shared by me"
    public static var menu_text_shared_by_me: String { localized(key: "menu_text_shared_by_me", table: "iOS-Localizable") }

    /// "Get your 3 GB storage bonus"
    public static var menu_text_storage_bonus_promo: String { localized(key: "menu_text_storage_bonus_promo", table: "iOS-Localizable") }

    /// "Subscription"
    public static var menu_text_subscription: String { localized(key: "menu_text_subscription", table: "iOS-Localizable") }

    /// "Label text to show total drive storage usage "
    /// "Total usage"
    public static var menu_text_total_usage: String { localized(key: "menu_text_total_usage", table: "iOS-Localizable") }

    /// "Trash"
    public static var menu_text_trash: String { localized(key: "menu_text_trash", table: "iOS-Localizable") }

    /// "Action to download file to device"
    /// "Download"
    public static var more_action_download: String { localized(key: "more_action_download", table: "iOS-Localizable") }

    /// "Action to open file in some app"
    /// "Open in..."
    public static var more_action_open_in: String { localized(key: "more_action_open_in", table: "iOS-Localizable") }

    /// "Button in the move settings to indicate moving the selected file here."
    /// "Move here"
    public static var move_action_move_here: String { localized(key: "move_action_move_here", table: "iOS-Localizable") }

    /// "Document name"
    public static var name_document_placeholder: String { localized(key: "name_document_placeholder", table: "iOS-Localizable") }

    /// "Title view"
    /// "Name your scan"
    public static var name_document_title: String { localized(key: "name_document_title", table: "iOS-Localizable") }

    /// "Name for newly created document, timestamp is dynamic"
    /// "Untitled document %@"
    public static func new_document_title(timestamp: String) -> String { String(format: localized(key: "new_document_title", table: "iOS-Localizable"), timestamp) }

    /// "Message on scan document what\'s new page"
    /// "Convert paper documents into encrypted PDFs.\nTap + in the top-right corner, then select Scan Document."
    public static var new_feature_scanDoc_desc: String { localized(key: "new_feature_scanDoc_desc", table: "iOS-Localizable") }

    /// "Title for scan document what\'s new page"
    /// "Scan documents in one tap"
    public static var new_feature_scanDoc_title: String { localized(key: "new_feature_scanDoc_title", table: "iOS-Localizable") }

    /// "Title for new feature promotion popup"
    /// "What\'s new!"
    public static var new_feature_title: String { localized(key: "new_feature_title", table: "iOS-Localizable") }

    /// "Button to redirect to storage setting page"
    /// "Go to local storage settings"
    public static var no_space_open_storage_setting: String { localized(key: "no_space_open_storage_setting", table: "iOS-Localizable") }

    /// "No space warning"
    /// "Not enough storage space to upload. Please consider upgrading your account or contact our customer support."
    public static var no_space_subtitle_cloud_full: String { localized(key: "no_space_subtitle_cloud_full", table: "iOS-Localizable") }

    /// "No space warning"
    /// "There is not enough storage on your device to download all the files marked as offline available."
    public static var no_space_subtitle_device_full: String { localized(key: "no_space_subtitle_device_full", table: "iOS-Localizable") }

    /// "No space warning"
    /// "Your device is packed."
    public static var no_space_title_device_is_packed: String { localized(key: "no_space_title_device_is_packed", table: "iOS-Localizable") }

    /// "No space warning"
    /// "You reached the limit of your plan."
    public static var no_space_title_limit_of_plan: String { localized(key: "no_space_title_limit_of_plan", table: "iOS-Localizable") }

    /// "Button to expand text view for error deteail"
    /// "Details"
    public static var notification_details: String { localized(key: "notification_details", table: "iOS-Localizable") }

    /// "Error text"
    /// "There is %d issue"
    public static func notification_issues(num: Int) -> String { String(format: localized(key: "notification_issues", table: "iOS-Localizable"), num) }

    /// "Button to turn on notifications."
    /// "Allow notifications"
    public static var notification_permission_enable_button_title: String { localized(key: "notification_permission_enable_button_title", table: "iOS-Localizable") }

    /// "Message shown in the notification popup when files are uploading."
    /// "We’ll notify you if there are any interruptions to your uploads or downloads."
    public static var notification_permission_files_description: String { localized(key: "notification_permission_files_description", table: "iOS-Localizable") }

    /// "Title shown in the notification popup when files are uploading."
    /// "Turn on notifications"
    public static var notification_permission_files_title: String { localized(key: "notification_permission_files_title", table: "iOS-Localizable") }

    /// "Message shown in the notification popup when photos are uploading."
    /// "We’ll only notify you if your action is required to complete backups and uploads."
    public static var notification_permission_photos_description: String { localized(key: "notification_permission_photos_description", table: "iOS-Localizable") }

    /// "Title shown in the  popup when photos are uploading."
    /// "Ensure seamless backups"
    public static var notification_permission_photos_title: String { localized(key: "notification_permission_photos_title", table: "iOS-Localizable") }

    /// "Notification text"
    /// "Check in with Proton Drive to confirm your photos are backed up and secure."
    public static var notification_text_confirm_backup_success: String { localized(key: "notification_text_confirm_backup_success", table: "iOS-Localizable") }

    /// "Button title shown on the onboarding page"
    /// "Get started"
    public static var onboarding_button_get_started: String { localized(key: "onboarding_button_get_started", table: "iOS-Localizable") }

    /// "Button title shown on the onboarding page"
    /// "Next"
    public static var onboarding_button_next: String { localized(key: "onboarding_button_next", table: "iOS-Localizable") }

    /// "Message shown in the app onboarding view"
    /// "Upload and view your files on the go. Zero-access technology guarantees only you have access."
    public static var onboarding_file_text: String { localized(key: "onboarding_file_text", table: "iOS-Localizable") }

    /// "Title shown in the app onboarding view"
    /// "All files at your fingertips"
    public static var onboarding_file_title: String { localized(key: "onboarding_file_title", table: "iOS-Localizable") }

    /// "Message shown in the app onboarding view"
    /// "Ensure your memories are kept safe, private, and in their original quality for years to come."
    public static var onboarding_photo_text: String { localized(key: "onboarding_photo_text", table: "iOS-Localizable") }

    /// "Title shown in the app onboarding view"
    /// "Automatic photo backups"
    public static var onboarding_photo_title: String { localized(key: "onboarding_photo_title", table: "iOS-Localizable") }

    /// "Message shown in the app onboarding view"
    /// "Add password protection to make your shared files even more secure."
    public static var onboarding_share_text: String { localized(key: "onboarding_share_text", table: "iOS-Localizable") }

    /// "Title shown in the app onboarding view"
    /// "Secure sharing"
    public static var onboarding_share_title: String { localized(key: "onboarding_share_title", table: "iOS-Localizable") }

    /// "Description of one dollar upsell popup"
    /// "When you need a little more storage, but not a lot. Introducing Drive Lite, featuring 20 GB storage for only %@ a month."
    public static func one_dollar_upsell_desc(localPrice: String) -> String { String(format: localized(key: "one_dollar_upsell_desc", table: "iOS-Localizable"), localPrice) }

    /// "Get Drive Lite"
    public static var one_dollar_upsell_get_plan_button: String { localized(key: "one_dollar_upsell_get_plan_button", table: "iOS-Localizable") }

    /// "Title of one dollar upsell popup"
    /// "More storage for only %@"
    public static func one_dollar_upsell_title(localPrice: String) -> String { String(format: localized(key: "one_dollar_upsell_title", table: "iOS-Localizable"), localPrice) }

    /// "View title"
    /// "Change mailbox password"
    public static var password_change_mailbox_password_title: String { localized(key: "password_change_mailbox_password_title", table: "iOS-Localizable") }

    /// "Banner text shown after changing successfully"
    /// "Password changed successfully"
    public static var password_change_success_text: String { localized(key: "password_change_success_text", table: "iOS-Localizable") }

    /// "View title"
    /// "Change password"
    public static var password_change_title: String { localized(key: "password_change_title", table: "iOS-Localizable") }

    /// "PIN config rule text"
    /// "Enter a PIN code with min 4 characters and max 21 characters."
    public static var password_config_caption: String { localized(key: "password_config_caption", table: "iOS-Localizable") }

    /// "Button in the config page to move to next page"
    /// "Next"
    public static var password_config_next_step: String { localized(key: "password_config_next_step", table: "iOS-Localizable") }

    /// "Title of textfield"
    /// "Set your PIN code"
    public static var password_config_textfield_title: String { localized(key: "password_config_textfield_title", table: "iOS-Localizable") }

    /// "Use PIN code"
    public static var password_config_title_use_pin: String { localized(key: "password_config_title_use_pin", table: "iOS-Localizable") }

    /// "Accept"
    public static var pending_invitation_screen_accept: String { localized(key: "pending_invitation_screen_accept", table: "iOS-Localizable") }

    /// "Decline"
    public static var pending_invitation_screen_decline: String { localized(key: "pending_invitation_screen_decline", table: "iOS-Localizable") }

    /// "Share date"
    public static var pending_invitation_screen_sort: String { localized(key: "pending_invitation_screen_sort", table: "iOS-Localizable") }

    /// "Pending shared items"
    public static var pending_invitation_screen_title: String { localized(key: "pending_invitation_screen_title", table: "iOS-Localizable") }

    /// "Action title in photos grid view"
    /// "Remove %d item"
    public static func photo_action_remove_item(num: Int) -> String { String(format: localized(key: "photo_action_remove_item", table: "iOS-Localizable"), num) }

    /// "Title shown in photo backup banner"
    /// "Backup in progress. This may take a while."
    public static var photo_backup_banner_in_progress: String { localized(key: "photo_backup_banner_in_progress", table: "iOS-Localizable") }

    /// "Title shown in photo backup banner"
    /// "End-to-end encrypted"
    public static var photo_backup_banner_title_e2ee: String { localized(key: "photo_backup_banner_title_e2ee", table: "iOS-Localizable") }

    /// "Are you sure you want to disable this feature? You can re-enable it later in settings if needed."
    public static var photo_feature_disable_alert_message: String { localized(key: "photo_feature_disable_alert_message", table: "iOS-Localizable") }

    /// "Disable photo backup feature"
    public static var photo_feature_disable_title: String { localized(key: "photo_feature_disable_title", table: "iOS-Localizable") }

    /// "Are you sure you want to enable this feature? The photo backup will be activated and displayed again."
    public static var photo_feature_enable_alert_message: String { localized(key: "photo_feature_enable_alert_message", table: "iOS-Localizable") }

    /// "Enable photo backup feature"
    public static var photo_feature_enable_title: String { localized(key: "photo_feature_enable_title", table: "iOS-Localizable") }

    /// "This will enable photo backup feature on this device. The Photos tab and feature settings will be displayed."
    public static var photo_feature_explanation: String { localized(key: "photo_feature_explanation", table: "iOS-Localizable") }

    /// "Failed to fetch photos. Please try again later."
    public static var photo_grid_error: String { localized(key: "photo_grid_error", table: "iOS-Localizable") }

    /// "Text of a baner"
    /// "Photos are not available during migration. Please wait until migration is finished."
    public static var photo_migration_banner_text: String { localized(key: "photo_migration_banner_text", table: "iOS-Localizable") }

    /// "Headline of migration popup"
    /// "Important updates"
    public static var photo_migration_headline: String { localized(key: "photo_migration_headline", table: "iOS-Localizable") }

    /// "Banner that explains photo volume data migration"
    /// "After migration, you can use new features like filters and photo album."
    public static var photo_migration_needed_explanation: String { localized(key: "photo_migration_needed_explanation", table: "iOS-Localizable") }

    /// "Title for a banner"
    /// "Photo library update needed"
    public static var photo_migration_needed_title: String { localized(key: "photo_migration_needed_title", table: "iOS-Localizable") }

    /// "Text of a placeholder while migrating photo data"
    /// "If you have a large photo library, it might take some time. You can close the app. We\'ll work on it in the background."
    public static var photo_migration_placeholder_text: String { localized(key: "photo_migration_placeholder_text", table: "iOS-Localizable") }

    /// "Title of a placeholder while migrating photo data"
    /// "Setting up Albums and Filters"
    public static var photo_migration_placeholder_title: String { localized(key: "photo_migration_placeholder_title", table: "iOS-Localizable") }

    /// "Subtitle of migration popup"
    /// "This quick update prepares your photos for new features like filters and albums"
    public static var photo_migration_subtitle: String { localized(key: "photo_migration_subtitle", table: "iOS-Localizable") }

    /// "Title of migration popup"
    /// "We need to update your data"
    public static var photo_migration_title: String { localized(key: "photo_migration_title", table: "iOS-Localizable") }

    /// "Turn on backup"
    public static var photo_onboarding_button_enable: String { localized(key: "photo_onboarding_button_enable", table: "iOS-Localizable") }

    /// "Your photos are end-to-end encrypted, ensuring total privacy."
    public static var photo_onboarding_e2e: String { localized(key: "photo_onboarding_e2e", table: "iOS-Localizable") }

    /// "Effortless backups"
    public static var photo_onboarding_effortless_backups: String { localized(key: "photo_onboarding_effortless_backups", table: "iOS-Localizable") }

    /// "Photos are backed up over WiFi in their original quality."
    public static var photo_onboarding_keep_quality: String { localized(key: "photo_onboarding_keep_quality", table: "iOS-Localizable") }

    /// "Protect your memories"
    public static var photo_onboarding_protect_memories: String { localized(key: "photo_onboarding_protect_memories", table: "iOS-Localizable") }

    /// "Encrypt and back up your photos and videos"
    public static var photo_onboarding_title: String { localized(key: "photo_onboarding_title", table: "iOS-Localizable") }

    /// "Button shown in the notification popup when photos are uploading."
    /// "Give access"
    public static var photo_permission_alert_button: String { localized(key: "photo_permission_alert_button", table: "iOS-Localizable") }

    /// "Message shown in the popup when photos are uploading."
    /// "This ensures all your photos are backed up and available across your devices.\n\nIn the next screen, change your settings to allow Proton Drive access to All Photos."
    public static var photo_permission_alert_text: String { localized(key: "photo_permission_alert_text", table: "iOS-Localizable") }

    /// "Title shown in the notification popup when user doesn\'t grant proper permission"
    /// "Proton Drive needs full access to your photos"
    public static var photo_permission_alert_title: String { localized(key: "photo_permission_alert_title", table: "iOS-Localizable") }

    /// "Generic error when photo cannot be loaded."
    /// "Make sure your device is connected to the internet and try again."
    public static var photo_preview_error_generic: String { localized(key: "photo_preview_error_generic", table: "iOS-Localizable") }

    /// "Error title shown when photo cannot be loaded"
    /// "Unable to load this photo"
    public static var photo_preview_error_photo_title: String { localized(key: "photo_preview_error_photo_title", table: "iOS-Localizable") }

    /// "Error text shown on the photo preview page"
    /// "There was an error loading this photo"
    public static var photo_preview_error_text: String { localized(key: "photo_preview_error_text", table: "iOS-Localizable") }

    /// "Error title shown on the photo preview page"
    /// "Could not load this photo"
    public static var photo_preview_error_title: String { localized(key: "photo_preview_error_title", table: "iOS-Localizable") }

    /// "Error title shown when format is unsupported"
    /// "Full preview of this format is not supported."
    public static var photo_preview_error_unsupported_format: String { localized(key: "photo_preview_error_unsupported_format", table: "iOS-Localizable") }

    /// "An error text appears if the local file SHA-1 differs from the remote value"
    /// "Please try again later."
    public static var photo_preview_error_verification_text: String { localized(key: "photo_preview_error_verification_text", table: "iOS-Localizable") }

    /// "An error title appears if the local file SHA-1 differs from the remote value"
    /// "Download verification failed"
    public static var photo_preview_error_verification_title: String { localized(key: "photo_preview_error_verification_title", table: "iOS-Localizable") }

    /// "Error title shown when video cannot be loaded"
    /// "Unable to load this video"
    public static var photo_preview_error_video_title: String { localized(key: "photo_preview_error_video_title", table: "iOS-Localizable") }

    /// "Message of a loading state alert"
    /// "Downloading and decrypting may take a few moments. Thanks for patience."
    public static var photo_preview_loading_message: String { localized(key: "photo_preview_loading_message", table: "iOS-Localizable") }

    /// "Title of a loading state alert"
    /// "Loading in progress"
    public static var photo_preview_loading_title: String { localized(key: "photo_preview_loading_title", table: "iOS-Localizable") }

    /// "Title displayed on the photo storage banner. Use ** to denote bold text; please retain this syntax."
    /// "Your storage is more than **80%** full"
    public static var photo_storage_eighty_percent_title: String { localized(key: "photo_storage_eighty_percent_title", table: "iOS-Localizable") }

    /// "Title displayed on the photo storage banner. Use ** to denote bold text; please retain this syntax."
    /// "Your storage is **50%** full"
    public static var photo_storage_fifty_percent_title: String { localized(key: "photo_storage_fifty_percent_title", table: "iOS-Localizable") }

    /// "Subtitle displayed on the photo storage banner. "
    /// "To continue the process you need to upgrade your plan."
    public static var photo_storage_full_subtitle: String { localized(key: "photo_storage_full_subtitle", table: "iOS-Localizable") }

    /// "Title displayed on the photo storage banner. "
    /// "Storage full"
    public static var photo_storage_full_title: String { localized(key: "photo_storage_full_title", table: "iOS-Localizable") }

    /// "Text shown on the photo storage banner, e.g. 3 items left, 1 item left"
    /// "%@ left"
    public static func photo_storage_item_left(items: String) -> String { String(format: localized(key: "photo_storage_item_left", table: "iOS-Localizable"), items) }

    /// "Notification text when photo is backing up but in the background"
    /// "Photo backup is slower in the background. Open the app for quicker uploads."
    public static var photo_upload_interrupted_notification: String { localized(key: "photo_upload_interrupted_notification", table: "iOS-Localizable") }

    /// "Subtitle shown on the photo upsell popup"
    /// "Upgrade now and keep all your memories encrypted and safe."
    public static var photo_upsell_subtitle: String { localized(key: "photo_upsell_subtitle", table: "iOS-Localizable") }

    /// "Title shown on the photo upsell popup"
    /// "Never run out of storage"
    public static var photo_upsell_title: String { localized(key: "photo_upsell_title", table: "iOS-Localizable") }

    /// "Warning text displayed in the photo picker."
    /// "Importing the files. Please keep the app open to avoid interruptions."
    public static var photos_picker_warning: String { localized(key: "photos_picker_warning", table: "iOS-Localizable") }

    /// "End-to-end encrypted"
    public static var photos_screen_footer: String { localized(key: "photos_screen_footer", table: "iOS-Localizable") }

    /// "Something went wrong... please try again later."
    public static var photos_screen_footer_error: String { localized(key: "photos_screen_footer_error", table: "iOS-Localizable") }

    /// "Text indicating that data is loading."
    /// "Getting things ready..."
    public static var populate_loading_text: String { localized(key: "populate_loading_text", table: "iOS-Localizable") }

    /// "Cancel"
    public static var prepare_preview_cancel: String { localized(key: "prepare_preview_cancel", table: "iOS-Localizable") }

    /// "The text displayed in the badge at the top left when previewing burst"
    /// "Burst"
    public static var preview_burst_badge_text: String { localized(key: "preview_burst_badge_text", table: "iOS-Localizable") }

    /// "A text label to indicate the image is cover of this burst"
    /// "Cover"
    public static var preview_burst_cover: String { localized(key: "preview_burst_cover", table: "iOS-Localizable") }

    /// "%d photo in total"
    public static func preview_burst_gallery_subtitle(num: Int) -> String { String(format: localized(key: "preview_burst_gallery_subtitle", table: "iOS-Localizable"), num) }

    /// "The text displayed in the badge at the top left when previewing a live photo"
    /// "LIVE"
    public static var preview_livePhoto_badge_text: String { localized(key: "preview_livePhoto_badge_text", table: "iOS-Localizable") }

    /// "The text displayed in the badge at the top left while the asset is loading during the preview."
    /// "Loading"
    public static var preview_loading_badge_text: String { localized(key: "preview_loading_badge_text", table: "iOS-Localizable") }

    /// "Text shown with progress bar"
    /// "%@ downloaded"
    public static func progress_status_downloaded(percent: String) -> String { String(format: localized(key: "progress_status_downloaded", table: "iOS-Localizable"), percent) }

    /// "Text to indicate this file is downloading"
    /// "Downloading..."
    public static var progress_status_downloading: String { localized(key: "progress_status_downloading", table: "iOS-Localizable") }

    /// "Banner text shown on photo backup page to indicate how many photos lefte.g. 350+ items left"
    /// "%d%@ item left"
    public static func progress_status_item_left(items: Int, roundingSign: String) -> String { String(format: localized(key: "progress_status_item_left", table: "iOS-Localizable"), items, roundingSign) }

    /// "Text to indicate this file is downloading"
    /// "Paused"
    public static var progress_status_paused: String { localized(key: "progress_status_paused", table: "iOS-Localizable") }

    /// "Upload failed"
    public static var progress_status_upload_failed: String { localized(key: "progress_status_upload_failed", table: "iOS-Localizable") }

    /// "Text shown with progress bar"
    /// "%@ uploaded..."
    public static func progress_status_uploaded(percent: String) -> String { String(format: localized(key: "progress_status_uploaded", table: "iOS-Localizable"), percent) }

    /// "Text to indicate this file is uploading"
    /// "Uploading..."
    public static var progress_status_uploading: String { localized(key: "progress_status_uploading", table: "iOS-Localizable") }

    /// "Waiting..."
    public static var progress_status_waiting: String { localized(key: "progress_status_waiting", table: "iOS-Localizable") }

    /// "Information banner shown on protection setting page "
    /// "Enabling auto-lock stops background processes unless set to \"After launch.\""
    public static var protection_info_banner_text: String { localized(key: "protection_info_banner_text", table: "iOS-Localizable") }

    /// "Text field caption"
    /// "Repeat your PIN to confirm."
    public static var protection_pin_caption_repeat_pin_code: String { localized(key: "protection_pin_caption_repeat_pin_code", table: "iOS-Localizable") }

    /// "Text field title"
    /// "Repeat your PIN code"
    public static var protection_pin_title_repeat_pin_code: String { localized(key: "protection_pin_title_repeat_pin_code", table: "iOS-Localizable") }

    /// "Section footer for pin&faceID setting"
    /// "Turn this feature on to auto-lock and use a PIN code or biometric sensor to unlock it."
    public static var protection_section_footer_protection: String { localized(key: "protection_section_footer_protection", table: "iOS-Localizable") }

    /// "Section header for pin&faceID setting"
    /// "Protection"
    public static var protection_section_header_protection: String { localized(key: "protection_section_header_protection", table: "iOS-Localizable") }

    /// "Section footer of protection auto lock setting"
    /// "The PIN code will be required after some minutes of the app being in the background or after exiting the app."
    public static var protection_timing_section_footer: String { localized(key: "protection_timing_section_footer", table: "iOS-Localizable") }

    /// "Section header of protection auto lock setting"
    /// "Timings"
    public static var protection_timings_section_header: String { localized(key: "protection_timings_section_header", table: "iOS-Localizable") }

    /// "Option title to choose biometry as protection"
    /// "Use Biometry"
    public static var protection_use_biometry: String { localized(key: "protection_use_biometry", table: "iOS-Localizable") }

    /// "e.g. use FaceID, use TouchID"
    /// "Use %@"
    public static func protection_use_use_technology(tech: String) -> String { String(format: localized(key: "protection_use_use_technology", table: "iOS-Localizable"), tech) }

    /// "Failed to download file"
    public static var proton_docs_download_error: String { localized(key: "proton_docs_download_error", table: "iOS-Localizable") }

    /// "Failed to open document editor"
    public static var proton_docs_opening_error: String { localized(key: "proton_docs_opening_error", table: "iOS-Localizable") }

    /// "Text shown with loading spinner"
    /// "Last updated: %@"
    public static func refresh_last_update(time: String) -> String { String(format: localized(key: "refresh_last_update", table: "iOS-Localizable"), time) }

    /// "Button to remove selected photos from the album"
    /// "Remove from album"
    public static var remove_from_album_action: String { localized(key: "remove_from_album_action", table: "iOS-Localizable") }

    /// "Enter your Proton username or email"
    public static var report_bug_account_field_placeholder: String { localized(key: "report_bug_account_field_placeholder", table: "iOS-Localizable") }

    /// "Proton Account user name or email"
    public static var report_bug_account_field_title: String { localized(key: "report_bug_account_field_title", table: "iOS-Localizable") }

    /// "Add from files"
    public static var report_bug_attachment_field_add_from_files: String { localized(key: "report_bug_attachment_field_add_from_files", table: "iOS-Localizable") }

    /// "Add from gallery"
    public static var report_bug_attachment_field_add_from_gallery: String { localized(key: "report_bug_attachment_field_add_from_gallery", table: "iOS-Localizable") }

    /// "Include logs from Proton Drive"
    public static var report_bug_attachment_field_logs_checkbox: String { localized(key: "report_bug_attachment_field_logs_checkbox", table: "iOS-Localizable") }

    /// "Attachments"
    public static var report_bug_attachment_field_title: String { localized(key: "report_bug_attachment_field_title", table: "iOS-Localizable") }

    /// "Total upload: \\(uploadSize) MB of 50 MB • \\(fileCount) of 10 files"
    /// "Total upload: %.1f MB of 50 MB • %d of 10 files"
    public static func report_bug_attachment_field_upload_status_format(uploadSize: Double, fileCount: Int) -> String { String(format: localized(key: "report_bug_attachment_field_upload_status_format", table: "iOS-Localizable"), uploadSize, fileCount) }

    /// "Report a problem"
    public static var report_bug_button: String { localized(key: "report_bug_button", table: "iOS-Localizable") }

    /// "Let us know where we can reach you"
    public static var report_bug_email_field_placeholder: String { localized(key: "report_bug_email_field_placeholder", table: "iOS-Localizable") }

    /// "Contact email address"
    public static var report_bug_email_field_title: String { localized(key: "report_bug_email_field_title", table: "iOS-Localizable") }

    /// "Please provide valid email address"
    public static var report_bug_email_field_warning: String { localized(key: "report_bug_email_field_warning", table: "iOS-Localizable") }

    /// "Please describe your issue and include any error messages..."
    public static var report_bug_message_field_placeholder: String { localized(key: "report_bug_message_field_placeholder", table: "iOS-Localizable") }

    /// "What went wrong?"
    public static var report_bug_message_field_title: String { localized(key: "report_bug_message_field_title", table: "iOS-Localizable") }

    /// "Minimum 10 characters"
    public static var report_bug_message_field_warning: String { localized(key: "report_bug_message_field_warning", table: "iOS-Localizable") }

    /// "Send"
    public static var report_bug_send_button_title: String { localized(key: "report_bug_send_button_title", table: "iOS-Localizable") }

    /// "Report sending failed."
    public static var report_bug_submission_failure: String { localized(key: "report_bug_submission_failure", table: "iOS-Localizable") }

    /// "Report sent successfully!"
    public static var report_bug_submission_success: String { localized(key: "report_bug_submission_success", table: "iOS-Localizable") }

    /// "I want to report a problem with:"
    public static var report_bug_topic_field_title: String { localized(key: "report_bug_topic_field_title", table: "iOS-Localizable") }

    /// "Albums"
    public static var report_topic_albums_title: String { localized(key: "report_topic_albums_title", table: "iOS-Localizable") }

    /// "Decryption"
    public static var report_topic_decryption_title: String { localized(key: "report_topic_decryption_title", table: "iOS-Localizable") }

    /// "Document"
    public static var report_topic_docs_title: String { localized(key: "report_topic_docs_title", table: "iOS-Localizable") }

    /// "Encryption"
    public static var report_topic_encryption_title: String { localized(key: "report_topic_encryption_title", table: "iOS-Localizable") }

    /// "Files app"
    public static var report_topic_file_provider_title: String { localized(key: "report_topic_file_provider_title", table: "iOS-Localizable") }

    /// "Offline Available"
    public static var report_topic_offline_title: String { localized(key: "report_topic_offline_title", table: "iOS-Localizable") }

    /// "Other"
    public static var report_topic_other_title: String { localized(key: "report_topic_other_title", table: "iOS-Localizable") }

    /// "Photos"
    public static var report_topic_photos_title: String { localized(key: "report_topic_photos_title", table: "iOS-Localizable") }

    /// "Sharing"
    public static var report_topic_sharing_title: String { localized(key: "report_topic_sharing_title", table: "iOS-Localizable") }

    /// "Spreadsheet"
    public static var report_topic_sheets_title: String { localized(key: "report_topic_sheets_title", table: "iOS-Localizable") }

    /// "Error message displayed on the photo backup issue page"
    /// "Unable to connect to iCloud"
    public static var retry_error_explainer_cannot_connect_icloud: String { localized(key: "retry_error_explainer_cannot_connect_icloud", table: "iOS-Localizable") }

    /// "Error message displayed on the photo backup issue page"
    /// "Network connection error"
    public static var retry_error_explainer_connection_error: String { localized(key: "retry_error_explainer_connection_error", table: "iOS-Localizable") }

    /// "Error message displayed on the photo backup issue page"
    /// "Device storage full"
    public static var retry_error_explainer_device_storage_full: String { localized(key: "retry_error_explainer_device_storage_full", table: "iOS-Localizable") }

    /// "Error message displayed on the photo backup issue page"
    /// "Encryption failed"
    public static var retry_error_explainer_encryption_error: String { localized(key: "retry_error_explainer_encryption_error", table: "iOS-Localizable") }

    /// "Error message displayed on the photo backup issue page"
    /// "Failed to load resource"
    public static var retry_error_explainer_failed_to_load_resource: String { localized(key: "retry_error_explainer_failed_to_load_resource", table: "iOS-Localizable") }

    /// "Error message displayed on the photo backup issue page"
    /// "Can\'t access the original file."
    public static var retry_error_explainer_invalid_asset: String { localized(key: "retry_error_explainer_invalid_asset", table: "iOS-Localizable") }

    /// "Error message displayed on the photo backup issue page"
    /// "Missing permissions"
    public static var retry_error_explainer_missing_permissions: String { localized(key: "retry_error_explainer_missing_permissions", table: "iOS-Localizable") }

    /// "Error message displayed on the photo backup issue page"
    /// "Name validation failed"
    public static var retry_error_explainer_name_validation: String { localized(key: "retry_error_explainer_name_validation", table: "iOS-Localizable") }

    /// "Error message displayed on the photo backup issue page"
    /// "Encryption failed"
    public static var retry_error_explainer_quote_exceeded: String { localized(key: "retry_error_explainer_quote_exceeded", table: "iOS-Localizable") }

    /// "Message shown when a user attempts to skip a photo that failed to back up."
    /// "Are you sure you want to skip photos that haven\'t been backed up? They will not be backed up."
    public static var retry_skip_alert_message: String { localized(key: "retry_skip_alert_message", table: "iOS-Localizable") }

    /// "Title shown when a user attempts to skip a photo that failed to back up."
    /// "Skip backup for these photos?"
    public static var retry_skip_alert_title: String { localized(key: "retry_skip_alert_title", table: "iOS-Localizable") }

    /// "Button title"
    /// "Retry all"
    public static var retry_view_button_retry_all: String { localized(key: "retry_view_button_retry_all", table: "iOS-Localizable") }

    /// "Subtitle shown on the backup retry view"
    /// "%d item failed to backup"
    public static func retry_view_items_failed_to_backup(count: Int) -> String { String(format: localized(key: "retry_view_items_failed_to_backup", table: "iOS-Localizable"), count) }

    /// "Title shown on the backup retry view"
    /// "Backup issues"
    public static var retry_view_title: String { localized(key: "retry_view_title", table: "iOS-Localizable") }

    /// "Title of a button. Shared photo is a photo shared by other user to me"
    /// "Save shared photo"
    public static var save_shared_photo: String { localized(key: "save_shared_photo", table: "iOS-Localizable") }

    /// "Button title to scan document"
    /// "Scan document"
    public static var scan_document_button: String { localized(key: "scan_document_button", table: "iOS-Localizable") }

    /// "Section title "
    /// "ABOUT"
    public static var setting_about: String { localized(key: "setting_about", table: "iOS-Localizable") }

    /// "Button title"
    /// "Manage account"
    public static var setting_account_manage_account: String { localized(key: "setting_account_manage_account", table: "iOS-Localizable") }

    /// "Section title"
    /// "Account Settings"
    public static var setting_account_settings: String { localized(key: "setting_account_settings", table: "iOS-Localizable") }

    /// "Title of acknowledgments page"
    /// "Acknowledgments"
    public static var setting_acknowledgments: String { localized(key: "setting_acknowledgments", table: "iOS-Localizable") }

    /// "Section title"
    /// "APP SETTINGS"
    public static var setting_app_settings: String { localized(key: "setting_app_settings", table: "iOS-Localizable") }

    /// "App Version: %@"
    public static func setting_app_version(version: String) -> String { String(format: localized(key: "setting_app_version", table: "iOS-Localizable"), version) }

    /// "Biometry protection setting title"
    /// "Biometry"
    public static var setting_biometry: String { localized(key: "setting_biometry", table: "iOS-Localizable") }

    /// "Setting option to clear local cache (content)"
    /// "Clear content cache"
    public static var setting_clear_local_cache: String { localized(key: "setting_clear_local_cache", table: "iOS-Localizable") }

    /// "Clear logs cache"
    public static var setting_clear_logs: String { localized(key: "setting_clear_logs", table: "iOS-Localizable") }

    /// "Manage Debug Mode"
    /// "Debug Mode"
    public static var setting_debug_mode: String { localized(key: "setting_debug_mode", table: "iOS-Localizable") }

    /// "Instructions section title"
    /// "Instructions"
    public static var setting_debug_mode_instructions: String { localized(key: "setting_debug_mode_instructions", table: "iOS-Localizable") }

    /// "1. Tap the yellow bug button to mark the current moment — this helps us identify when the issue occurred.\n\n2. Press and hold the bug button to open the bug report screen and share more details."
    public static var setting_debug_mode_instructions_body: String { localized(key: "setting_debug_mode_instructions_body", table: "iOS-Localizable") }

    /// "Setting option to export log"
    /// "Export logs"
    public static var setting_export_logs: String { localized(key: "setting_export_logs", table: "iOS-Localizable") }

    /// "Get help section title"
    /// "Get help"
    public static var setting_get_help: String { localized(key: "setting_get_help", table: "iOS-Localizable") }

    /// "This is markdown text\nPlease move [support website](%@) together"
    /// "You will find additional help on our [support website](%@)"
    public static func setting_help_additional_help(link: String) -> String { String(format: localized(key: "setting_help_additional_help", table: "iOS-Localizable"), link) }

    /// "Label text to encourage user report issue"
    /// "If you are facing any problems, please report the issue."
    public static var setting_help_report_encourage_text: String { localized(key: "setting_help_report_encourage_text", table: "iOS-Localizable") }

    /// "Button title"
    /// "Report an issue"
    public static var setting_help_report_issue: String { localized(key: "setting_help_report_issue", table: "iOS-Localizable") }

    /// "Button title"
    /// "Show logs"
    public static var setting_help_show_logs: String { localized(key: "setting_help_show_logs", table: "iOS-Localizable") }

    /// "Button title to navigate to language setting"
    /// "Language"
    public static var setting_language: String { localized(key: "setting_language", table: "iOS-Localizable") }

    /// "Title of latest logs view"
    /// "Latest logs"
    public static var setting_latest_logs: String { localized(key: "setting_latest_logs", table: "iOS-Localizable") }

    /// "Setting option to photo backup"
    /// "Photos backup"
    public static var setting_photo_backup: String { localized(key: "setting_photo_backup", table: "iOS-Localizable") }

    /// "PIN protection setting title"
    /// "PIN"
    public static var setting_pin: String { localized(key: "setting_pin", table: "iOS-Localizable") }

    /// "Title of privacy policy page"
    /// "Privacy policy"
    public static var setting_privacy_policy: String { localized(key: "setting_privacy_policy", table: "iOS-Localizable") }

    /// "Title of security key page "
    /// "Security keys"
    public static var setting_security_key: String { localized(key: "setting_security_key", table: "iOS-Localizable") }

    /// "Title of see latest logs row"
    /// "See latest logs"
    public static var setting_see_latest_logs: String { localized(key: "setting_see_latest_logs", table: "iOS-Localizable") }

    /// "Storage setting section title"
    /// "Storage"
    public static var setting_storage: String { localized(key: "setting_storage", table: "iOS-Localizable") }

    /// "Out of storage"
    public static var setting_storage_out_of_storage: String { localized(key: "setting_storage_out_of_storage", table: "iOS-Localizable") }

    /// "Syncing has been paused. Please upgrade or free up space to resume syncing."
    public static var setting_storage_out_of_storage_warning: String { localized(key: "setting_storage_out_of_storage_warning", table: "iOS-Localizable") }

    /// "Using \\(currentStorage) of \\(maxStorage)"
    /// "Using %@ of %@"
    public static func setting_storage_usage_info(currentStorage: String, maxStorage: String) -> String { String(format: localized(key: "setting_storage_usage_info", table: "iOS-Localizable"), currentStorage, maxStorage) }

    /// "System setting section title"
    /// "System"
    public static var setting_system: String { localized(key: "setting_system", table: "iOS-Localizable") }

    /// "Information text"
    /// "Checking for update ..."
    public static var setting_system_checking_update: String { localized(key: "setting_system_checking_update", table: "iOS-Localizable") }

    /// "Information text"
    /// "Downloading new version ..."
    public static var setting_system_downloading: String { localized(key: "setting_system_downloading", table: "iOS-Localizable") }

    /// "Toggle title"
    /// "Launch on startup"
    public static var setting_system_launch_on_startup: String { localized(key: "setting_system_launch_on_startup", table: "iOS-Localizable") }

    /// "Information text"
    /// "New version available"
    public static var setting_system_new_version_available: String { localized(key: "setting_system_new_version_available", table: "iOS-Localizable") }

    /// "Information text"
    /// "Proton Drive is up to date: v%@"
    public static func setting_system_up_to_date(version: String) -> String { String(format: localized(key: "setting_system_up_to_date", table: "iOS-Localizable"), version) }

    /// "Button title"
    /// "Update now"
    public static var setting_system_update_button: String { localized(key: "setting_system_update_button", table: "iOS-Localizable") }

    /// "Terms and Conditions"
    public static var setting_terms_and_condition: String { localized(key: "setting_terms_and_condition", table: "iOS-Localizable") }

    /// "Title of terms of service page"
    /// "Terms of service"
    public static var setting_terms_of_service: String { localized(key: "setting_terms_of_service", table: "iOS-Localizable") }

    /// "Option to enable photo backups using mobile data."
    /// "Use mobile data to backup photos"
    public static var setting_use_cellular_to_backup: String { localized(key: "setting_use_cellular_to_backup", table: "iOS-Localizable") }

    /// "Title of default home tab setting"
    /// "Default home tab"
    public static var settings_default_home_tab: String { localized(key: "settings_default_home_tab", table: "iOS-Localizable") }

    /// "Action to save shared link as text file"
    /// "Text file"
    public static var shareExt_alert_action_textFile: String { localized(key: "shareExt_alert_action_textFile", table: "iOS-Localizable") }

    /// "Alert message to user want to save the shared link as text file or discard"
    /// "Save the link as"
    public static var shareExt_alert_msg_save_link_as: String { localized(key: "shareExt_alert_msg_save_link_as", table: "iOS-Localizable") }

    /// "The action for coping share link"
    /// "Copy link"
    public static var share_action_copy_link: String { localized(key: "share_action_copy_link", table: "iOS-Localizable") }

    /// "The action for copying a password used to protect a shared item"
    /// "Copy password"
    public static var share_action_copy_password: String { localized(key: "share_action_copy_password", table: "iOS-Localizable") }

    /// "The action for opening setting page"
    /// "Link settings"
    public static var share_action_link_settings: String { localized(key: "share_action_link_settings", table: "iOS-Localizable") }

    /// "Action to save burst photo"
    /// "Save Burst"
    public static var share_action_save_burst_photo: String { localized(key: "share_action_save_burst_photo", table: "iOS-Localizable") }

    /// "Action to save shared file in the current location"
    /// "Save here"
    public static var share_action_save_here: String { localized(key: "share_action_save_here", table: "iOS-Localizable") }

    /// "Action to save image"
    /// "Save Image"
    public static var share_action_save_image: String { localized(key: "share_action_save_image", table: "iOS-Localizable") }

    /// "Action to save live photo"
    /// "Save Live Photo"
    public static var share_action_save_live_photo: String { localized(key: "share_action_save_live_photo", table: "iOS-Localizable") }

    /// "Action title, save to {location}"
    /// "Save to"
    public static var share_action_save_to: String { localized(key: "share_action_save_to", table: "iOS-Localizable") }

    /// "The action for showing system share sheet"
    /// "Share"
    public static var share_action_share: String { localized(key: "share_action_share", table: "iOS-Localizable") }

    /// "The action for stopping sharing item"
    /// "Stop sharing"
    public static var share_action_stop_sharing: String { localized(key: "share_action_stop_sharing", table: "iOS-Localizable") }

    /// "Information text for stop sharing"
    /// "Delete link and remove access for everyone"
    public static var share_action_stop_sharing_desc: String { localized(key: "share_action_stop_sharing_desc", table: "iOS-Localizable") }

    /// "Message of the share page when no items are shared"
    /// "Create links and share files with others"
    public static var share_empty_message: String { localized(key: "share_empty_message", table: "iOS-Localizable") }

    /// "Title of the share page when no items are shared"
    /// "Share files with links"
    public static var share_empty_title: String { localized(key: "share_empty_title", table: "iOS-Localizable") }

    /// "Append the item name, for example: Share a.png, Share sample folder."
    /// "Share %@"
    public static func share_item(name: String) -> String { String(format: localized(key: "share_item", table: "iOS-Localizable"), name) }

    /// "Warning text"
    /// "This link was created with an old Drive version and can not be modified. Delete this link and create a new one to change the settings."
    public static var share_legacy_link_warning: String { localized(key: "share_legacy_link_warning", table: "iOS-Localizable") }

    /// "Button displayed on the screen in case of failure"
    /// "Delete Link"
    public static var share_link_button_delete_link: String { localized(key: "share_link_button_delete_link", table: "iOS-Localizable") }

    /// "Action text shown in the unsaved changes alert"
    /// "Leave without saving"
    public static var share_link_drop_unsaved_change_action: String { localized(key: "share_link_drop_unsaved_change_action", table: "iOS-Localizable") }

    /// "Error message displayed on the screen in case of failure"
    /// "Failed to generate a secure link. Try again later."
    public static var share_link_error_message: String { localized(key: "share_link_error_message", table: "iOS-Localizable") }

    /// "Please select an expiration date in the future"
    public static var share_link_past_date_error: String { localized(key: "share_link_past_date_error", table: "iOS-Localizable") }

    /// "Action text shown in the unsaved changes alert"
    /// "Save changes"
    public static var share_link_save_changes: String { localized(key: "share_link_save_changes", table: "iOS-Localizable") }

    /// "Banner text"
    /// "Sharing settings updated"
    public static var share_link_settings_updated: String { localized(key: "share_link_settings_updated", table: "iOS-Localizable") }

    /// "Alert title shown in the unsaved changes alert"
    /// "Your unsaved changes will be lost."
    public static var share_link_unsaved_change_alert_title: String { localized(key: "share_link_unsaved_change_alert_title", table: "iOS-Localizable") }

    /// "Label text"
    /// "Updating Settings"
    public static var share_link_updating_title: String { localized(key: "share_link_updating_title", table: "iOS-Localizable") }

    /// "Error message when the user wants to enable editable share URLs beyond the allowance."
    /// "Max amount of editable public urls limited to 3 on your plan. Please upgrade."
    public static var share_max_editable_share_limit_error: String { localized(key: "share_max_editable_share_limit_error", table: "iOS-Localizable") }

    /// "Section header title for set public share link"
    /// "Link options"
    public static var share_section_link_options: String { localized(key: "share_section_link_options", table: "iOS-Localizable") }

    /// "Button title"
    /// "Stop sharing"
    public static var share_stop_sharing: String { localized(key: "share_stop_sharing", table: "iOS-Localizable") }

    /// "This will delete the link and remove access to your file or folder for anyone with the link. You can’t undo this action."
    public static var share_stop_sharing_alert_message: String { localized(key: "share_stop_sharing_alert_message", table: "iOS-Localizable") }

    /// "Message shown in the share setting page"
    /// "Anyone with the link and password can access the file/folder "
    public static var share_via_custom_password_message: String { localized(key: "share_via_custom_password_message", table: "iOS-Localizable") }

    /// "Message shown in the share setting page"
    /// "Anyone with this link can access your file/folder"
    public static var share_via_default_password_message: String { localized(key: "share_via_default_password_message", table: "iOS-Localizable") }

    /// "Preparing secure link for sharing"
    /// "Preparing secure link"
    public static var share_via_prepare_secure_link: String { localized(key: "share_via_prepare_secure_link", table: "iOS-Localizable") }

    /// "Files and folders that you share with others will appear here"
    public static var shared_by_me_empty_message: String { localized(key: "shared_by_me_empty_message", table: "iOS-Localizable") }

    /// "Shared by me"
    public static var shared_by_me_empty_title: String { localized(key: "shared_by_me_empty_title", table: "iOS-Localizable") }

    /// "Shared by me"
    public static var shared_by_me_screen_title: String { localized(key: "shared_by_me_screen_title", table: "iOS-Localizable") }

    /// "Shared"
    public static var shared_screen_title: String { localized(key: "shared_screen_title", table: "iOS-Localizable") }

    /// "Bookmark link copied"
    public static var shared_with_me_bookmarks_copied: String { localized(key: "shared_with_me_bookmarks_copied", table: "iOS-Localizable") }

    /// "We could not copy the bookmark URL"
    public static var shared_with_me_bookmarks_copy_url_error: String { localized(key: "shared_with_me_bookmarks_copy_url_error", table: "iOS-Localizable") }

    /// "Alert title shown when user attempts to delete a bookmark"
    /// "You are about to delete “%@”. Are you sure you want to proceed?"
    public static func shared_with_me_bookmarks_delete_button(item: String) -> String { String(format: localized(key: "shared_with_me_bookmarks_delete_button", table: "iOS-Localizable"), item) }

    /// "Delete"
    public static var shared_with_me_bookmarks_delete_confirmation: String { localized(key: "shared_with_me_bookmarks_delete_confirmation", table: "iOS-Localizable") }

    /// "String shown to display bookmark second line, where %@ is the formatted date."
    /// "Public Link • Created %@"
    public static func shared_with_me_bookmarks_second_line(date: String) -> String { String(format: localized(key: "shared_with_me_bookmarks_second_line", table: "iOS-Localizable"), date) }

    /// "Shared with me empty message"
    /// "Files and folders that others shared with you will appear here"
    public static var shared_with_me_empty_message: String { localized(key: "shared_with_me_empty_message", table: "iOS-Localizable") }

    /// "Shared with me empty title"
    /// "Shared with me"
    public static var shared_with_me_empty_title: String { localized(key: "shared_with_me_empty_title", table: "iOS-Localizable") }

    /// "Pending shared items"
    public static var shared_with_me_pending_invitation_section: String { localized(key: "shared_with_me_pending_invitation_section", table: "iOS-Localizable") }

    /// "10+ items shared with you"
    public static var shared_with_me_pending_invitation_section_message_many: String { localized(key: "shared_with_me_pending_invitation_section_message_many", table: "iOS-Localizable") }

    /// "1 item shared with you"
    public static var shared_with_me_pending_invitation_section_message_one: String { localized(key: "shared_with_me_pending_invitation_section_message_one", table: "iOS-Localizable") }

    /// "items shared with you"
    public static var shared_with_me_pending_invitation_section_message_some: String { localized(key: "shared_with_me_pending_invitation_section_message_some", table: "iOS-Localizable") }

    /// "Alert title shown when user attempts to remove his access to the file or folder"
    /// "You are about to leave \"%@\". You will not be able to access it again until the owner shares it with you. Are you sure you want to proceed?"
    public static func shared_with_me_remove_me(item: String) -> String { String(format: localized(key: "shared_with_me_remove_me", table: "iOS-Localizable"), item) }

    /// "Leave"
    public static var shared_with_me_remove_me_confirmation: String { localized(key: "shared_with_me_remove_me_confirmation", table: "iOS-Localizable") }

    /// "Placeholder text of invitation message"
    /// "Add a message"
    public static var sharing_invitation_message_placeholder: String { localized(key: "sharing_invitation_message_placeholder", table: "iOS-Localizable") }

    /// "Banner text is shown when user try to invite address has invited"
    /// "Already a member of this share."
    public static var sharing_invite_duplicated_member_error: String { localized(key: "sharing_invite_duplicated_member_error", table: "iOS-Localizable") }

    /// "Banner text shown after removing user\'s access"
    /// "Access removed"
    public static var sharing_member_access_removed: String { localized(key: "sharing_member_access_removed", table: "iOS-Localizable") }

    /// "Section header for editor access settings"
    /// "Access"
    public static var sharing_member_access_section_title: String { localized(key: "sharing_member_access_section_title", table: "iOS-Localizable") }

    /// "Banner text shown after updating the invitee\'s access permissions."
    /// "Access updated and shared"
    public static var sharing_member_access_updated: String { localized(key: "sharing_member_access_updated", table: "iOS-Localizable") }

    /// "Toggle label to allow editors to manage sharing"
    /// "Allow editors to change permissions and share"
    public static var sharing_member_allow_editors_to_manage_sharing: String { localized(key: "sharing_member_allow_editors_to_manage_sharing", table: "iOS-Localizable") }

    /// "Title of public link component to indicate that anyone with the link can edit or view."
    /// "Anyone with the link"
    public static var sharing_member_anyone_with_link: String { localized(key: "sharing_member_anyone_with_link", table: "iOS-Localizable") }

    /// "Confirmation button to change your own access to viewer"
    /// "Change my access"
    public static var sharing_member_change_own_access_confirmation: String { localized(key: "sharing_member_change_own_access_confirmation", table: "iOS-Localizable") }

    /// "Confirmation message shown before you change your own access down to viewer"
    /// "You won\'t be able to share \"%@\" after changing your access to viewer. The owner or an editor with sharing access can restore your edit access. You can’t undo this change yourself."
    public static func sharing_member_change_own_access_message(name: String) -> String { String(format: localized(key: "sharing_member_change_own_access_message", table: "iOS-Localizable"), name) }

    /// "Confirmation dialog title shown before you change your own access down to viewer"
    /// "Change access to viewer?"
    public static var sharing_member_change_own_access_title: String { localized(key: "sharing_member_change_own_access_title", table: "iOS-Localizable") }

    /// "Action title"
    /// "Copy invite link"
    public static var sharing_member_copy_invite_link: String { localized(key: "sharing_member_copy_invite_link", table: "iOS-Localizable") }

    /// "Suffix marking the current user in the members list, e.g. \'Alice (you)\'"
    /// "%@ (you)"
    public static func sharing_member_current_user_suffix(name: String) -> String { String(format: localized(key: "sharing_member_current_user_suffix", table: "iOS-Localizable"), name) }

    /// "Banner text when added editor success"
    /// "%d editor added"
    public static func sharing_member_editor_added(num: Int) -> String { String(format: localized(key: "sharing_member_editor_added", table: "iOS-Localizable"), num) }

    /// "Body of the tooltip explaining that editors can now manage sharing"
    /// "Editors can now manage sharing and invite others. You can turn it off anytime in Share settings."
    public static var sharing_member_editor_permissions_tooltip_message: String { localized(key: "sharing_member_editor_permissions_tooltip_message", table: "iOS-Localizable") }

    /// "Title of the tooltip shown when editors can manage sharing on a newly created share"
    /// "New editor permissions"
    public static var sharing_member_editor_permissions_tooltip_title: String { localized(key: "sharing_member_editor_permissions_tooltip_title", table: "iOS-Localizable") }

    /// "Banner text shown after disabling the setting that lets editors manage sharing"
    /// "Setting updated. Editors can\'t change permissions or share."
    public static var sharing_member_editors_can_share_disabled: String { localized(key: "sharing_member_editors_can_share_disabled", table: "iOS-Localizable") }

    /// "Banner text shown after enabling the setting that lets editors manage sharing"
    /// "Setting updated. Editors can change permissions and share."
    public static var sharing_member_editors_can_share_enabled: String { localized(key: "sharing_member_editors_can_share_enabled", table: "iOS-Localizable") }

    /// "Error message"
    /// "The invitee has already been invited."
    public static var sharing_member_error_already_invited: String { localized(key: "sharing_member_error_already_invited", table: "iOS-Localizable") }

    /// "Error message"
    /// "Group sharing is not supported at the moment."
    public static var sharing_member_error_group_not_support: String { localized(key: "sharing_member_error_group_not_support", table: "iOS-Localizable") }

    /// "You’ve hit the limit for invites and members in this share. Consider removing someone to expand the share limit."
    public static var sharing_member_error_insufficient_invitation_quota: String { localized(key: "sharing_member_error_insufficient_invitation_quota", table: "iOS-Localizable") }

    /// "Error message"
    /// "This user is part of too many shares. Please ask them to leave a share before inviting them."
    public static var sharing_member_error_insufficient_share_joined_quota: String { localized(key: "sharing_member_error_insufficient_share_joined_quota", table: "iOS-Localizable") }

    /// "Error message"
    /// "The invitee’s email is not associated with a Proton account, or you’re trying to invite yourself. Please check the email and try again."
    public static var sharing_member_error_invalid_address: String { localized(key: "sharing_member_error_invalid_address", table: "iOS-Localizable") }

    /// "Error message"
    /// "Your email doesn’t match the one used to share this content."
    public static var sharing_member_error_invalid_inviter_address: String { localized(key: "sharing_member_error_invalid_inviter_address", table: "iOS-Localizable") }

    /// "Error message"
    /// "Invalid key packet detected. Please contact customer support"
    public static var sharing_member_error_invalid_key_packet: String { localized(key: "sharing_member_error_invalid_key_packet", table: "iOS-Localizable") }

    /// "Error message"
    /// "Invalid key packet signature. Please contact customer support"
    public static var sharing_member_error_invalid_key_packet_signature: String { localized(key: "sharing_member_error_invalid_key_packet_signature", table: "iOS-Localizable") }

    /// "Error message"
    /// "The user is already in this share with a different email."
    public static var sharing_member_error_invited_with_different_email: String { localized(key: "sharing_member_error_invited_with_different_email", table: "iOS-Localizable") }

    /// "Error message"
    /// "We couldn’t find the email address or key for the invitee."
    public static var sharing_member_error_missing_key: String { localized(key: "sharing_member_error_missing_key", table: "iOS-Localizable") }

    /// "Error message"
    /// "The current user does not have admin permission on this share"
    public static var sharing_member_error_not_allowed: String { localized(key: "sharing_member_error_not_allowed", table: "iOS-Localizable") }

    /// "Error message"
    /// "The invitation does not exist"
    public static var sharing_member_error_not_exist: String { localized(key: "sharing_member_error_not_exist", table: "iOS-Localizable") }

    /// "Error message"
    /// "Sharing is temporarily disabled. Please try again later."
    public static var sharing_member_error_temporarily_disabled: String { localized(key: "sharing_member_error_temporarily_disabled", table: "iOS-Localizable") }

    /// "Include message and file name in invite email"
    public static var sharing_member_include_message: String { localized(key: "sharing_member_include_message", table: "iOS-Localizable") }

    /// "Information text"
    /// "Message and file name are stored with zero access encryption when included in the invite email."
    public static var sharing_member_include_message_info: String { localized(key: "sharing_member_include_message_info", table: "iOS-Localizable") }

    /// "Text to indicate invite message is not included"
    /// "not included"
    public static var sharing_member_include_message_not_included: String { localized(key: "sharing_member_include_message_not_included", table: "iOS-Localizable") }

    /// "Section title to set invite message"
    /// "Message for recipient"
    public static var sharing_member_include_message_section_title: String { localized(key: "sharing_member_include_message_section_title", table: "iOS-Localizable") }

    /// "Button title to invite people to access file"
    /// "Add people or group to share"
    public static var sharing_member_invite_button: String { localized(key: "sharing_member_invite_button", table: "iOS-Localizable") }

    /// "Banner text shown after coping invite link"
    /// "Invite link copied"
    public static var sharing_member_invite_link_copied: String { localized(key: "sharing_member_invite_link_copied", table: "iOS-Localizable") }

    /// "Invitation has been sent to the invitee."
    /// "Invite sent"
    public static var sharing_member_invite_send: String { localized(key: "sharing_member_invite_send", table: "iOS-Localizable") }

    /// "Section header of invitee list"
    /// "Who has access"
    public static var sharing_member_invitee_section_header: String { localized(key: "sharing_member_invitee_section_header", table: "iOS-Localizable") }

    /// "Banner text shown after creating public share link"
    /// "Link to this item created"
    public static var sharing_member_link_created: String { localized(key: "sharing_member_link_created", table: "iOS-Localizable") }

    /// "The invitation is still pending as the invitee has not yet responded."
    /// "Pending"
    public static var sharing_member_pending: String { localized(key: "sharing_member_pending", table: "iOS-Localizable") }

    /// "Text to indicate invitee has write permission"
    /// "Can edit"
    public static var sharing_member_permission_can_edit: String { localized(key: "sharing_member_permission_can_edit", table: "iOS-Localizable") }

    /// "Text to indicate invitee has read permission"
    /// "Can view"
    public static var sharing_member_permission_can_view: String { localized(key: "sharing_member_permission_can_view", table: "iOS-Localizable") }

    /// "Section title to set access permission"
    /// "Permission"
    public static var sharing_member_permission_section_title: String { localized(key: "sharing_member_permission_section_title", table: "iOS-Localizable") }

    /// "Placeholder of text field"
    /// "Add people or group"
    public static var sharing_member_placeholder: String { localized(key: "sharing_member_placeholder", table: "iOS-Localizable") }

    /// "Section header"
    /// "Sharing options"
    public static var sharing_member_public_link_header: String { localized(key: "sharing_member_public_link_header", table: "iOS-Localizable") }

    /// "Action title"
    /// "Remove access"
    public static var sharing_member_remove_access: String { localized(key: "sharing_member_remove_access", table: "iOS-Localizable") }

    /// "Banner text shown after resending invitation"
    /// "Invitation\'s email was sent again"
    public static var sharing_member_resend_invitation: String { localized(key: "sharing_member_resend_invitation", table: "iOS-Localizable") }

    /// "Action title to resend invitation"
    /// "Resend invite"
    public static var sharing_member_resend_invite: String { localized(key: "sharing_member_resend_invite", table: "iOS-Localizable") }

    /// "The role of the sharing member is an admin"
    /// "Admin"
    public static var sharing_member_role_admin: String { localized(key: "sharing_member_role_admin", table: "iOS-Localizable") }

    /// "The role of the sharing member is an editor"
    /// "Editor"
    public static var sharing_member_role_editor: String { localized(key: "sharing_member_role_editor", table: "iOS-Localizable") }

    /// "Status label shown next to the item owner in the members list"
    /// "Owner"
    public static var sharing_member_role_owner: String { localized(key: "sharing_member_role_owner", table: "iOS-Localizable") }

    /// "The role of the sharing member is a viewer."
    /// "Viewer"
    public static var sharing_member_role_viewer: String { localized(key: "sharing_member_role_viewer", table: "iOS-Localizable") }

    /// "Action sheet title for enable/disable invitation message "
    /// "Message setting"
    public static var sharing_member_title_message_setting: String { localized(key: "sharing_member_title_message_setting", table: "iOS-Localizable") }

    /// "Information about how many people is invited"
    /// "Sharing with %d person"
    public static func sharing_member_total_invitee(num: Int) -> String { String(format: localized(key: "sharing_member_total_invitee", table: "iOS-Localizable"), num) }

    /// "Banner text when added editor success"
    /// "%d viewer added"
    public static func sharing_member_viewer_added(num: Int) -> String { String(format: localized(key: "sharing_member_viewer_added", table: "iOS-Localizable"), num) }

    /// "How many members in the group"
    /// "%d member"
    public static func sharing_members(num: Int) -> String { String(format: localized(key: "sharing_members", table: "iOS-Localizable"), num) }

    /// "Setting title for Easy Device Migration feature"
    /// "Sign in to another device"
    public static var sign_in_to_another_device: String { localized(key: "sign_in_to_another_device", table: "iOS-Localizable") }

    /// "Start using Proton Drive"
    public static var sign_up_succeed_text: String { localized(key: "sign_up_succeed_text", table: "iOS-Localizable") }

    /// "Label text, sort files by file type"
    /// "File type"
    public static var sort_type_file_type: String { localized(key: "sort_type_file_type", table: "iOS-Localizable") }

    /// "Label text, sort files by last modified date"
    /// "Last modified"
    public static var sort_type_last_modified: String { localized(key: "sort_type_last_modified", table: "iOS-Localizable") }

    /// "Label text, sort files by file name"
    /// "Name"
    public static var sort_type_name: String { localized(key: "sort_type_name", table: "iOS-Localizable") }

    /// "Label text, sort files by file size"
    /// "Size"
    public static var sort_type_size: String { localized(key: "sort_type_size", table: "iOS-Localizable") }

    /// "Banner text on the state banner"
    /// "Your account is at risk of deletion"
    public static var state_at_risk_of_deletion: String { localized(key: "state_at_risk_of_deletion", table: "iOS-Localizable") }

    /// "To avoid data loss, ask your admin to upgrade."
    public static var state_at_risk_of_deletion_desc: String { localized(key: "state_at_risk_of_deletion_desc", table: "iOS-Localizable") }

    /// "Text shown on the state banner"
    /// "Backing up..."
    public static var state_backing_up: String { localized(key: "state_backing_up", table: "iOS-Localizable") }

    /// "Banner text on the state banner when backup complete"
    /// "Backup complete"
    public static var state_backup_complete_title: String { localized(key: "state_backup_complete_title", table: "iOS-Localizable") }

    /// "Banner text on the state banner when backup is disabled"
    /// "Backup is disabled"
    public static var state_backup_disabled_title: String { localized(key: "state_backup_disabled_title", table: "iOS-Localizable") }

    /// "Text shown when user enable cellular"
    /// "Photos backup is now allowed also on mobile data"
    public static var state_cellular_is_enabled: String { localized(key: "state_cellular_is_enabled", table: "iOS-Localizable") }

    /// "Banner text on the state banner when device doesn\'t have connection"
    /// "No internet connection"
    public static var state_disconnection_title: String { localized(key: "state_disconnection_title", table: "iOS-Localizable") }

    /// "Banner text on the state banner"
    /// "Your Drive storage is full"
    public static var state_drive_storage_full: String { localized(key: "state_drive_storage_full", table: "iOS-Localizable") }

    /// "Text shown on the state banner"
    /// "Encrypting..."
    public static var state_encrypting: String { localized(key: "state_encrypting", table: "iOS-Localizable") }

    /// "Banner text on the state banner when backup issues detected "
    /// "Backup: issues detected"
    public static var state_issues_detected_title: String { localized(key: "state_issues_detected_title", table: "iOS-Localizable") }

    /// "Banner text on the state banner"
    /// "Your Mail storage is full"
    public static var state_mail_storage_full: String { localized(key: "state_mail_storage_full", table: "iOS-Localizable") }

    /// "To send or receive emails, free up space or upgrade for more storage."
    public static var state_mail_storage_full_desc: String { localized(key: "state_mail_storage_full_desc", table: "iOS-Localizable") }

    /// "Banner text on the state banner when device doesn\'t connect to wifi"
    /// "Wi-Fi needed for backup"
    public static var state_need_wifi_title: String { localized(key: "state_need_wifi_title", table: "iOS-Localizable") }

    /// "Banner text on the state banner when lacking permission to access photos"
    /// "Permission required for backup"
    public static var state_permission_required_title: String { localized(key: "state_permission_required_title", table: "iOS-Localizable") }

    /// "Getting ready to back up"
    public static var state_ready_title: String { localized(key: "state_ready_title", table: "iOS-Localizable") }

    /// "Button text on the state banner for retrying the backup"
    /// "Retry"
    public static var state_retry_button: String { localized(key: "state_retry_button", table: "iOS-Localizable") }

    /// "Finding new photos…"
    public static var state_searching_for_new_photos: String { localized(key: "state_searching_for_new_photos", table: "iOS-Localizable") }

    /// "Loading photo library…"
    public static var state_setting_up_library: String { localized(key: "state_setting_up_library", table: "iOS-Localizable") }

    /// "Button text on the state banner for opening permission settings"
    /// "Settings"
    public static var state_settings_button: String { localized(key: "state_settings_button", table: "iOS-Localizable") }

    /// "Banner text on the state banner "
    /// "Your storage is full"
    public static var state_storage_full: String { localized(key: "state_storage_full", table: "iOS-Localizable") }

    /// "To upload files, free up space or upgrade for more storage."
    public static var state_storage_full_desc: String { localized(key: "state_storage_full_desc", table: "iOS-Localizable") }

    /// "Banner text on the state banner when storage full"
    /// "Device storage full"
    public static var state_storage_full_title: String { localized(key: "state_storage_full_title", table: "iOS-Localizable") }

    /// "Banner text on the state banner to indicate subscription is expired"
    /// "Your subscription has ended"
    public static var state_subscription_has_ended: String { localized(key: "state_subscription_has_ended", table: "iOS-Localizable") }

    /// "Upgrade to restore full access and to avoid data loss."
    public static var state_subscription_has_ended_desc: String { localized(key: "state_subscription_has_ended_desc", table: "iOS-Localizable") }

    /// "Banner text on the state banner when backend has problems "
    /// "The upload of photos is temporarily unavailable"
    public static var state_temp_unavailable_title: String { localized(key: "state_temp_unavailable_title", table: "iOS-Localizable") }

    /// "Button text on the state banner for turning on backup"
    /// "Turn on"
    public static var state_turnOn_button: String { localized(key: "state_turnOn_button", table: "iOS-Localizable") }

    /// "Button text on the state banner for enabling cellular"
    /// "Use Cellular"
    public static var state_use_cellular_button: String { localized(key: "state_use_cellular_button", table: "iOS-Localizable") }

    /// "Alert message"
    /// "This will delete the link and remove access to your file or folder for anyone with the link. You can’t undo this action."
    public static var stop_sharing_alert_message: String { localized(key: "stop_sharing_alert_message", table: "iOS-Localizable") }

    /// "Alert title"
    /// "Stop sharing"
    public static var stop_sharing_alert_title: String { localized(key: "stop_sharing_alert_title", table: "iOS-Localizable") }

    /// "Banner text"
    /// "Sharing removed"
    public static var stop_sharing_success_text: String { localized(key: "stop_sharing_success_text", table: "iOS-Localizable") }

    /// "Complete these steps in your first 30 days for a free storage upgrade."
    public static var storage_bonus_checklist_subtitle: String { localized(key: "storage_bonus_checklist_subtitle", table: "iOS-Localizable") }

    /// "Get your 3 GB storage bonus"
    public static var storage_bonus_checklist_title: String { localized(key: "storage_bonus_checklist_title", table: "iOS-Localizable") }

    /// "Tab bar title"
    /// "Files"
    public static var tab_bar_title_files: String { localized(key: "tab_bar_title_files", table: "iOS-Localizable") }

    /// "Tab bar title"
    /// "Photos"
    public static var tab_bar_title_photos: String { localized(key: "tab_bar_title_photos", table: "iOS-Localizable") }

    /// "Tab bar title"
    /// "Shared"
    public static var tab_bar_title_shared: String { localized(key: "tab_bar_title_shared", table: "iOS-Localizable") }

    /// "Tab bar title"
    /// "Shared with me"
    public static var tab_bar_title_shared_with_me: String { localized(key: "tab_bar_title_shared_with_me", table: "iOS-Localizable") }

    /// "Information banner text"
    /// "Photo library update in progress. To speed things up, the app will keep your screen awake during the process."
    public static var tags_migration_banner_text: String { localized(key: "tags_migration_banner_text", table: "iOS-Localizable") }

    /// "Description of migration popup"
    /// "Processing happens on your device, keeping photos secure with end-to-end encryption."
    public static var tags_migration_e2e: String { localized(key: "tags_migration_e2e", table: "iOS-Localizable") }

    /// "Headline of tags migration popup"
    /// "More ways to filter your photos"
    public static var tags_migration_headline: String { localized(key: "tags_migration_headline", table: "iOS-Localizable") }

    /// "Description of migration popup"
    /// "This may take a while, but you can keep using the app while we set it up."
    public static var tags_migration_keep_awake: String { localized(key: "tags_migration_keep_awake", table: "iOS-Localizable") }

    /// "Description of migration popup"
    /// "We’re updating your library to help you quickly sort photos, like by Screenshots."
    public static var tags_migration_new_filter: String { localized(key: "tags_migration_new_filter", table: "iOS-Localizable") }

    /// "Button for creating new photo"
    /// "Take new photo"
    public static var take_new_photo_button: String { localized(key: "take_new_photo_button", table: "iOS-Localizable") }

    /// "label text"
    /// "Something gone wrong, please try again later"
    public static var technical_error_placeholder: String { localized(key: "technical_error_placeholder", table: "iOS-Localizable") }

    /// "Label text is shown when pull down"
    /// "Pull to refresh"
    public static var text_pull_to_refresh: String { localized(key: "text_pull_to_refresh", table: "iOS-Localizable") }

    /// "Button title for deleting item. e.g. Delete file, Delete item, Delete folder..etc"
    /// "Delete %@"
    public static func trash_action_delete_file_button(type: String) -> String { String(format: localized(key: "trash_action_delete_file_button", table: "iOS-Localizable"), type) }

    /// "Alert title shown when user attempts to delete file"
    /// "%@ will be deleted permanently.\nDelete anyway?"
    public static func trash_action_delete_permanently_confirmation_title(type: String) -> String { String(format: localized(key: "trash_action_delete_permanently_confirmation_title", table: "iOS-Localizable"), type) }

    /// "Button title"
    /// "Empty trash"
    public static var trash_action_empty_trash: String { localized(key: "trash_action_empty_trash", table: "iOS-Localizable") }

    /// "The type will be specified afterwards, e.g., \'Restore file,\' \'Restore 2 folders,\' etc."
    /// "Restore %@"
    public static func trash_action_restore(type: String) -> String { String(format: localized(key: "trash_action_restore", table: "iOS-Localizable"), type) }

    /// "Action to restore all trashed files"
    /// "Restore all files"
    public static var trash_action_restore_all_files: String { localized(key: "trash_action_restore_all_files", table: "iOS-Localizable") }

    /// "Action to restore all trashed files"
    /// "Restore all folders"
    public static var trash_action_restore_all_folders: String { localized(key: "trash_action_restore_all_folders", table: "iOS-Localizable") }

    /// "Action to restore all trashed items"
    /// "Restore all items"
    public static var trash_action_restore_all_items: String { localized(key: "trash_action_restore_all_items", table: "iOS-Localizable") }

    /// "The type will be specified afterwards, e.g., \'Restore selected 2 files,\' \'Restore selected 1 folder,\' etc."
    /// "Restore selected %@"
    public static func trash_action_restore_selected(type: String) -> String { String(format: localized(key: "trash_action_restore_selected", table: "iOS-Localizable"), type) }

    /// "Message of the empty trash screen"
    /// "Items moved to the trash will stay here until deleted"
    public static var trash_empty_message: String { localized(key: "trash_empty_message", table: "iOS-Localizable") }

    /// "Title of the share folder when no items are trashed"
    /// "Trash is empty"
    public static var trash_empty_title: String { localized(key: "trash_empty_title", table: "iOS-Localizable") }

    /// "An error if the user tries to save a file from the share extension without being logged in"
    /// "Please authenticate before saving file(s)"
    public static var universalLink_incoming_auth_error: String { localized(key: "universalLink_incoming_auth_error", table: "iOS-Localizable") }

    /// "An error if the user opens ProtonFile without being logged in"
    /// "Please authenticate before opening the file"
    public static var universalLink_protonFile_auth_error: String { localized(key: "universalLink_protonFile_auth_error", table: "iOS-Localizable") }

    /// "View title shown on unlock app page "
    /// "Unlock App"
    public static var unlock_app_title: String { localized(key: "unlock_app_title", table: "iOS-Localizable") }

    /// "Title of an update banner"
    /// "Update Required"
    public static var update_required_title: String { localized(key: "update_required_title", table: "iOS-Localizable") }

    /// "Information text shown when user uploading files"
    /// "For uninterrupted uploads, keep the app open. Uploads will pause when the app is in the background."
    public static var upload_disclaimer: String { localized(key: "upload_disclaimer", table: "iOS-Localizable") }

    /// "Button for uploading new photo"
    /// "Upload a photo"
    public static var upload_photo_button: String { localized(key: "upload_photo_button", table: "iOS-Localizable") }

    /// "Create a new album to add photos"
    /// "Add to new album"
    public static var action_add_to_new_album: String { localized(key: "action_add_to_new_album", table: "shared-Localizable") }

    /// "action title to delete album"
    /// "Delete album"
    public static var action_delete_album: String { localized(key: "action_delete_album", table: "shared-Localizable") }

    /// "action title to delete album"
    /// "Delete without saving"
    public static var action_delete_without_saving: String { localized(key: "action_delete_without_saving", table: "shared-Localizable") }

    /// "Action title to leave album shared to me "
    /// "Leave album"
    public static var action_leave_album: String { localized(key: "action_leave_album", table: "shared-Localizable") }

    /// "Create a new shared album to share photos"
    /// "New shared album"
    public static var action_new_shared_album: String { localized(key: "action_new_shared_album", table: "shared-Localizable") }

    /// "Button title to remove selected photos from the album"
    /// "Remove from album"
    public static var action_remove_photos: String { localized(key: "action_remove_photos", table: "shared-Localizable") }

    /// "Button title to rename album"
    /// "Rename album"
    public static var action_rename_album: String { localized(key: "action_rename_album", table: "shared-Localizable") }

    /// "action title to save photos and delete album"
    /// "Save photos and remove"
    public static var action_save_and_remove: String { localized(key: "action_save_and_remove", table: "shared-Localizable") }

    /// "Share photos via link"
    /// "Send link"
    public static var action_send_link: String { localized(key: "action_send_link", table: "shared-Localizable") }

    /// "Set the selected photo as album cover"
    /// "Set as album cover"
    public static var action_set_as_album_cover: String { localized(key: "action_set_as_album_cover", table: "shared-Localizable") }

    /// "Action title to sort items"
    /// "Sort"
    public static var action_sort: String { localized(key: "action_sort", table: "shared-Localizable") }

    /// "Message shown to user when edit album success"
    /// "Edits saved"
    public static var album_edit_saved: String { localized(key: "album_edit_saved", table: "shared-Localizable") }

    /// "Warning message when the user tries to delete selected photos from the album\nPLEASE keep `, %d` in the end, this is to fix plural limitation"
    /// "What would you like to do with this item?,%d"
    public static func album_photo_remove_warning(num: Int) -> String { String(format: localized(key: "album_photo_remove_warning", table: "shared-Localizable"), num) }

    /// "Are you sure you want to remove the selected item(s) from your album?"
    public static var album_photo_remove_warning_admin: String { localized(key: "album_photo_remove_warning_admin", table: "shared-Localizable") }

    /// "Remove"
    public static var album_photo_remove_warning_admin_confirmation: String { localized(key: "album_photo_remove_warning_admin_confirmation", table: "shared-Localizable") }

    /// "Warning message when the user tries to delete selected photos from the album\nPLEASE keep `, %d` in the end, this is to fix plural limitation"
    /// "You’ll lose access to this photo. If you haven’t already, save it to your photo timeline before removing it from the album."
    public static func album_photo_remove_warning_editor(num: Int) -> String { String(format: localized(key: "album_photo_remove_warning_editor", table: "shared-Localizable"), num) }

    /// "Continue"
    public static var album_photo_remove_warning_editor_continue: String { localized(key: "album_photo_remove_warning_editor_continue", table: "shared-Localizable") }

    /// "Textfield placeholder"
    /// "Album name"
    public static var create_album_placeholder: String { localized(key: "create_album_placeholder", table: "shared-Localizable") }

    /// "Alert message to delete album"
    /// "Are you sure you want to delete the album “%@”? The photos will not be deleted."
    public static func delete_album_alert_message(name: String) -> String { String(format: localized(key: "delete_album_alert_message", table: "shared-Localizable"), name) }

    /// "Alert title to delete album"
    /// "Delete “%@”"
    public static func delete_album_alert_title(name: String) -> String { String(format: localized(key: "delete_album_alert_title", table: "shared-Localizable"), name) }

    /// "Warning text before deleting album that contains photos don\'t in the photo stream"
    /// "Some photos in this album are not saved to your timeline. Deleting this album will permanently delete those photos.\n\nWould you like to save them before removing?"
    public static var delete_album_and_move_alert_message: String { localized(key: "delete_album_and_move_alert_message", table: "shared-Localizable") }

    /// "Shown in tray app"
    /// "Detecting remote changes"
    public static var detecting_remote_changes: String { localized(key: "detecting_remote_changes", table: "shared-Localizable") }

    /// "Title shown in the view when device is disconnected"
    /// "Your device has no connection"
    public static var disconnection_view_title: String { localized(key: "disconnection_view_title", table: "shared-Localizable") }

    /// "Gallery title to display the album gallery"
    /// "Albums"
    public static var gallery_title_albums: String { localized(key: "gallery_title_albums", table: "shared-Localizable") }

    /// "Gallery title to display the photo gallery"
    /// "Photos"
    public static var gallery_title_photos: String { localized(key: "gallery_title_photos", table: "shared-Localizable") }

    /// "Button to add photo...etc"
    /// "Add"
    public static var general_add: String { localized(key: "general_add", table: "shared-Localizable") }

    /// "Button to edit, edit title...etc"
    /// "Edit"
    public static var general_edit: String { localized(key: "general_edit", table: "shared-Localizable") }

    /// "Banner message shown after the selected items have been successfully added to the album"
    /// "%d item added to album"
    public static func item_add_to_album(num: Int) -> String { String(format: localized(key: "item_add_to_album", table: "shared-Localizable"), num) }

    /// "Banner message shown after the selected items have been successfully added to the photo stream"
    /// "%d item added to your stream"
    public static func item_add_to_photo_stream(num: Int) -> String { String(format: localized(key: "item_add_to_photo_stream", table: "shared-Localizable"), num) }

    /// "Banner message shown after the selected items already exist in the album"
    /// "%d item already exist"
    public static func item_already_exist(num: Int) -> String { String(format: localized(key: "item_already_exist", table: "shared-Localizable"), num) }

    /// "Banner message shown after the selected items are not fully uploaded"
    /// "%d item is not fully uploaded"
    public static func item_failed_incomplete(num: Int) -> String { String(format: localized(key: "item_failed_incomplete", table: "shared-Localizable"), num) }

    /// "Failed to add the selected photos to the album."
    /// "%d item failed to add"
    public static func item_failed_to_add(num: Int) -> String { String(format: localized(key: "item_failed_to_add", table: "shared-Localizable"), num) }

    /// "Failed to remove the selected photos to the album."
    /// "%d item failed to remove"
    public static func item_failed_to_remove(num: Int) -> String { String(format: localized(key: "item_failed_to_remove", table: "shared-Localizable"), num) }

    /// "Banner message shown after the selected items have been successfully removed from the album"
    /// "%d item removed from album"
    public static func item_remove_from_album(num: Int) -> String { String(format: localized(key: "item_remove_from_album", table: "shared-Localizable"), num) }

    /// "Banner message shown after the selected items have been successfully removed from the photo stream"
    /// "%d item removed from stream"
    public static func item_remove_from_photo_stream(num: Int) -> String { String(format: localized(key: "item_remove_from_photo_stream", table: "shared-Localizable"), num) }

    /// "Listing local files and folders"
    public static var listing_local_files: String { localized(key: "listing_local_files", table: "shared-Localizable") }

    /// "name validation error, the name only contains dot which is not allowed "
    /// "\".\" is not a valid name"
    public static var name_validation_dot: String { localized(key: "name_validation_dot", table: "shared-Localizable") }

    /// "name validation error, name contains invisible characters"
    /// "Name cannot include invisible characters, / or \\."
    public static var name_validation_invisible_chars: String { localized(key: "name_validation_invisible_chars", table: "shared-Localizable") }

    /// "Name must not begin with a space"
    public static var name_validation_leading_white: String { localized(key: "name_validation_leading_white", table: "shared-Localizable") }

    /// "name validation error, given empty name"
    /// "Name must not be empty"
    public static var name_validation_non_empty: String { localized(key: "name_validation_non_empty", table: "shared-Localizable") }

    /// "name validation error, longer than 255"
    /// "Name is too long"
    public static var name_validation_too_long: String { localized(key: "name_validation_too_long", table: "shared-Localizable") }

    /// "Name must not end with a space"
    public static var name_validation_trailing_white: String { localized(key: "name_validation_trailing_white", table: "shared-Localizable") }

    /// "name validation error, the name only contains 2 dots which is not allowed "
    /// "\"..\" is not a valid name"
    public static var name_validation_two_dot: String { localized(key: "name_validation_two_dot", table: "shared-Localizable") }

    /// "Label for button which opens a file"
    /// "Open"
    public static var open: String { localized(key: "open", table: "shared-Localizable") }

    /// "Add selected photos to shared album"
    /// "Add to shared album"
    public static var section_add_to_shared_album: String { localized(key: "section_add_to_shared_album", table: "shared-Localizable") }

    /// "Section title for share options"
    /// "Share via"
    public static var section_share_via: String { localized(key: "section_share_via", table: "shared-Localizable") }

    /// "Newest first"
    public static var sort_newest_first: String { localized(key: "sort_newest_first", table: "shared-Localizable") }

    /// "Oldest first"
    public static var sort_oldest_first: String { localized(key: "sort_oldest_first", table: "shared-Localizable") }

    /// "Recently added"
    public static var sort_recently_added: String { localized(key: "sort_recently_added", table: "shared-Localizable") }

    /// "Filter tag to show all photos"
    /// "All"
    public static var tag_all: String { localized(key: "tag_all", table: "shared-Localizable") }

    /// "Filter tag to show burst"
    /// "Burst"
    public static var tag_burst: String { localized(key: "tag_burst", table: "shared-Localizable") }

    /// "Filter tag to show favorite photos"
    /// "Favorites"
    public static var tag_favorites: String { localized(key: "tag_favorites", table: "shared-Localizable") }

    /// "Filter tag to show live photos"
    /// "Live Photos"
    public static var tag_livePhotos: String { localized(key: "tag_livePhotos", table: "shared-Localizable") }

    /// "Filter tag to show motion photos"
    /// "Motion Photos"
    public static var tag_motionPhotos: String { localized(key: "tag_motionPhotos", table: "shared-Localizable") }

    /// "Filter tag to show my albums"
    /// "My albums"
    public static var tag_myAlbum: String { localized(key: "tag_myAlbum", table: "shared-Localizable") }

    /// "Filter tag to show panoramas"
    /// "Panoramas"
    public static var tag_panoramas: String { localized(key: "tag_panoramas", table: "shared-Localizable") }

    /// "Filter tag to show portraits"
    /// "Portraits"
    public static var tag_portraits: String { localized(key: "tag_portraits", table: "shared-Localizable") }

    /// "Filter tag to show raw photo"
    /// "RAW"
    public static var tag_raw: String { localized(key: "tag_raw", table: "shared-Localizable") }

    /// "Filter tag to show screenshot"
    /// "Screenshots"
    public static var tag_screenshots: String { localized(key: "tag_screenshots", table: "shared-Localizable") }

    /// "Filter tag to show selfies"
    /// "Selfies"
    public static var tag_selfies: String { localized(key: "tag_selfies", table: "shared-Localizable") }

    /// "Filter tag to show album shared by me"
    /// "Shared"
    public static var tag_shared: String { localized(key: "tag_shared", table: "shared-Localizable") }

    /// "Filter tag to show album shared with me"
    /// "Shared with me"
    public static var tag_sharedWithMe: String { localized(key: "tag_sharedWithMe", table: "shared-Localizable") }

    /// "Filter tag to show videos"
    /// "Videos"
    public static var tag_videos: String { localized(key: "tag_videos", table: "shared-Localizable") }

    /// "View title"
    /// "Rename Album"
    public static var title_rename_album: String { localized(key: "title_rename_album", table: "shared-Localizable") }

}

#endif
