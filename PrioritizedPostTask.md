# Main Thread Scheduling: Prioritized postTask API

For an overview of the larger problem space, see [Main Thread Scheduling API](README.md).

## TL;DR

Userspace tasks often have varying degrees of importance (related to user
experience), but the Platform lacks a unified API to schedule prioritized work.


## The Problem

To keep apps responsive, developers should break up long tasks into smaller chunks.
[Userspace schedulers](UserspaceSchedulers.md) often manage these chunks of
work (tasks)&mdash;prioritizing and executing work async at an appropriate time
relative to the current situation of the user and browser.

These tasks&mdash;or groups of related tasks&mdash;usually have a priority
attached, i.e. not all work has the same importance. Work related to rendering
in-viewport content, for example, is more important than rendering content that
is just out of the viewport but might be seen soon (note: priority can
change in response to user input).

Userspace schedulers use priority to order execution of tasks they control, but
this has limited meaning since they do not control all tasks on the page. Apps
can consist of 1P, 1P library, 3P, and (one or more) framework script, all of
which competes for the main thread. At the same time, the browser has tasks to
run on the main thread, such as async work (e.g. `fetch()` and IDB tasks) and
garbage collection.

The problem is that *most* of these tasks run at the same priority, as the
Platform only exposes a few priorities, either explicitly or implicitly through
a disparate set of APIs:

![Current Web Priorities](images/web_priorities_current.png)

The first two&mdash;*microtask* and *don't yield*&mdash;are generally
antithetical to scheduling and the goal of improving responsiveness. They are
*implicit* priorities that developers can and do use.

requestAnimationFrame(), which was designed for animations, is used (abused) by
userspace code to gain higher priority, since rendering is often prioritized by
UAs. Scheduling work at this "priority" has the disadvantage of incurring extra
overhead caused by running the rendering lifecylce updates (they may early-out,
but this is still more heavy-weight than may be needed if not updating DOM).

Idle callbacks run when there is no other work that can be done. This is a good
scheduling tool, but not sufficient.

Everything else runs at the same priority between frames.

### Lack of a unified API

