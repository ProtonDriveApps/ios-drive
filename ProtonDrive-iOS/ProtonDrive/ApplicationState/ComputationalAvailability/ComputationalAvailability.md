# Computational availability

## Goals
Monitoring computational availability at one place gives us power to:
1) react to change of states
    - start work when it's possible
    - stop work when necessary
2) differentiate between states
    - For example in some work-enabled states we want to constrain the work to make it more robust.

## Types of availability
- `foreground` - normal run of app
- `suspended` - backgrounded / paused operation. No work should be done
- `extensionTask` - shortlived state (~ 30 sec) triggered just as the app transitions from `foreground` to `suspended`. Work can be continued but with respect to approaching suspension.
    - it is expected that this task is only triggered by us if we have work to do.
- `processingTask` - period of time when app can wake from `suspended` time. This window is either ended by:
    - the task expiring - all work must be stopped and app goes back to `suspended` state`
    - all work being done - task should be stopped and app goes back to `suspended` state`
    - app transitions to `foreground` - work can be continued

## Code dependencies
`Extension` state is app wide - multiple app modules share the same task. That means that extension state is set from a shared BG mode object (`ExtensionBackgroundOperationController`).
`Processing` state is specific to each module. That means, that each module utilizing the computational availability state needs to have its own instance of `ComputationalAvailabilityController` because it needs to inject its own `processingController: BackgroundTaskStateController` because livecycles of different processing tasks are independent. 

## Debugging
It's possible to simulate run of BG task while being attached to the debugger. Steps described here: https://developer.apple.com/documentation/backgroundtasks/starting-and-terminating-tasks-during-development
Note that when these commands are used, the OS will run the BG task at high priority, and so these commands cannot be used to debug expiration conditions. The OS usually expires a BG task in anything between a few seconds and a few minutes under normal conditions, but runs it indefinitely when using the debug command.

### Example:
```
e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"ch.protonmail.protondrive.photosProcessing"]
e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateExpirationForTaskWithIdentifier:@"ch.protonmail.protondrive.photosProcessing"]
```
