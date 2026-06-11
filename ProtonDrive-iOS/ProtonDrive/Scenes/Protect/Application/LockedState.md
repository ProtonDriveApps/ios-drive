# Locked state

The user can enable autolocking of the app in Settings. It can be unlocked either via biometry or by a PIN. Either of those locking mechanisms encrypts a main key which is used to encrypt sensitve attributes of some of the CoreData objects.

There's one implicit assumption to make the encryption & decryption work nicely - no read or write of the sensitive attributes should happen while the main key is locked.

Since there is currently no way to make sure the above assumption is fulfilled, we have added extra step after unlocking - refreshing all CD objects in all relevant contexts. This makes sure that in case we tried to read a sensitive attribute during locked period (which would result in that attribute being set to `nil`) - this erroneous value is not propagated and saved by mistake after the app is unlocked.

Of course this is a bit fragile and will be subject to refactoring soon. 
