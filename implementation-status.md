# Implementation and Experimentation Status in Chromium

This page tracks the implementation and experimentation status in Chromium of
different features of the various Scheduling APIs. For more information on the
various APIs and their statuses, please see the repo's
[README](README.md#apis-and-status).

## Features and Minimum Versions

### Experimental Features

 | Feature | Flag(s) | Minimum Version |
 | --- | --- | --- |
 | [`scheduler.yield()`](https://github.com/WICG/scheduling-apis/blob/main/explainers/yield-and-continuation.md) | `SchedulerYield` | 113.0.5672.24 |
 | [`TaskSignal.any()`](https://github.com/shaseley/abort-signal-any) | `AbortSignalAny` | 112.0.5599.0 |


### Shipped Features

 | Feature | Minimum Version |
 | --- | --- |
 | `scheduler.postTask()` (Window and Workers) | M94 |
 | `TaskController` and `TaskSignal` | M94 |
 | `prioritychange` events and `onprioritychange` | M94 |
 | TaskPriorityChangeEvent | M94 |

## Local Testing

There are two ways to enable the experimental scheduling features in Chrome:

**Method 1**: Enable **all** experimental web platform features by navigating to

```
chrome://flags/#enable-experimental-web-platform-features
```

**Method 2**: Enable just the desired scheduling features by passing the
appropriate [flags](#feature-flags) at the command line, for example:

```
--enable-blink-features=SchedulerYield
```

## Origin Trials

No [Origin Trials](https://www.chromium.org/blink/origin-trials) for scheduling
APIs are currently running, but an Origin Trial for `scheduler.yield()` is being
planned for sometime in 2023 Q2.

## Examples

Sample code can be found in the [explainers](./explainers/).

## Filing Issues

For API issues or concerns, please [file a GitHub
issue](https://github.com/WICG/scheduling-apis/issues/new).
