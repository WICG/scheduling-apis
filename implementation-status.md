# Implementation and Experimentation Status in Chromium

This page tracks the implementation and experimentation status in Chromium of
different features of the various Scheduling APIs. For more information on the
various APIs and their statuses, please see the repo's
[README](README.md#apis-and-status).

## Features and Minimum Versions

 | Feature | Minimum Version |
 | --- | --- |
 | `scheduler.postTask()` with the current Promise-based API shape | 81.0.4044.9 |
 | `prioritychange` events and `onprioritychange` |  82.0.4084.0 |
 | `scheduler.currentTaskSignal` | 82.0.4084.0 |
 | TaskPriorityChangeEvent with `previousPriority` property | 91.0.4469.4 |
 | `postTask` and `currentTaskSignal` on Workers | 93.0.4549.3 |

### Feature Flags

 | Feature | Flag(s) |
 | --- | --- |
 | `scheduler.postTask()`, `TaskController`, `TaskSignal` | `WebScheduler` |
 | `scheduler.currentTaskSignal` | `WebScheduler`,`SchedulerCurrentTaskSignal` |

## Local Testing

There are two ways to enable the experimental scheduling features in Chrome:

**Method 1**: Enable **all** experimental web platform features by navigating to

```
chrome://flags/#enable-experimental-web-platform-features
```

**Method 2**: Enable just the desired scheduling features by passing the
appropriate [flags](#feature-flags) at the command line, for example:

```
--enable-blink-features=WebScheduler
```

## Origin Trials

No [Origin Trials](https://www.chromium.org/blink/origin-trials) for scheduling
APIs are currently running. We previously ran origin trials for
`scheduler.postTask()` in Chrome 82&ndash;84 and Chrome 88&ndash;89.

## Examples

Sample code can be found [here](sample-code/) and in the
[explainer](./explainers/prioritized-post-task.md).

## Filing Issues

For API issues or concerns, please [file a GitHub
issue](https://github.com/WICG/scheduling-apis/issues/new).
