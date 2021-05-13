# Scheduling APIs

This document outlines the motivation for working on various scheduling
APIs<sup>1</sup>, discusses some of the problems that apps and userspace
schedulers face when writing scheduling code, and links to [various
proposals](#scheduling-apis-and-status) we are working on in this space.

(<sup>1</sup>The scope of this work was previously restricted to main-thread
scheduling, and while main-thread scheduling remains the primary focus, the
repository and some accompanying text has been renamed to "scheduling-apis" to
reflect the inclusion of APIs like
[`scheduler.postTask()`](explainers/prioritized-post-task.md) on workers.)

## Motivation: Main-thread Contention

Applications may experience main-thread contention at various points in their
execution, e.g. during page load or as a result of user interaction. This
contention can negatively affect user experience in terms of responsiveness and
latency. For example, a busy main thread can prevent the UA from servicing
input, leading to poor responsiveness. Similarly, tasks (e.g. fetch
completions, rendering, etc.) can experience large queuing durations during
times of contention, which increases task latency and can result in degraded
quality of experience.

Consider a "search-as-you-type" application. This app needs to be responsive to
user input, i.e. users typing in the search-box. At the same time, any
animations on the page must be rendered smoothly, and the work for fetching and
preparing search results and updating the page must also progress quickly.
There are a lot of different deadlines to meet for the app developer. It is
easy for any long running script work to hold up the main thread and cause
responsiveness issues for typing, rendering animations, or updating search
results.

Another example pinch-zooming in a map application. The app needs to
continuously respond to the input, update the rendering, and potentially fetch
new content to be displayed. Similar to the search-as-you-type example, long
running script work could block other tasks, making the application feel laggy.

## Current Solutions, Their Limitations, and APIs to Fill the Gaps

Dealing with contention is largely a scheduling problem: to the degree that
work can be reordered in an more optimal way, scheduling can have a positive
impact. What makes this problem more pronounced on the web is that tasks run to
completion&mdash;the UA cannot preempt a task to run high priority work
like processing user input. This problem is generally tackled in userspace by
systematically chunking and scheduling main-thread work. Since long tasks and
responsiveness are at odds, breaking up long tasks can help keep an app
responsive when also *yielding to the browser's event loop*.

[Userspace schedulers](./misc/userspace-schedulers.md) have evolved to manage
these chunks of work&mdash;prioritizing and executing work async at an
appropriate time relative to current situation of user and browser. And while
userspace schedulers have been effective in improving responsiveness, there are
several problems they still face:

 1. **Coordination between (cooperating) actors**: Most userspace schedulers
    have a notion of priority that allows tasks to be ordered in a way that
    improves user experience. But this is limited since userspace schedulers
    *do not control all tasks on the page*.

    Apps can consist of 1P, 1P library, 3P, and (one or more) framework script
    each of which competes for the main thread. At the same time, the browser
    also has tasks to run on the main thread, such as `fetch()` and IDB tasks
    and garbage collection.

    Having a shared notion of priority can help the browser make better
    scheduling decisions, which in turn can help improve user experience.
    We propose adding a [prioritized task scheduling
    API](./explainers/prioritized-post-task.md) to address this problem.

 1. **A disparate set of scheduling APIs**: Despite the need to schedule chunks
    of script, the Platform lacks a unified API to do so. Developers can choose
    `setTimeout`, `postMessage`, `requestAnimationFrame`, or
    `requestIdleCallback`, when choosing to schedule tasks.
  
    This disparate set of scheduling APIs makes it even more difficult for
    developers to write scheduling code and requires expert knowledge of the
    browser's event loop to do so. Creating a unified native scheduling API
    &mdash;[`scheduler.postTask()`](./explainers/prioritized-post-task.md)
    &mdash;will alleviate this.

 1. **Determining when to yield to the browser**: yielding has overhead&mdash;the
    overhead of posting a task and context switching, the cost of regaining
    control, etc. This can lead to increased task latency.

    Making intelligent decisions about when to yield is difficult with limited
    knowledge. Scheduling primitives can help userspace schedulers make better
    decisions, e.g. [`isInputPending()`](https://github.com/WICG/is-input-pending)
    and [`isFramePending()`](https://github.com/szager-chromium/isFramePending/blob/master/explainer.md).

 1. **Regaining control after yielding**: chunking work and yielding is
    necessary for improving responsiveness, but it comes at a cost: when
    yielding to the event loop, a task that yields has no way to *continue*
    without arbitrary work of the *same priority* running first, e.g. other
    script. This disincentivizes yielding from a script that requires low task
    latency. Providing a primitive like [`scheduler.yield()`](./explainers/yield-and-continuation.md)
    that is designed to take into account this async userspace task model can
    help, as the scheduler can prioritize these continuations more fairly.

## Additional Scheduling Problems

The problem as described above only covers part of the scheduling problem
space. Additionally, there are developer needs for things like detecting when
a frame is pending, throttling the frame rate, and avoiding layout thrashing.
Some of the other APIs we are considering in this space are noted [here](./misc/low-level-apis.md).

## APIs and Status

 | API | Abstract | Status | Links |
 | --- | --- | --- | --- |
 | `scheduler.postTask()` | An API for scheduling and controlling prioritizing tasks. | An origin trial recently concluded in Chrome M89, and we are currently working towards shipping the API. The feature is available [behind a flag](./origin-trial-status.md) in Chromium. | [Explainer](./explainers/prioritized-post-task.md) <br/> [Spec](https://wicg.github.io/scheduling-apis/) <br/> [Polyfill](https://github.com/WICG/scheduling-apis/issues/37) |
 | `scheduler.yield()` | An API for breaking up long tasks by yielding to the browser, continuing after being rescheduled by the scheduler. | This feature is actively being designed, and the explainer will be updated soon with our current thinking. | [Explainer](./explainers/yield-and-continuation.md) |
 | `scheduler.wait()` | This enables tasks to yield and resume after some amount of time, or perhaps after an event has occurred. | This feature is currently being co-designed with `scheduler.yield()`. | [Related Discussion](https://github.com/WICG/scheduling-apis/issues/19) |
 | `scheduler.currentTaskSignal` | This API provides a way to get the currently running task's `TaskSignal`, which can be used to schedule dependent tasks. | This API is available behind a flag in Chromium, but we are currently re-evaluating the API based on the broader notion of a *userspace task* in the context of `scheduler.yield()`. | [Explainer](./explainers/post-task-propagation.md) |
 | Prioritized Fetch Scheduling | Using a `TaskSignal` or `postTask` priorities for resource fetching would enable developers to prioritize critical resources, or deprioritize less critical ones. | This feature is actively being designed. | [Early Proposal](https://docs.google.com/document/d/1107Vk7csYTf_lIapd2mipVQiO73JfX1uIkOA5Rbu3k8/view) |
 | `isInputPending()` | An API for determining if the current task is blocking input events. | This API shipped in Chrome M87. | [Explainer](https://github.com/WICG/is-input-pending) <br/> [Spec](https://wicg.github.io/is-input-pending/) <br/> [web.dev](https://web.dev/isinputpending/) |

## Further Reading / Viewing

 * TPAC / WebPerfWG Presentation - October 2020 [[slides](https://docs.google.com/presentation/d/1KqfH0j-OMY6kOsAyh4impB9q4OwSfX--waenzF8iFX4/edit?usp=sharing), [video](https://www.youtube.com/watch?v=LLNewXxHJfs)]: updates on various APIs are presented
 * WebPerfWG F2F Presentation - June 2019 [[slides](https://docs.google.com/presentation/d/1GUB081FTpvFEwEkfePagFEkiqcLKKnIHkhym-I8tTd8/edit#slide=id.g5b43bd1ecf_0_508), [video](https://www.youtube.com/watch?v=eyAW4FuSgyE&t=14387)]: `scheduler.yield()` and `scheduler.postTask()` are presented and discussed
 * Detailed [Scheduling API Proposal](https://docs.google.com/document/d/1xU7HyNsEsbXhTgt0ZnXDbeSXm5-m5FzkLJAT6LTizEI/edit#heading=h.iw2lczs6xwe6) for `scheduler.yield()` and `scheduler.postTask()`
 * Scheduling API [MVP Proposal](https://docs.google.com/document/d/1AATlW1ohLUgjSdqukgDx3C0P6rnJFgZavmKoZxGb8Rw/edit?usp=sharing)
 * [Priority-Based Web Scheduling](https://docs.google.com/document/d/1AATlW1ohLUgjSdqukgDx3C0P6rnJFgZavmKoZxGb8Rw/edit?usp=sharing) dives into various scheduling priority systems
 * [Scheduling Overview - TPAC 2018](https://docs.google.com/presentation/d/12lkTrTwGedKSFqOFhQTsEdcLI3ydRiAdom_9uQ2FgsM/edit?usp=sharing)
 * [Talk from Chrome Dev Summit - 2018](https://youtu.be/mDdgfyRB5kg) covers the problem and larger direction
