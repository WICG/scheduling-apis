# Main-thread Scheduling API

This document outlines the motivation for working on main thread scheduling
APIs, discusses some of the problems that apps and userspace schedulers face
when writing scheduling code, and links to various proposals we are working on
in this space.

**Note**: individual proposals will be linked in the sections below and have
separate explainers.

## Motivation: Main thread contention
Consider a "search-as-you-type" application:

This app needs to be responsive to user input, i.e. user typing in the
search-box. At the same time any animations on the page must be rendered
smoothly, and the work for fetching and preparing search results and updating
the page must also progress quickly. 

There are a lot of different deadlines to meet for the app developer. It is easy
for any long running script work to hold up the main thread and cause
responsiveness issues for typing, rendering animations, or updating search
results.

(**TODO**: Add a use cases doc with more concrete examples.)

## Current solutions, their limitations, and APIs to fill the gaps

This problem is generally tackled by systematically chunking and scheduling
main thread work. Since long tasks and responsiveness are at odds, breaking up
long tasks can help keep an app responisive when also *yielding to the browser's
event loop*.

[Userspace schedulers](UserspaceSchedulers.md) have evolved to manage these
chunks of work&mdash;prioritizing and executing work async at an appropriate
time relative to current situation of user and browser.

While userspace schedulers have been effective in improving responsiveness,
there are several problems they still face:

 1. **Determining when to yield to the browser**: yielding has overhead&mdash;the
    overhead of posting a task and context switching, the cost of regaining
    control, etc. This leads to increased task latency (the task at hand takes
    longer).

    Making intelligent decisions of when to yield is difficult with limited
    knowledge. Scheduling primitives can help userspace schedulers make better
    decisions, e.g. [isInputPending()](https://github.com/WICG/is-input-pending)
    and isFramePending().

 2. **Regaining control after yielding**: chunking work and yielding is
    necessary for improving responsiveness, but it comes at a cost: when
    yielding to the event loop, a task that yields has no way to *continue*
    without arbitrary work of the *same priority* running first, e.g. other
    script. This disincentivizes yielding for script that requires low task
    latency.

    We propose adding [scheduler.yield()](YieldAndContinuation.md) as a
    solution.

 3. **Coordination between (cooperating) actors**: Most userspace schedulers
    have a notion of priority that allows tasks to be ordered in a way that
    improves user experience. But this is limited since userspace schedulers
    *do not control all tasks on the page*.

    Apps can consist of 1P, 1P library, 3P, and (one or more) framework script
    each of which competes for the main thread. At the same time, the browser
    also has tasks to run on the main thread, such as `fetch()` and IDB tasks
    and garbage collection.

    Having a shared notion of priority can help the browser make better
    scheduling decisions to help improve user experience.

    We propose adding a [prioritized postTask scheduling
    API](PrioritizedPostTask.md) to address this problem.

 4. **A disparate set of scheduling APIs**: Despite the need to schedule chunks
    of script, the Platform lacks a unified API to do so. Developers can choose
    `setTimeout`, `postMessage`, `requestAnimationFrame`, or
    `requestIdleCallback`, when choosing to schedule tasks.
  
    This disparate set of scheduling APIs makes it onerous for developers to
    write scheduling code, and requires expert knowledge of the Browser's event
    loop to do so. Creating a unified native scheduling API can alleviate this.

    This is also addressed by the [postTask API](PrioritizedPostTask.md).

## Additional Scheduling Problems

The problem as described above only covers part of the scheduling problem
space.  Additionally, there are developer needs for things like detecting when
a frame is pending, throttling the frame rate, and avoiding layout thrashing.

Some of the other APIs we're considering in this space are noted
[here](LowLevelAPIs.md).

## Explainer Links

 * [scheduler.yield()](YieldAndContinuation.md)
 * [scheduler.postTask()](PrioritizedPostTask.md)
 * [isInputPending()](https://github.com/WICG/is-input-pending)

## Further Reading / Viewing

 * WebPerfWG F2F Presentation - June 2019 [[slides](https://docs.google.com/presentation/d/1GUB081FTpvFEwEkfePagFEkiqcLKKnIHkhym-I8tTd8/edit#slide=id.g5b43bd1ecf_0_508), [video](https://www.youtube.com/watch?v=eyAW4FuSgyE&t=14387)]: `scheduler.yield()` and `scheduler.postTask()` are presented and discussed
 * Detailed [Scheduling API Proposal](https://docs.google.com/document/d/1xU7HyNsEsbXhTgt0ZnXDbeSXm5-m5FzkLJAT6LTizEI/edit#heading=h.iw2lczs6xwe6) for `scheduler.yield()` and `scheduler.postTask()`
 * Scheduling API [MVP Proposal](https://docs.google.com/document/d/1AATlW1ohLUgjSdqukgDx3C0P6rnJFgZavmKoZxGb8Rw/edit?usp=sharing)
 * [Priority-Based Web Scheduling](https://docs.google.com/document/d/1AATlW1ohLUgjSdqukgDx3C0P6rnJFgZavmKoZxGb8Rw/edit?usp=sharing) dives into various scheduling priority systems
 * [Scheduling Overview - TPAC 2018](https://docs.google.com/presentation/d/12lkTrTwGedKSFqOFhQTsEdcLI3ydRiAdom_9uQ2FgsM/edit?usp=sharing)
 * [Talk from Chrome Dev Summit - 2018](https://youtu.be/mDdgfyRB5kg) covers the problem and larger direction
