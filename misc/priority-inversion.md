# Priority Inversions with `scheduler.postTask()`

## Introduction

Priority inversion is a risk associated with prioritized task scheduling.
Priority inversions occur when high priority work is blocked by lower priority
work [1], typically resulting in degraded performance. This document explores
priority inversions in the context of `scheduler.postTask()` and what web
developers can do to avoid them.

### The Impact of Priority Inversions on Web Apps

In certain systems, e.g. real-time embedded systems, priority inversions can
have [severe consequences](http://www.cs.cornell.edu/courses/cs614/1999sp/papers/pathfinder.html).
But the most likely outcome for web apps is degraded user experience resulting
from less-than-optimal performance. The impact of priority inversions is
roughly proportional to the queuing time of the lowest priority tasks for a
given site. And while indefinite starvation is possible since `postTask()`
tasks are run in strict priority order, apps tend to reach states of quiescence
after loading or interactivity, implying priority inversions lead to temporary
performance issues. But we will be monitoring the extent of starvation as usage
of the API increases and will consider starvation prevention measures if
needed.

### Differences with Other Platforms

When evaluating the risk of priority inversion on the web, there are a few key
differences with the classic formulation [2] to bear in mind, which makes
analyzing the risk different than other platforms:

 1. JavaScript code is not preempted. Much of the literature around priority
    inversions invovles process/thread preemption. This does not mean priority
    inversions cannot occur, but the landscape is significantly different.

 1. Not all prioritization on the web is specified. `scheduler.postTask()`
    specifies how callbacks scheduled with the API should be ordered, but there
    are many other [task
    sources](https://html.spec.whatwg.org/multipage/webappapis.html#task-source),
    and UAs can prioritize between them how they see fit.

 1. [Userspace tasks](userspace-task-models.md) are complex, often
    [spanning multiple browser task sources](userspace-task-models.md#mixing-async-apis).
    Without first class support for [yieldy asynchronous
    tasks](userspace-task-models.md#yieldy-asynchronous-tasks),
    it is difficult to reason about the "priority of a task" since it is not a
    well-defined concept. `scheduler.postTask()` provides a priority for
    callbacks, but not yet for entire yieldy async tasks.

## Classic Priority Inversion

Priority inversions of any form require a dependency between tasks with
different priorities. In the classic formulation of the problem [2], the
dependency is mutually exclusive access to a shared resource&mdash;implemented
with a lock or monitor. This formulation also requires process preemption,
specifically during the critical section of code protected with a locking
mechanism. The scenario Lampson and Redell described is:

 1. 3 processes of differing priority: P1 < P2 < P3 (< implies lower priority)
 1. P1 starts, eventually acquiring a lock L
 1. P2 preempts P1
 1. P3 preempts P2
 1. P3 attempts to acquire lock L but is blocked by P1
 1. P2 runs again

In the last step, P2 blocks P1 from running since it has higher priority. But
this in turn prevents P3 from getting the lock, and hence we have a priority
inversion (P2 effectively has higher priority than P3). **Note:** it is not
sufficient that P1 has a lock and is preventing P3 from running. If the
critical section is relatively short and P1 wasn't blocked by another task,
then P3 would resume quickly.

So how does the apply to the web and `scheduler.postTask()`?

[Synchronous userspace tasks](userspace-task-models.md#synchronous-tasks)
that use `scheduler.postTask()` are not at risk of priority inversion in the
same way because of the lack of preemption. In fact disabling interrupts to
prevent preemption is one solution to priority inversions [2], which resembles
the run-to-completion behavior of JavaScript. Given the lack of preemption in
JavaScript, writing code that locks critical sections is uncommon and
unnecessary when the critical section is contained within a single synchronous
block that can only be accessed by a single thread.

Where there is a greater risk of priority inversions of this form is with
[yieldy asyncrounous tasks](userspace-task-models.md#yieldy-asynchronous-tasks),
which [resemble threads](userspace-task-models.md#yieldy-asynchronous-tasks-and-threads).
But a key difference is that these tasks are still not
preemptible&mdash; developers must choose to explicitly yield or interact with
a yieldy API. Assessing the risk here is also difficult since the priority can
be lost when [mixing async APIs](userspace-task-models.md#mixing-async-apis)
with `scheduler.postTask()`.

There may be an opportunity for a UA to detect and mitigate priority inversions
that involve primitives like [web
locks](https://developer.mozilla.org/en-US/docs/Web/API/Web_Locks_API), but
that likely requires further refinement of the userspace task model and
priority propagation, which is out of scope for `scheduler.postTask()`. We
believe the best approach for preventing this type of priority inversion is to
be clear that developers need to be careful not to keep resources held while
yielding.

## Other Forms of Priority Inversion

Priority inversions can also occur if there is a dependency between a
not-yet-run low priority task and a higher priority task. This section gives a
couple of examples of how this can occur, along with application-level
mitigations.  These examples are not meant to be exhaustive, but we feel they
help illustrate the types of priority inversions that developers should be
aware of.

### Example 1: Non-Locked Shared Resources

A significantly complex app may have a system for retrieving and caching
resources that is used by multiple parts of the page to avoid duplication of
work. Furthermore, the system might use priorities to schedule work based on
the impact on user experience.

The risk of priority inversion occurs here if a
resource request is started at low priority and a subsequent high priority
request is initiated while the low priority one is pending:

```js
// Note: we assume parts of the processing for such a system is done with
// prioritized tasks. This example would also apply to fetch() if the API was
// aware of postTask priorities.
function getCachedResource(resource, priority) {
  if (needToFetchResource(resource) {
    // Kick off the request in a separate task of the appropriate priority.
    let result = scheduler.postTask(() => {
      return getResourceAtPriority(resource, priority);
    }, {priority});

    // Save off the resulting Promise, which will signal completion.
    setPendingResource(result);
  }

  // Return a promise that will be resolved with the data --- either when the
  // fetching task completes or now if we already have the data.
  return getPromiseForResourceData(resource);
}

...

// The first request for |url| happens at background priority.
getCachedResource(url, 'background').then(...);

...

// A subsequent request for |url| happens just after, at user-blocking priority
// This can lead to a priority inversion if the system is not designed to
// handle this case.
getCachedResource(url, 'user-blocking').then(...);
```

Developers should be aware that such situations could arise. Systems like this
that use internal priorities or a combination of `setTimeout()` and
`requestIdleCallback()` might have already faced such issues. For
`scheduler.postTask()`, there are a couple ways to mitigate this type of
problem at the application-level:

 * Detect that the situation and use the `TaskController`/`TaskSignal` API to
   change the priority of underlying task(s). `scheduler.postTask()` was
   designed around task priorities needing to be dynamic, such as in this
   scenario.

 * Always schedule a new task while the result is pending. This will potentially
   lead to extra processing, but it is a simple way to avoid the dependency.

### Example 2: Yielding Using `scheduler.postTask()`

Consider the following example that uses an no-op task to yield to the event
loop:

```js
async function task() {
  doWork();
  // Yield to stay responsive, but which priority to use?
  await scheduler.postTask(() => {}, {priority: 'background'});
  finishWork();
}

...

scheduler.postTask(task, {priority: 'user-blocking'});
```

There is a *priority mismatch* in this example: `task` was scheduled at
user-blocking priority, but yields at background priority. *If* the entire
yieldy async task is considered user-blocking priority, then the `finishWork()`
portion is blocked by a lower priority task.

The problem in this example is that `task()` is not aware of its priority. This
can be solved by passing the priority or a `TaskSignal` to `task`:

```js
async function task(signal) {
  doWork();
  // Yield to stay responsive.
  await scheduler.postTask(() => {}, {signal});
  finishWork();
}

...

const controller = new TaskSignal('user-blocking');
const signal = controller.signal;
scheduler.postTask(() => task(signal), {signal});
```

Also under consideration to help prevent this particular class of problems are:

 * Passing the signal or *task context*&mdash;which includes priority and
   signal&mdash;to `postTask()` as the first argument
 * [`scheduler.yield()`](../explainers/yield-and-continuation.md) or equivalent,
   which would be designed to propagate priority while yielding
 * [`scheduler.currentTaskSignal`](../explainers/post-task-propagation.md),
   which enables reading and propagating the priority of the current task

## Conclusion

A key difference between the web and other platforms is the lack of preemption.
In preemptive systems, there is a system-level need to address priority
inversions because preempting low priority tasks that have locked resources is
a cause of such inversions. But this is not the case on the web given the lack
of preemption. While priority inversions can still occur, they are likely to be
caused by application code rather than inherent to the system<sup>1</sup>.

From the examples in this document, we think there are two main things web
developers should keep in mind while writing prioritized code:

 1. Be mindful of dependencies created between tasks and potential priority
    mismatches. This applies to both the shared resource and yielding examples
    in the [previous section](#other-forms-of-priority-inversion). In some
    cases, e.g. yielding, additional scheduling APIs can help and are being
    considered. In other cases, `TaskController`s can be used to dynamically
    boost priority to avoid priority inversions.

 1. Don't hold onto locks/resources when yielding to the event loop from a
    task. This risks priority inversions if a higher priority task attempts to
    access the same resource.

<sup>1</sup>Excluding the complication of [mixing async
APIs](userspace-task-models.md#mixing-async-apis). Not retaining the priority
through a yieldy async task could lead to priority inversions, depending on how
the UA schedules between task sources, or to suboptimal scheduling&mdash;but
this is the status quo.

## References

[1] Sha, Lui, Ragunathan Rajkumar, and John P. Lehoczky. "Priority inheritance protocols: An approach to real-time synchronization." IEEE Transactions on computers 39.9 (1990): 1175-1185.

[2] Lampson, Butler W., and David D. Redell. "Experience with processes and monitors in Mesa." Communications of the ACM 23.2 (1980): 105-117.
