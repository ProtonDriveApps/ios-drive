# ProcessEligibility

Generic domain to communicate state of a given process to other components. It marks if depending processes are eligible to run.

## Example

A `Downloader` process needs to be observed and its performance tracked. However, there's no point of measuring it while the app is in suspended state and the process is therefore stopped. In such case, the eligibility should be set to `notEligible` and the measuring module would be able to pause its work.

## iOS

On iOS, all processes are eligible to run when app is `foreground` or running in `extensionTask`. Some processes have specific task, `processingTask`.
Any of the above would be translated to `eligible` state.

## macOS

macOS has different application states, TBD. They can also be mapped to `eligible` vs `notEligible`.
