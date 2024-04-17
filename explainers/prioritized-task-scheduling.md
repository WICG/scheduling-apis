# Prioritized Task Scheduling

## Authors

- [Scott Haseley](https://github.com/shaseley)

## Participate

- [Issue tracker](https://github.com/WICG/scheduling-apis/issues)

## Table of Contents

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

- [Preface](#preface)
- [Definitions and Concepts](#definitions-and-concepts)
  - [Notes](#notes)
- [Introduction](#introduction)
- [Goals](#goals)
- [Non-goals](#non-goals)
- [User research](#user-research)
- [Proposal](#proposal)
  - [Task Priorities](#task-priorities)
  - [`TaskSignal` and `TaskController`](#tasksignal-and-taskcontroller)
    - [`TaskSignal.any()` Specialization](#tasksignalany-specialization)
  - [`scheduler.postTask()`](#schedulerposttask)
  - [`scheduler.yield()`](#scheduleryield)
    - [How Continuations are Prioritized](#how-continuations-are-prioritized)
  - [`scheduler.render()`](#schedulerrender)
    - [High Priority Rendering Updates](#high-priority-rendering-updates)
  - [`scheduler.wait()`](#schedulerwait)
    - [Prioritizing Continuations](#prioritizing-continuations)
    - [Relationship to `setTimeout()` and `scheduler.postTask()`](#relationship-to-settimeout-and-schedulerposttask)
    - [Future Enhancements](#future-enhancements)
  - [`scheduler.currentTaskSignal`](#schedulercurrenttasksignal)
  - [Integration with Other APIs](#integration-with-other-apis)
    - [`fetch`](#fetch)
    - [`<script async>`](#script-async)
    - [`MessageChannel`](#messagechannel)
    - [Storage APIs](#storage-apis)
  - [Key scenarios](#key-scenarios)
- [Considered alternatives](#considered-alternatives)
  - [`TaskSignal`](#tasksignal)
  - [`scheduler.postTask()`](#schedulerposttask-1)
  - [`scheduler.yield()`](#scheduleryield-1)
  - [`scheduler.render()`](#schedulerrender-1)
  - [`MessageChannel` Prioritization](#messagechannel-prioritization)
- [Stakeholder Feedback / Opposition](#stakeholder-feedback--opposition)
- [References & Acknowledgments](#references--acknowledgments)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

## Preface

This explainer brings together various past, present, and planned scheduling APIs proposals into a
single explainer. Some of the APIs presented have separate longer explainers, which are linked in
the relevant sections, and some ideas have not been fully designed.

## Definitions and Concepts

**Tasks** and **continuations** are fundamental concepts in scheduling, and at least the former is a
very overloaded term. Brief descriptions of these concepts follow, but they are also discussed in
depth in [Task Models](../misc/userspace-task-models.md).

In this document a **task** typically means a synchronous chunk of JavaScript executed
asynchronously, i.e. scheduled or executed in response to some async event. Scheduled tasks include
things like `setTimeout()` and `requestIdleCallback()` callbacks, and async events include things
like click event handlers<sup>1</sup>.

**Yielding** within a task is to pause and resume execution in another task. We call the resuming
task a **continuation**. A **yieldy task** is a task that is broken up into an initial task and one
or more _continuations_. Continuations can be scheduled using the same APIs as tasks (e.g.
`setTimeout()`), and from the browser's point of view both the task and continuations are [HTML
tasks](https://html.spec.whatwg.org/multipage/webappapis.html#concept-task); but from the
developer's point of view, they are related and part of the same _logical task_.

Scheduling can be used to improve site performance, specifically **responsiveness** and
**user-perceived latency** (or end-to-end latency). These measure latency on different timescales.
Responsiveness refers to how fast a page is able to respond to user input, which [Interaction to
Next Paint (INP)](https://web.dev/articles/inp) attempts to measure using the primitives in [Event
Timing](https://w3c.github.io/event-timing/).  User-perceived latency is an application- and
event-specific measure of latency, e.g. how long a SPA navigation takes or how it takes to fetch and
display results when clicking a "search" button.

### Notes

<sup>1</sup>In this context we typically only think of top-level JS execution as a _task_, as
opposed to events dispatched during a task.

## Introduction

Scheduling is an important tool for improving website performance and user experience, particularly
on interactive pages with a lot of JavaScript. Two important aspects of this are:

 1. **Yielding, or breaking up long tasks.** Long tasks limit scheduling opportunities because [JS tasks
    are not preemptable](https://developer.mozilla.org/en-US/docs/Web/JavaScript/EventLoop#run-to-completion).
    Long tasks can block handling input or updating the UI in response to input, which is often a
    cause of poor responsiveness.

 2. **Prioritization, or running the most important work first.** The (task/event loop) scheduler
    determines which task runs next on the event loop. Running higher priority work sooner can
    improve user experience by minimizing user-perceived latency of the associated user interaction.

Modern pages and frameworks often do some form of this, ranging from breaking up long tasks with
`setTimeout()` to building complex [userland schedulers](../misc/userspace-schedulers.md) that
manage prioritization and execution of all internal tasks. While these approaches can be effective,
there are gaps and rough edges with existing scheduling APIs that make this difficult. For example:

 - `requestIdleCallback()` is the only way to schedule prioritized tasks. It's helpful for
   deprioritizing certain types of work, but can't be used to increase priority of important tasks
   or be used to prioritize I/O. To gain higher priority, developers might use
   `requestAnimationFrame()` as a hack to get higher priority (with UA-specific results), but that
   can negatively affect rendering performance by delaying visual updates since rAF callbacks run
   before a new frame is produced. In general, UA schedulers are unaware of high priority userland
   tasks, which limits their ability to effectively prioritize work.

 - Continuations scheduled with existing APIs are indistinguishable from other tasks, and the
   pending continuation is appended to the end of the relevant task queue. Task continuations aren't
   prioritized, which can lead to a performance penalty (latency) for yieldy tasks to regain the
   thread after yielding.

 - `setTimeout()` clamps at 4ms if sufficiently nested, which impacts performance when using it to
   frequently yield. Developers often need to hack around this, e.g. by [using
   `postMessage`](https://dbaron.org/log/20100309-faster-timeouts) instead; but `postMessage` was
   designed for cross-window communication, not scheduling.

 - There's no way to specify a priority on I/O-related APIs like `fetch()` and IndexedDB, which
   limits the effectiveness of userland scheduling.


## Goals

The main goal of this work is to facilitate improving site performance (responsiveness and latency)
through better scheduling primitives, and specifically:

 - provide an ergonomic and performant way to break up long tasks, reducing the end-to-end task
   latency of yieldy tasks compared to current methods;

 - provide a way to schedule high priority tasks and continuations;

 - enable prioritizing select async I/O main thread tasks, e.g. `fetch()` and async `<script>`;

 - enable the browser to make better internal scheduling decisions by being aware of userland task
   priorities;

 - provide a cohesive set of scheduling APIs using modern web primitives, e.g. `AbortController`,
   promises, etc.


## Non-goals

 - It's a non-goal to to replace every userland scheduler. Rather, our goal is to provide primitives
   that these schedulers, and pages in general, can use to improve scheduling/performance.

 - It's a non-goal to change JavaScript's [run-to-completion](https://developer.mozilla.org/en-US/docs/Web/JavaScript/EventLoop#run-to-completion)
   semantics. Making JavaScript tasks preemptable would significantly improve responsiveness, but
   such a paradigm shift is outside the scope of this proposal.


## User research

No user research was performed specifically for this proposal, but there have been studies on input
latency in computing, some of which is discussed in [this event-timing
issue](https://github.com/w3c/event-timing/issues/118).


## Proposal

### Task Priorities

(See also the original [`scheduler` explainer](./prioritized-post-task.md#priorities) and
[specification](https://wicg.github.io/scheduling-apis/#sec-task-priorities).)

The proposal centers around a small set of semantic task priorities, which are used to schedule
tasks and continuations, and which are integrated into new and existing APIs. Semantically
meaningful naming helps developers understand when it is appropriate to use a given priority and
enable easier coordination, and there is precedent in other systems. Similar priorities (and a
similarly small set) can be found in other platforms like Apple's
[QoSClass](https://developer.apple.com/documentation/dispatch/dispatchqos/qosclass) and Chromium's
internal [browser task
queues](https://source.chromium.org/chromium/chromium/src/+/261ad5cb51f1dbf3385af53218512796602100ed:content/browser/scheduler/browser_task_queues.h).

1. **user-blocking**: tasks that block a user from interacting with and using the app. This could be
   (chunked) work that is directly in response to user input, or updating in-viewport UI state.

   User-blocking tasks are meant to have a higher priority in the event loop compared to other JS
   tasks, i.e. they are prioritized by UA schedulers.

2. **user-visible**: tasks that will be visible to the user, but either not immediately or do not
   block the user from interacting with the page. These tasks are either less important or less
   urgent than user-blocking tasks.

   This is the default priority used for `postTask()` and the `TaskController`
   constructor, and it is meant to be scheduled by UAs similarly to other scheduling methods, e.g.
   same-window `postMessage` and `setTimeout(,0)`.

3. **background**: Background tasks are low priority tasks that are not time-sensitive and not
   visible to the user.

   Background tasks are meant to have a lower priority in the event loop compared to other JS tasks.
   These tasks are comparable to _idle tasks_ scheduled by `requestIdleCallback()`, but without the
   requirements that come with an idle period (deadlines, idle period length, etc.).

### `TaskSignal` and `TaskController`

(See also the original [`scheduler` explainer](./prioritized-post-task.md#controlling-posted-tasks)
and [specification](https://wicg.github.io/scheduling-apis/#sec-controlling-tasks).)

`scheduler` tasks and continuations have an associated [priority](#task-priorities), and they can be
aborted with an `AbortSignal`. `TaskSignal` &mdash; which inherits from `AbortSignal` &mdash;
encapsulates this state. `TaskController` is used to signal a change in this state.

A `TaskController` is an `AbortController` (inheritance) with the additional capability of changing
its signal's (`TaskSignal`) priority. This can be used to dynamically reprioritize pending tasks
associated with the signal.

These primitives are used to control `scheduler` tasks through the `signal` option in the APIs that
follow.

**Example: Creating a `TaskController.`**
```js
const controller = new TaskController({priority: 'background'});
// `signal` can be passed to `scheduler` APIs and other AbortSignal-accepting APIs.
const signal = controller.signal;
console.log(signal.priority);                // 'background'
console.log(signal instanceof AbortSignal);  // true
console.log(signal.aborted);                 // false
```

**Example: Signaling 'prioritychange' and 'abort'.**
```js
const controller = new TaskController({priority: 'background'});
const signal = controller.signal;
// TaskSignal fires 'prioritychange' events when the priority changes.
signal.addEventListener('prioritychange', handler);
controller.setPriority('user-visible');
console.log(signal.priority);                // 'user-visible'

// TaskController can abort the associated TaskSignal.
controller.abort();
console.log(signal.aborted);                 // true
```


#### `TaskSignal.any()` Specialization

(See also the [`TaskSignal.any()` explainer](https://github.com/shaseley/abort-signal-any#tasksignal-apis)
and [specification](https://wicg.github.io/scheduling-apis/#dom-tasksignal-any).)

[`AbortSignal.any()`](https://dom.spec.whatwg.org/#dom-abortsignal-any) creates an `AbortSignal`
that is aborted when any of the signals passed to it are aborted. We call this a _dependent signal_
since it is dependent on other signals for its abort state.

[`TaskSignal.any()`](https://wicg.github.io/scheduling-apis/#dom-tasksignal-any) is a specialization
of this (inherited) method. It returns a `TaskSignal` which is similarly aborted when any of the
signals passed to it are aborted, but additionally it has priority, which by default is
"user-visible" but can be customized &mdash; either to a fixed priority or a dynamic priority based
on another `TaskSignal`.

Summarizing, compared to `AbortSignal.any()`, `TaskSignal.any()`:
 - Returns a `TaskSignal` instead of an `AbortSignal`
 - Has the same behavior for abort, i.e. it is dependent on the input signals for its abort state
 - Also initializes the priority component of the signal, to either a fixed priority or a dynamic
   priority based on an input `TaskSignal` (meaning it changes as the input signal changes)

**Example: `TaskSignal.any()` with default priority.**
```js
// The following behaves identical to AbortSignal.any([signal1, signal2]), but
// the signal returned is a TaskSignal with default priority.
const signal = TaskSignal.any([signal1, signal2]);
console.log(signal instanceof TaskSignal);  // true
console.log(signal.priority);               // 'user-visible' (default)
```

**Example: `TaskSignal.any()` with a fixed priority.**
```js
// The resulting signal can also be created with a fixed priority:
const signal = TaskSignal.any([signal1, signal2], {priority: 'background'});
console.log(signal.priority);               // 'background'
```

**Example: `TaskSignal.any()` with a dynamic priority.**
```js
// Here, `signal` is dependent on `controller.signal` for priority.
const controller = new TaskController();
const sourceSignal = controller.signal;

const signal = TaskSignal.any([signal1, sourceSignal], {priority: sourceSignal});
console.log(signal.priority);               // 'user-visible'
controller.setPriority('background');
console.log(signal.priority);               // 'background'
```

`TaskSignal.any()` provides developers with a lot of flexibility about how tasks are scheduled and
which other signals should affect a task or group of tasks.

### `scheduler.postTask()`

(See also the original [`scheduler` explainer](./prioritized-post-task.md) and
[specification](https://wicg.github.io/scheduling-apis/#dom-scheduler-posttask)).

`scheduler.postTask(task, options)` enables scheduling prioritized tasks such that the priority
influences event loop scheduling (see [Task Priorities](#task-priorities)). This is primarily used
to break up long tasks on function boundaries.

**Example: Breaking up a long task with `scheduler.postTask()`.**
```js
function longTask() {
  const task1 = scheduler.postTask(doWork);
  const task2 = scheduler.postTask(doMoreWork);

  return Promise.all([task1, task2]);
}
```

<hr/>

The API returns a promise which is resolved with the return value of the callback.

**Example: `scheduler.postTask()` return value.**

```js
function task() { return 'example'; }

const result = await scheduler.postTask(task);
console.log(result);  // 'example'
```

Breaking up long tasks helps improve responsiveness since long tasks can block input handling.
Prioritization can help reduce latency of important work by either deprioritizing background work
or prioritizing the important work. The default option (`'user-visible'`) has similar scheduling
characteristics as existing APIs, e.g. `setTimeout()`.

<hr/>

For simplicity, the API takes a `priority` option which can be used when no control (`TaskSignal`)
is necessary.

**Example: Scheduling prioritized tasks with the priority option.**
```js
function longTask() {
  const priority = 'background';

  const task1 = scheduler.postTask(doBackgroundWork, {priority});
  const task2 = scheduler.postTask(doMoreBackgroundWork, {priority});

  return Promise.all([task1, task2]);
}

function inputHandler() {
  requestAnimationFrame(() => {
    updateUI();
    // Don't block the frame. See also scheduler.render().
    scheduler.postTask(processInput, {priority: 'user-blocking'});
  });
}
```

<hr/>

Tasks can also be [controlled](#tasksignal-and-taskcontroller) with a `TaskController` by passing
its `TaskSignal` to `scheduler.postTask()`.

**Example: Controlling tasks with a `TaskSignal`.**
```js
function task() {
  // ... do a bunch of work...
}

const controller = new TaskController();
const signal = controller.signal;

scheduler.postTask(task, {signal});

// ... later ...

// Change the priority, e.g. if the viewport content changed.
controller.setPriority('background');

// Abort all pending tasks associated with the signal.
// Note: this causes pending promises to be rejected.
controller.abort();
```

<hr/>

If signal and priority are both provided, the task will have a fixed priority and use the signal for
abort. Note that this is equivalent to passing `TaskSignal.any([signal], priority)`.

**Example: Scheduling a task with signal and priority.**

```js
function task(signal) {
  // Use the input signal for aborting, but with fixed 'background' priority.
  scheduler.postTask(otherTask, {signal, priority: 'background'});

  // The above is equivalent to and shorthand for:
  const newSignal = TaskSignal.any([signal], {priority: 'background'});
  scheduler.postTask(otherTask, {signal: newSignal});
}
```

### `scheduler.yield()`

(See also the [separate `scheduler.yield()` explainer](./yield-and-continuation.md)).

`scheduler.yield()` can be used in any context to yield to the event loop by awaiting the promise it
returns. The [task continuation](#definitions-and-concepts) &mdash; the code that runs as a
microtask when the returned promise is resolved &mdash; runs in a new browser task and gives the
browser a scheduling opportunity. Continuations are [given a higher
priority](#how-continuations-are-prioritized) by the UA, which helps minimize the latency penalty
for yielding.

Whereas `scheduler.postTask()` can be used to break up long tasks on function boundaries by
scheduling chunks of work, `scheduler.yield()` can be used to break up long tasks by inserting
yield points in functions.

**Example: Inserting yield points.**
```js
async function task() {
  doWork();
  // Yield to the event loop and resume in a new browser task.
  await scheduler.yield();
  doMoreWork();

  await scheduler.yield();
  // ... and so on ...
}

// Schedule the long but yieldy task to run. scheduler.yield() can be used to
// break up long timers, long I/O callbacks, etc.
setTimeout(task, 100);
```

<hr/>

Similar to `scheduler.postTask()`, developers can provide `{signal, priority}` options to control
continuation scheduling and cancellation.

**Example: Controlling continuations with priority and signal.**

```js
const controller = new TaskController({priority: 'background'});

async function task() {
  doWork();

  // Deprioritize the continuation, and reject the promise if
  // the signal is aborted.
  await scheduler.yield({signal: controller.signal}});

  doMoreWork();

  // Deprioritize the continuation, but don't ever abort it.
  await scheduler.yield({priority: 'background'}});

  ...
}
```

<hr/>

If the yielding task was originally scheduled with `scheduler.postTask()` and no options are passed
to `scheduler.yield()`, then the current priority/signal will be **inherited**. This works across
throughout the entire async task. Similarly, yielding within a `requestIdleCallback` callback will
inherit `'background'` priority by default.

Inheritance can also be customized, for example to limit inheriting only the priority or abort
component of the current task's `TaskSignal`.

If there isn't priority or signal to inherit, the default values are used (a non-abortable,
`'user-visible'` continuation).

**Example: Inheriting the task priority.**

```js
async function task() {
  doWork();

  // Inherit the current signal (priority and abort), which happens by default.
  await scheduler.yield();

  doMoreWork();

  // Inherit only the current task's priority.
  await scheduler.yield({priority: "inherit"}});

  doMoreWork();

  // Inherit the abort component and use a fixed priority.
  await scheduler.yield({signal: "inherit", priority: "background"});
}

scheduler.postTask(task, {signal: theSignal});
```

**Example: Inheriting priority in idle tasks.**

```js
requestIdleCallback(async (deadline) => {
  while (notFinished()) {
    workUntil(deadline);
    // Continuations will run at `'background'` continuation priority.
    await scheduler.yield();
  }
});
```

#### How Continuations are Prioritized

Using `scheduler.yield()` can be more ergonomic than alternatives, but it also solves a common
performance concern with yielding by **prioritizing continuations**. Developers are often hesitant
to yield because giving up the thread means other arbitrary code can run before the continuation is
scheduled. `scheduler.yield()` solves this by giving continuations a higher priority within the
event loop. This means the UA might choose to process input or rendering before running a
continuation, but not other pending timers, for example.

Task and continuation priorities are ranked as follows:

```
'user-blocking' continuation > 'user-blocking' task >
'user-visible' continuation > 'user-visible' task >
'background' continuation > 'background' task
```

### `scheduler.render()`

`scheduler.render()` is similar to `scheduler.yield()`, but the promise it returns is not resolved
until after the next rendering update _if rendering is likely to happen_. If the DOM is dirty or a
`requestAnimationFrame` callback is pending _and_ the page is visible, this means the promise it
returns won't be resolved until after the rendering steps next run (or the page is hidden). If
rendering is not expected, then the behavior matches `scheduler.yield()`. In either case, the
promise is always resolved in a new task.

The main use case is to ensure pending DOM updates are shown to the user before continuing:

```js
async function handleInput() {
  showInitialResponse();
  // Make sure the initial input response was rendered.
  await scheduler.render();

  continueHandlingInput();
}
```

This API takes the same options as `scheduler.yield()`, which can be used to abort the continuation
and control its priority. Furthermore, prioritization (continuation scheduling) works the same as
`scheduler.yield()`.

#### High Priority Rendering Updates

`scheduler.render()` informs the UA that a task is blocked on rendering, which is a signal that
rendering is important. While UAs typically have scheduling policies that prevent starvation of
rendering updates, an explicit signal can help optimize pages. For example, some sites may know
during loading exactly where the above-the-fold content ends, which is an ideal time to produce a
visual update. Providing an explicit signal to the UA at this point could help optimize page load,
if the UA's parser yields and runs a rendering update.

### `scheduler.wait()`

`scheduler.wait()` is another "yieldy" API, similar to `scheduler.yield()` and `scheduler.render()`,
but used when execution should not resume immediately. The promise returned by `scheduler.wait()` is
resolved after the provided timeout. This API can be used to pause execution of the current task for
some amount of time, e.g. to wait for a "ready signal" (polling) or to time-shift work.

```js
window.addEventListener('load', async () => {
  // Wait a second after load for things to settle.
  await scheduler.wait(1000);

  // ...
});

async function task() {
  while (!ready()) {
    scheduler.wait(100);
  }
  // Carry on...
}
```

This API has the same optional parameters as `scheduler.yield()` for controlling abort and priority:

```js
const controller = new TaskController({priority: 'background'});

async function task() {
  // The continuation will have background priority, and it will be aborted if
  // controller.signal is aborted.
  await scheduler.wait(5000, {signal: "inherit"});

  // Carry on...
}

scheduler.postTask(task, {signal: controller.signal});
```

#### Prioritizing Continuations

The current thinking is that `scheduler.wait()` continuations will be prioritized like
`scheduler.postTask()` tasks and not like `scheduler.yield()` continuations since there are
different latency expectations (`wait()` adds latency by design). For continuations that need higher
priority, `'user-blocking'` priority can be used. This also enables using `await scheduler.wait(0)`
as a way to opt into yielding in a "friendlier" way, i.e. it doesn't try to regain control
immediately.

#### Relationship to `setTimeout()` and `scheduler.postTask()`

`scheduler.wait()` is essentially a prioritized, promise-based `setTimeout()` that doesn't take a
callback function. Developers often wrap `setTimeout()` in a promise for this purpose.

Using `scheduler.postTask({}, {delay, ...})` avoids the promise wrapping, but the proposed API is
simpler for the use case, more ergonomic for async code, and supports inheritance as well.

#### Future Enhancements

An extension of this API would be to enable waiting for things other than time, e.g. events. We plan
to explore integrating this with [observables](https://github.com/WICG/observable), depending on how
that work proceeds.

### `scheduler.currentTaskSignal`

`scheduler.currentTaskSignal` returns the current task's signal, which is the `TaskSignal` used by
the "yieldy APIs" (`scheduler.yield()` et al.) for signal inheritance. Exposing this signal enables
using it to schedule related work or combining it with other signals without needing to pass the
signal through every function along the way.

**Example: reading the current task's priority.**

```js
function task() {
  console.log(scheduler.currentTaskSignal.priority);  // 'background'
}

scheduler.postTask(task, {priority: 'background'});
```

**Example: combining signals with the current task's signal.**


```js
async function task() {
  // Subtasks should be aborted if this task's signal is aborted, but can
  // separately be aborted by this controller.
  const controller = new AbortController();
  const signal = TaskSignal.any(
   [controller.signal, scheduler.currentTaskSignal],
   {priority: scheduler.currentTaskSignal});

  scheduler.postTask(subtask1, {signal});
  scheduler.postTask(subtask2, {signal});

  // ...
}

scheduler.postTask(task, {signal: someSignal});
```

### Integration with Other APIs

UAs can prioritize on a per-[task
source](https://html.spec.whatwg.org/multipage/webappapis.html#task-source) basis; but such
decisions are difficult without explicit (userland) priority information. Integrating `scheduler`
[priorities](#task-priorities) with other asynchronous APIs would give developers further control
over task ordering on their pages by creating a more complete prioritized task scheduling system.

#### `fetch`

`fetch()` has a `signal` option (an `AbortSignal`) which is used to abort an ongoing fetch, similar
to the `signal` option in `scheduler` APIs. We propose extending this such that if the signal
provided is a `TaskSignal`, the priority is used for event loop task scheduling.

**Example: A 'user-blocking' fetch.**
```js
async function task() {
  // Both of the promises below are resolved in 'user-blocking' tasks.
  const prioritySignal = TaskSignal.any([], {priority: 'user-blocking'});
  let response = await fetch(url, {signal: prioritySignal});
  let data = await response.json();
}
```

This can be used to increase the priority such that fetch-related tasks won't be blocked by
`'user-visible'` (default) continuations or tasks, or can be used to deprioritize fetches related to
background work.

Note that:
 1. This is separate from the [`priority`](https://fetch.spec.whatwg.org/#request-priority) option,
    which only controls network priority.
 2. This proposal could be extended, for convenience, to include a `taskpriority` fetch option,
    similar to `<script async>` below.

#### `<script async>`

Async scripts are executed independently when ready, but the UA doesn't know the importance relative
to other queued work (e.g. other async scripts, tasks and continuations, etc.). Similar to
`fetch()`, the tag supports a [`fetchpriority`](https://html.spec.whatwg.org/#attr-link-fetchpriority)
attribute for network prioritization, but doesn't have a way to specify the execution priority. We
propose adding a `taskpriority` attribute (a [task priority](#task-priorities)) for this purpose.

**Example: The `taskpriority` `<script>` attribute.**
```html
<!-- Ensure the script execution doesn't get in the way of other pending work. -->
<script async taskpriority="background" ...>
```

For non-async script tags, the `taskpriority` attribute would have no effect.

#### `MessageChannel`

`MessageChannel`s are used to communicate between frames or workers, but are also used as a
scheduling mechanism (same-window case). In either case, the urgency of the messages are unknown to
the UA, which makes determining the event loop priority difficult. For example, some sites may rely
on frame <-> worker communication to drive the site, in which case it might be beneficial to
prioritize messages (and let the site triage them); but in other cases `MessageChannel` is used to
replace `setTimeout(,0)`, in which case always prioritizing is probably the wrong choice.

Like in other cases, we propose adding an option for prioritizing messages, in this case via a new
option in the `MessageChannel` constructor:

```js
// Messages sent between ports are scheduled at 'background' priority in the
// associated event loops.
const channel = new MessageChannel({priority: 'background'});
```

#### Storage APIs

This section is left as future work.

### Key scenarios

These APIs are fundamentally connected through shared priority and signals, and used together they
provide developers over more control of scheduling on their pages.

**Example: Handling a click.** This uses a few scheduling primitives to handle a click event, using
a `TaskSignal` to prioritize continuations and fetches.

```js
// Global controller used to control app state (assume it's used elsewhere).
let appController = new AbortController();

// TaskController used for only for clicks.
let clickController;

button.addEventListener('click', async () => {
  // Abort a previous click.
  if (clickController) {
    clickController.abort();
  }
  clickController = new AbortController();

  // Create a user-blocking task signal dependent on both controllers.
  const signals = [appController.signal, clickController.signal];
  const signal = TaskSignal.any(signals, {priority: 'user-blocking'});

  showSpinner();
  await scheduler.render({signal});

  // Handle the click.
  const start = performance.now();
  const signal = scheduler.currentTaskSignal;
  const res = await fetch(url, {signal});

  let data = await res.json();
  // process() could be a yieldy task.
  data = await process(data);

  // Something like this could used to start a delayed UI update.
  const elapsed = performance.now() - start;
  if (elapsed < 1000) {
    await scheduler.wait(1000 - elapsed, {signal});
  }

  // Display the summary and wait for it to be rendered.
  displaySummary(data);
  await scheduler.render({signal});

  // Display the rest. This could use render() or yield() to further break
  // up the task.
  displayDetails(data);
});
```

## Considered alternatives

### `TaskSignal`

`TaskSignal` inherits from `AbortSignal` to simplify sharing signals between signal-accepting APIs,
rather than creating a separate `PrioritySignal` See [this
issue](https://github.com/WICG/scheduling-apis/issues/13) for more discussion.

### `scheduler.postTask()`

See [this section](./prioritized-post-task.md#alternatives-considered) from the original explainer.

### `scheduler.yield()`

See [this section](./prioritized-post-task.md#alternatives-considered) from the original explainer.

### `scheduler.render()`

There are two common patterns developers can use to get similar behavior, with slightly different
scheduling behavior.

**Double-rAF.** This approach uses a nested `requestAnimationFrame()` to ensure the work starts
after the next frame.
```js
function handleInput() {
  showInitialResponse();
  requestAnimationFrame(() => {
    requestAnimationFrame(continueHandlingInput);
  });
}
```

**rAF + continuation:** This approach also ensure work starts after the next frame, but by
scheduling a non-rAF-aligned continuation from within rAF.
```js
function handleInput() {
  showInitialResponse();
  requestAnimationFrame(() => {
    // Continue ASAP. Without `scheduler`, setTimeout() can be used.
    scheduler.postTask(continueHandlingInput, {priority: 'user-blocking'});
  });
}
```

Note that continuing in the initial `requestAnimationFrame` can lead to poor responsiveness since
the rAF handler blocks the frame. `scheduler.render()` avoids this problem and is more ergonomic for
async code. It is also more efficient in that it doesn't _cause_ a frame if one isn't needed and,
it's more robust in that it works regardless page visibility (which can be important if loading a
page in the background, for example).

The previously proposed
[`requestPostAnimationFrame()`](https://github.com/WICG/request-post-animation-frame/blob/main/explainer.md)
is another alternative. It doesn't have frame-blocking problem, but `scheduler.render()` provides a
scheduling opportunity since the continuation is in a separate task, which is better for
responsiveness.

### `MessageChannel` Prioritization

The main alternative is to prioritize individual messages, either on `self.postMessage` or on a
`MessageChannel`. But this approach would require triaging messages on the receiving side to put
them in the right queues, which would complicate the implementation and raises efficiency concerns.

## Stakeholder Feedback / Opposition

## References & Acknowledgments

Many thanks for valuable feedback and advice from:

 - [anniesullie](https://github.com/anniesullie)
 - [clelland](https://github.com/clelland)
 - [tdresser](https://github.com/tdresser)
