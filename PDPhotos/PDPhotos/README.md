# API

Contains client-BE code.

# Use cases

Domain level objects building on top of API and data layer (updating / reading local cache - CoreData)

# Scenes folder

Contains copied and adjusted stacks that should work for both old Gallery and new Albums.
Consider adding new subfeatures to the folders listed below or - if it's of substantial size, adding new subfolder. 

- `Gallery`
  - Contains reworked old Gallery including Tags switching
- `Albums`
  - Contains new Albums feature stacks
- Common
  - Contains common stuff, thumbnails, possibly selection etc

# Dependency injection

- Objects that need to survive view's lifecycles or need to be shared across multiple views are held in `Container`.
- Instances are created by `Factory` objects, which are stateless.
- Every subfeature should have its own `Factory` and when necessary, also `Container`

Top level object is `PDPhotosContainer`. This one holds any dependencies needed further in the graph.

It spawns `PhotosScenesContainer` when necessary, which holds any presentation-relevant objects, that are shared by
multiple instances (for example `MetadataController`, which should be shared by both `gallery` and `albums).

This one should hold two containers: `GallerySceneContainer` and `AlbumsSceneContainer`. The above pattern repeats.
