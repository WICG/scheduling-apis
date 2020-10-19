## Origin Trial Status of `scheduler.postTask`

We're running an [Origin
Trial](https://www.chromium.org/blink/origin-trials) in Chrome 86&ndash;87 to allow
testing this API in the wild (you can register [here](https://developers.chrome.com/origintrials/#/view_trial/2650368380707536897)).

This page tracks the current status of what parts of the APIs are implemented
as part of the trial. Please read the
[explainer](https://github.com/WICG/main-thread-scheduling/blob/master/PrioritizedPostTask.md)
to understand how to take advantage of these APIs.

In addition to participating via the origin trial, these APIs are available on
Chrome Canary and Dev by turning on experimental web platform APIs in Chrome.
You can do that by navigating to
`chrome://flags/#enable-experimental-web-platform-features`.

To disable `postTask` locally for testing (e.g. to compare performance with and
without the feature), pass the following on the command-line when running
Chrome:

```
--disable-blink-features=WebScheduler --origin-trial-disabled-features=WebScheduler
```

### Minimum Version for Local Testing

The minimum supported Chrome version for `postTask` is **81.0.4044.9**.

The minimum supported Chrome version for `onprioritychange` and `currentTaskSignal` is **82.0.4084.0**.

### Implementation Status

1. `scheduler.postTask` has been implemented, including parameters for
   `priority` and `delay`.

2. `TaskController` and `TaskSignal` have been implemented.

3. [Priority
   inheritance](https://github.com/WICG/main-thread-scheduling/blob/master/PostTaskPropagation.md)
   has been implemented and exposed through `scheduler.currentTaskSignal`.

4. An `onprioritychange` event has been added to `TaskSignal`.

### Examples

Sample code can be found [here](sample-code/), which covers the currently
implemented features. Please see the
[explainer](https://github.com/WICG/main-thread-scheduling/blob/master/PrioritizedPostTask.md)
for more context.

TODO(shaseley): add examples for `scheduler.currentTaskSignal` and `onprioritychange`.

### Filing Issues

For API issues or concerns, please [file a GitHub issue](https://github.com/WICG/main-thread-scheduling/issues/new?labels=postTask+API).
