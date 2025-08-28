# Migration of photo share

## PhotoVolumeMigrationController

Has 2 entry points:
 
### `startMigration`

Should be triggered to start migration. What will happen:

1. `POST migrate/legacy` (to trigger the async BE job)
2. clean up local state (delete logacy photo Share and all its Photos, including their root and Shares)
3. start monitoring the migration via `GET migrate/legacy`

### `monitorMigration`

Should be triggered when we already know BE is performing the migration, so we need to start monitoring it:

1. opportunistically clean up local state (delete logacy photo Share and all its Photos, including their root and Shares)
  - this may have been already done, if the user triggered the migration in previous app launch
  - this may not be done if the user triggered the migration on another client
2. start monitoring the migration via `GET migrate/legacy`

### After that's done

After migration status reports finish, we invoke bootstrapping to fetch new volume.

## Observing the migration progress

Is implemented in `AsynchronousPhotoVolumeMigrationUpdateFacade`. It fetches migration status repeatedly
with some delay (10s) until there's a success. In case of errors it adds exponential backoff to the delay.

Until we receive a success, we keep the `inProgress` state to block the UI. 
