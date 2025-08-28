# Gallery

## View hierarchy

- `GalleryRootView`
  - assumes bootstrapping is done and tries to combine permissions & backup & fetching sources to derive the content
  - switches content between onboarding / permissions / gallery / error page
- `PhotosGalleryView`
  - assumes permissions were given or remote items are fetched or backup is enabled
  - switches content between loading / grid / placeholder / empty
  - `loading`, `placeholder` is embeded in scrollview to allow pull to refresh (not grid, which needs its own scrollview)
- `PhotosGridView`
  - assumes there are items to be displayed
  - needs to handle pull to refresh itself to avoid multiple nested scrollviews

### Banners View

Is displayed over `PhotosGalleryView` (in case loading / placeholder is shown). Or in `PhotosGridView` to allow
content inset updating (the banners are to be hidden when scrollview is scrolled).

Is a compound of:
- `PhotosStorageView`
- `LockingBannerView`
- `PhotosStateView`

### Illustration

-----------------------|
| GalleryRootView      |
|                      |
|  |-------------------|
|  | PhotosGalleryView |
|  |                   |
|  |  |----------------|
|  |  | PhotosGridView |
|  |  | ▯▯▯            |
|  |  | ▯▯▯            |
|  |  |----------------|
|  |-------------------|
|----------------------|