A sub-problem here is that there is no unified scheduling API. Instead,
developers have had to resort to various hacks, such as using [postMessage to get
around setTimeout(0)'s delay](https://dbaron.org/log/20100309-faster-timeouts),
or using rAF to gain higher priority.

This complicates code, is onerous for developers to learn and write, and can
have negative peformance effects (e.g. gratuitous rendering lifecycle updates).

## Proposal

To address these problems, we propose adding a unified prioritized task
scheduling API, in which developers can schedule work with a set of standard
priorities directly through a native scheduler.

The API is centered around prioritized `TasksQueues`:
 + The `Scheduler` maintains a set of shared global task queues, and a set of
 user-defined task queues.
 + `Tasks` are enqueued in one of the `TaskQueues`.
 + Each `TaskQueue` has a priority, which the `Task` inherits.

To schedule work, developers can post a task to the scheduler with
`scheduler.postTask()`, or interact directly with individual task queues.

(**Note**: we are also interested in pursuing priorities for other tasks such as
`<script>` and  `fetch()`, but this is out of scope for this API.)

### Priorities

At the core of this API is a set of priorities. How many priorities to expose
is an interesting queston (see FAQ); minimally, we need to add priorities above
and below the existing "default" priority, and propose adding additional
priorities that map closely to existing APIs:

![New Web Scheduling Priorities](images/web_priorities_proposed.png)

1. **Immediate**: Immediate priority tasks run as soon as the scheduler regains
control, and will generally run before rendering and user input.

2. **High**: The highest priority for inter-frame script that still (generally)
yields to rendering. This can be used for important tasks that need to run
before most other work, e.g. processing for content that should be visible as
soon as possible.

3. **Default**: This priority is used for most existing tasks and should be
used for work that doesn’t need an elevated priority.

4. **Low**: Low priority can be used to deprioritize work that is not as
important relative to high and default, but still is still more important than
idle work.

5. **Idle**: Idle is for background work, and idle tasks will only run if no
other tasks are runnable. These tasks compete only with other idle tasks and
`requestIdleCallback()`.

### Global Task Queues 

The `scheduler` (per-document, global scope) will maintain a set of global
serial task queues with the priorities listed above. The scheduler selects
the oldest task from the highest priority task queue as the next task to run.

E.g. Posting a task through `window.scheduler`:

```javascript
function importantWork() {
  ...
}

let task = scheduler.postTask(importantWork, {priority: 'high'});
...
```

E.g Chaining together dependent scheduled tasks. The scheduled tasks run async
with task timing, not microtask timing.

```javascript
async function computeSomething() {
  // Tasks are posted at default priority. schedule() is a global function that
  // integrates with window.scheduler.
  let res1 = await schedule(doSubTask1);
  // ...
  // Do something with |res1|...
  // ...
  let res2 = await schedule(doSubTask2);
  return res1 + res2;
}

```

### Canceling Tasks and Changing Task Priorities

Tasks might need to be canceled or their priorities changed, for example if a
user interaction changes what an app needs to do next.

```javascript
let nextTask = scheduler.postTask(renderAwesomeThing);

function amazingButtonClicked() {
  if (nextTask)
    nextTask.cancel();
  nextTask = scheduler.postTask(renderMoreAwesomeThing);
}
```

E.g. Change a task priority by moving it to a different global task queue.

```javascript
let importantPendingTask = scheduler.postTask(renderAwesomeThing, {priority: 'high'});

...

scheduler.getTaskQueue('low').take(importantPendingTask);
```

### Delayed task posting

Tasks may need to run after a delay, essentially as a prioritized version of
setTimeout(). This can be useful for implementing more complex app-specific
scheduling logic, for example to implement deadline-based scheduling.

```javascript
function deadlineScheduler() {
  ...
}

let delayedTask = scheduler.postTask(deadlineScheduler, {priority: 'high', delay: nextDeadline});

```

### User-defined task queues

Developers can create their own serial task queues to manage groups of tasks.
This allows developers to act on the tasks as a group, e.g. to change the
priority, disable the TaskQueue, etc.

```javascript
function doWork() {
  ...
}

let myQueue = new TaskQueue('default');
myQueue.postTask(doWork);
```

User-defined task queues enables the app to manage a group of tasks, such as
updating priority, canceling, flushing tasks when the page is hidden, etc.

Updating priority of entire queue:
```javascript
myQueue.setPriority('immedidate');
```

Flushing the queue, for example to run important pending tasks prior to a
document lifecycle change.
```javascript
myQueue.flush();
```

Canceling all tasks in the queue:
```javascript
myQueue.clear();
```

## Frequently Asked Questions

### How many priorities should there be?

There is a tension between supporting every use case (someone will always need
the Nth + 1 priority), and making the priorites meaningful across the system. A
smaller set of priorities favors the latter, and there is a precedence for this
in successful frameworks like GCD (see
[QoSClass](https://developer.apple.com/documentation/dispatch/dispatchqos/qosclass)).

Developers that need more priorities can use the native ones to specify where
their tasks should run relative to other tasks in the system&mdash;based on how
they effect user experience&mdash;and use user-defined task queues or arrays to
multiplex the native priority.

### What about deprioritized frames?

Some UAs may deprioritize certain frames of a page that share the main thread.
If a frame is off-screen, for example, it may be depriorized since its contents
cannot be seen.

The `scheduler` is a window object, and the priorities determine the order that
tasks run for an individual *document*. The browser may choose to throttle
certain frames, and so the priority system is not global across documents. In
other words, a high-priority task in a low-priority document may not
high-priority overall.

### How does API work with the [Idle Until Urgent](https://philipwalton.com/articles/idle-until-urgent/) pattern?

(**TODO**: Fill this in.)

### What about starvation?

(**TODO**: Fill this in.)

### How does the system handle priority inversions?

(**TODO**: Fill this in.)

## Further Reading / Viewing

 * WebPerfWG F2F Presentation - June 2019 [[slides](https://docs.google.com/presentation/d/1GUB081FTpvFEwEkfePagFEkiqcLKKnIHkhym-I8tTd8/edit#slide=id.g5b43bd1ecf_0_508), [video](https://www.youtube.com/watch?v=eyAW4FuSgyE&t=14387)]: `scheduler.yield()` and `scheduler.postTask()` are presented and discussed
 * Detailed [Scheduling API Proposal](https://docs.google.com/document/d/1xU7HyNsEsbXhTgt0ZnXDbeSXm5-m5FzkLJAT6LTizEI/edit#heading=h.iw2lczs6xwe6)
 * [MVP Proposal](https://docs.google.com/document/d/1AATlW1ohLUgjSdqukgDx3C0P6rnJFgZavmKoZxGb8Rw/edit?usp=sharing)
 * [Priority-Based Web Scheduling](https://docs.google.com/document/d/1AATlW1ohLUgjSdqukgDx3C0P6rnJFgZavmKoZxGb8Rw/edit?usp=sharing) dives into various scheduling priority systems
