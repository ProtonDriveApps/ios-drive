# Proton Drive iOS

## iOS Client Trust Model
x  | Device Storage | Device Memory | Keychain | SecureEnclave | Transport | iCloud | Device backup
--- | --- | --- | --- | --- | --- | --- | ---
Trust level | **Low** | **Moderate** | **Low** | **High** | **Low** | **Low** | **Low**
Compromise conditions | Sandbox escape is enough | Requires either kernel compromised or binary modified, coupled to app version | Codesigning compromise is enough | No known attacks yet | Person in the middle attacks | Not controlled by us | May be stolen when stored off device
Solution | MainKey | Not much can be done | MainKey | _ | Certificate pinning | Do not use | Exclude sensitive information from device backups

## Local Data
As most iOS appications, our application needs to store some data locally:
- nodes metadata
- encrypted blocks of files
- cleartext files (during preview or import)
- private and public account keys
- details of user account
- access token for communication with back end

Some of these pieces of data is kept in Keychain, some in our local CoreData database, and some in UserDefaults dictionary, and some inside the application or developer group directories. In order to integrate with FileProvidar system API, these caches need to be accessible from both main app process and application extension: we use App Groups and Keychain Groups for that. iOS offers high level of data protection using Keychain Data Protection and File Data Protection classes, but on top of them we've introduced our own additional layer of protection called MainKey mechanism (for cases when user has TouchID/FaceID or PIN is active).

App uses native QuickLook framework as an in-app previewer of cleartext files. 

Cleartext files are not stored for longer than is absolutely needed:
1. during presentation in the in-app previewer;
2. during upload process.

Object | Access | Disclosure | Modification | Access denial
--- | --- | --- | --- | ---
CoreData (Nodes, Revisions, Blocks, Thumbnails, Shares, Volumes, ShareURLs) | **Critical** |  **Critical** | **Critical**: can mislead user on this device until relogin | **Moderate**: poor UX
Encrypted files | **Low** | **Low** | **Low** | **Moderate**: poor UX
Cleartext files | **Critical** | **Critical** | **Critical**: can pose an attack vector | **Moderate**: poor UX
Account Private and Public Keys | **Critical**: allows decryption of messages caught in the air | **Critical**: allows decryption of old messages | **Critical**: in some circumstances can lead to impersonation | **Moderate**: objects will not be properly encrypted or decrypted
Account detals | **Critical**: connects account to person | **Critical**: connects account to person | **Low** | **Low**
Authentication token | **High**: allows to steal session | **High**: session can be closed from website | **Low**: wrong token leads to correct logout | **Low**: no token leads to correct logout

### Default Data Protection
Most Keychain items are saved with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` flag. We could not use more strict flags because its pretty common that app needs to complete its work in background even when the device is locked - for example, when user is uploading or downloading blocks of files. In order to share them across all our application extensions (Share and Push Application Extensions), we keep them in one Keychain Access Group. We do not want them to be restorable from backup on ther devices.

Data protection class for files is set as `NSFileProtectionComplete` in app entitlements with a default exceptions for CoreData and UserDefaults files, which we need to access in background and when the device is locked.

More information is available in [iOS Security](https://www.apple.com/business/docs/site/iOS_Security_Guide.pdf) documentation.

### MainKey* Encryption
In order to increase our chances to protect the data when iOS sandbox is compromised or when rogue application managed to dump keychain, we've introduced MainKey protection system.
The idea is to encrypt all sensible local data with per-login local key called MainKey, which will not be stored in compromisable places.

MainKey may be persisted by means of 2 techniques:
- _TouchID/FaceID protection._ SecureEnclave chip generates asymmetric keypair, keep private key inside and give public key to the app. We encrypt MainKey with public key and save to Keychain, asking SecureEnclave to decrypt it every time we need to retrieve cleartext MainKey. SecureEnclave decrypt the MainKey only after biometric authentication or device passcode and the private key never leaves it.
- _PIN protection._ We can derive temporary key from user-input PIN string, symmetrically encrypt MainKey with this temporary key and save cyphertext to Keychain. Temporary key and PIN string are never persisted and are removed from memory as fast as possible. No PIN input - no access to MainKey.
- _No protection._ For cases when user does not want to switch on additional protection in app Settings, MainKey is saved cleartext in Keychain. This case is weak against forensic attacks in cases when device is compromised, but the data should not be extractable from backups. This case is trivial and will not be discussed furter.

MainKey protects:
1. Attributes of items saved in CoreData that are not otherwise encrypted (ex: signature email of file revision, local URL of downloaded file block)
2. User account and account encryption keys
3. Authentication token

On every app launch MainKey cyphertext from Keychain should be decrypted and placed into memory of the app process before any other part of the app will start its work. That's why the app is not functional unless user enters PIN/TouchID/FaceID - the app can not access local data and does not know anything about user to request data from server.
Side effect of this architecture is that Share extension requires authentication every time, as it runs in separate process.

MainKey is kept in memory of the app process according to Autolock Time settings: it can be removed from memory after certain amount of time or each time apps goes background.

_*In other Proton publications MainKey mechanism is referred to as AppKey mechanism_
