# ProtonFile opening

Proton document is a special type of `Node`, for which we don't download binary data, but instead use its id to redirect to an editor.

## Types of incoming data
Depending from where the opening is triggered from (mac / iOS, main app / extension), we either have it's `NodeIdentifier`, or just a URL which may contain `linkId` and `shareId`. Both need to be checked against our local DB so we verify it's a valid protondoc and then it can be used to redirect to editor.
The parsing is done in `ProtonFileIdentifierInteractor`.

## Types of redirection
There are two types:
- redirect to external browser
- opening in-app in webview

### Redirect to external browser
After we have the parsed identifier, we construct an external URL and open it in external browser. 
This is synchronous operation, we just need to append the ids to a given `docs.proton` url.
The whole URL creation flow is captured in `ProtonFileNonAuthenticatedURLInteractorProtocol`.

### Opening in-app in webview
1. We need an authenticated session for this. That means creating a session fork and passing necessary data to web via `Payload` attribute.
    - `ProtonFileAuthenticatedWebSessionInteractor`
2. After that we construct an authenticated `login` url with `returnURL` attribute, so web can redirect to editor after it verifies authenticated session.
    - `ProtonFileAuthenticatedDataInteractor`
Due to this extra work, it is an async operation which should be reflected in UI.
