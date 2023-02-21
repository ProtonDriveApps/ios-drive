
# Background Operations

## Basic idea
If we move the app from foreground to background (minimizing etc), we need to ask for system resources to be able to continue with work. There are two types of operations (see below), which we never use simultaneously.
Since we don't want to overuse these system provided resources, so we only ask for the tasks/start them when we atually have work to do. We also need to be good citizens with completing the work and tasks when the system tells us.

## Types of operations
- `Extension` - operation which extends foreground mode - is started immediatelly after going to background and lasts usually for 30 sec (if work is not finished earlier)
- `Processing` - we have to ask for this one and we have no control over timing of it. We just register a request to the system and it gives us `BGTask` at some point in future. We can set the earliest begin date.

## Application flow 
We only start the `extension` task when we have work in progress. If `extension` expires with work remaining to be done, we schedule the `processing` task and stop the work. Then, when system notifies us about task starting, we again start the work. If it expires without the work being done, we reschedule the task again. If the work is done (either in extension or processing), no other task is scheduled.  

## Code structure
We devided the logic into three layers:
- Resource - objects we use to invoke system APIs
- Domain - abstraction of business logic (Interactors)
- Application - top level logic controlling the rest of layers (controlling when to start/stop work)
The whole structure is held in authenticated DI container.

## Specifics of `UPLOAD`
Right now, if we fail to complete the upload in 3 hours, the file urls expire on backend so any upload after that date will result in failure.

### Points to be discussed/tested:
When user goes to foreground even though that background task is scheduled and work is to be done, user sees `upload failed` banner. We don't try to restart when app transitions to foreground.
The earliest processing task delay is set to 1 minute. This means, if processing expires, it's rescheduled in another 1 minute (but is not promised by the system, it can be much longer). This could lead to draining battery (needs tests/discussion).
