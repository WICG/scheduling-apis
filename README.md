# Main-thread Scheduling API
For an overview, see: [Slides presented at TPAC 2018](https://docs.google.com/presentation/d/12lkTrTwGedKSFqOFhQTsEdcLI3ydRiAdom_9uQ2FgsM/edit?usp=sharing)

Also this [talk from Chrome Dev Summit](https://youtu.be/mDdgfyRB5kg) covers the problem and larger direction.

## Motivation: Main thread contention
Consider a "search-as-you-type" application:

This app needs to be responsive to user input i.e. user typing in the search-box. At the same time any animations on the page must be rendered smoothly, also the work for fetching and preparing search results and updating the page must also progress quickly. 

This is a lot of different deadlines to meet for the app developer. It is easy for any long running script work to hold up the main thread and cause responsiveness issues for typing, rendering animations or updating search results.

This problem can be tackled by systematically chunking and scheduling main thread work i.e. prioritizing and executing work async at an appropriate time relative to current situation of user and browser. 
A Main Thread Scheduler provides improved guarantees of responsiveness.

## Case studies: Userspace schedulers
Schedulers have been built in userspace in an attempt to chunk up main thread work and schedule it at appropriate times, in order to improve responsiveness and maintain high and smooth frame-rate.
The specific schedulers we looked at are: [Google Maps Scheduler](https://github.com/spanicker/main-thread-scheduling#case-study-1-maps-job-scheduler) and [React Scheduler](https://github.com/spanicker/main-thread-scheduling#case-study-2-react-scheduler). These [case studies](https://github.com/spanicker/main-thread-scheduling#appendix-scheduler-case-studies) demonstrate that schedulers can be (and have been) built as JS libraries, and also point to the platform gaps that they suffer from.

## Scheduler anatomy: What it takes to build an effective scheduler
We analyzed various scheduling systems, including userspace schedulers above, and determined that the following are core aspects of an effective scheduling system for main thread:

### 1. Set of tasks with priority
Tasks are work items posted by application to be run by scheduler (typically async). Tasks can posted at specific priority, based on a pre-determined set of priorities.

### 2. “virtual” task-queues for managing groups of tasks
This is to allow the app to:

* dynamically update priority or cancel a group of tasks
* synchronously run queued tasks (flush the queue) when the user navigates away etc

### 3. API for posting tasks
API to enable posting tasks -- at known priority levels.

### 4. run-loop
A mechanism to execute tasks at an appropriate time, relative to the current state of the user and the browser.
**What does the run-loop need for effective scheduling?**
#### 4a. run-loop requires knowledge of:

* 1. rendering
  * timing of next frame 
  * time budget within current frame
* 2. input
  * is input pending 
  * how long do we have before input should be serviced
* 3. loading, navigation

#### b. run-loop requires effective coordination with other work on the main thread:

* 1. fetches and network responses
* 2. browser initiated callbacks: eg. onreadystatechange in xhr, post-message from worker etc
* 3. browser’s internal work: eg. GC
* 4. rendering: tasks may be reprioritized dependent on renderer state
* 5. other developer scheduled callbacks: eg. settimeout 

### Priorities for tasks
 
#### 1. "user-blocking"
Urgent work that must happen in the limited time *within the current frame*.
Work that the user has initiated and should yield immediate results, and therefore should start ASAP.
This work must be completed for the user to continue.
Tasks posted at this priority can delay frame rendering, and therefore should finish quickly (otherwise use "default" priority).

This is work in:

* input handlers: (tap, click) needed to provide the user immediate acknowledgement of their interation, eg. toggling the like button, showing a spinner or starting an animation when clicking on a comment list etc. 
* requestAnimationFrame: rendering work for ongoing animations 
* microtasks: are user-blocking priority, and do not yield to the browser's event loop.

NOTE: we've seen bad cases where developers accidentally do large, non-urgent work in microtasks -- with promise.then and await, without realizing it blocks rendering.

NOTE: [queueMicrotask](https://fergald.github.io/docs/explainers/queueMicrotask.html) is going to provide a direct API for submitting microtasks.

#### 2. "default"
User visible work that is needed to *prepare for the next frame* (or future frames).
Normal work that is important, but can take a while to finish.
This is typically initiated by the user, but has dependency on network or I/O.
This is essentially setTimeout(0) without clamping; see other [workarounds used today](https://github.com/spanicker/main-thread-scheduling#3-after-paint-callback)

Eg. user zooms into a map, fetching of the maps tiles OR atleast post-processing of fetch responses should be posted as "default" priority.
Eg. user clicks a (long) comment list, it can take a while to fetch all the comments from the server; the fetches should be handled as "default" priority (and potentially show a spinner, posted as "user-blocking" priority).

NOTE: it may make sense to kick off fetches in input-handler, however handling fetch responses in microtasks can be problematic, and could block user input & urgent rendering work.

#### 3. "idle"
Work that is not visible to the user, and not time critical.
Eg. analytics, backups, syncs, indexing, etc.

requestIdleCallback (rIC) is the API for idle priority work.


## API Shape
We intend to pursue a two-pronged approach:

* I. Ship primitives to enable Javascript / userland schedulers to succeed: above components of scheduling can be built in javascript. However there are gaps that need to be filled for [4a](https://github.com/spanicker/main-thread-scheduling/blob/master/README.md#4a-run-loop-requires-knowledge-of) and [4b](https://github.com/spanicker/main-thread-scheduling/blob/master/README.md#4a-run-loop-requires-knowledge-of). These can be tackled as a set of APIs to plug these gaps. 
* II. Show proof-of-concept for a native platform scheduler, that is directly integrated into the browser's event-loop.

More details below, for each approach. 

### I. APIs to improve JS schedulers

The following (primitive) APIs are being pursued currently:
#### 1. Is Input Pending
Knowledge of whether input is pending, and the type of input.
This is covered here:
https://github.com/tdresser/should-yield

#### 2. Expected time to next animation frame
JS schedulers are estimating the time to next animation frame with book-keeping, but it's not possible to be estimate this properly without knowing browser internals.

TODO: Add link to repo.

#### 3. "After-paint" callback
Schedulers need to execute "default priority" work immediately following the document lifecycle (style, layout, paint).
Currently they use workarounds to target this with:

* postmessage after each rAF (used by ReactScheduler):
* messagechannel workaround (google3 nexttick used by Maps etc): use a private message channel to postMessage empty messages; also tacked on after rAF. A bug currently prevents yielding.
* settimeout 0: doesn’t work well, in Chrome this is clamped to 1ms and to 4ms after N recursions.

TODO: Add link to repo.

#### 4. Propagating scheduling Context for async work
Similar in spririt to zone.js. We need a way to inherit and propagate scheduling priority across async things: fetches, promises etc.

TODO: Add link to repo.

### II. Built-in API
The run-loop could be built into the browser and integrated closely with the browser’s event-loop. This would automatically move #4 into the browser and #3 becomes the platform exposed API. The API sketch follows.

We propose adding default task queues with three semantic priorities, i.e. enum TaskQueuePriority, can be one of these:

* User-blocking
* Default
* Idle

#### Global set of Serial Task queues
Tasks are guaranteed to start and finish in the order submitted, i.e. a task does not start until the previous task has completed.

A set of global serial task queues will be made available to post work on main thread. There will be a global queue for each priority level.

#### API for posting & canceling tasks
NOTE: syntax is likely to change for compatibility for posting work off main thread variant (TODO: Link to repo).

```
function mytask() {
  ...
}

myQueue = TaskQueue.default("user-blocking") 
```
returns the global task queue with priority “user-blocking”, for posting to main thread.
```
taskId = myQueue.postTask(myTask, <list of args>);
```
where myTask is a callback.
The return value is a long integer, the task id, that uniquely identifies the entry in the queue. 

```
myQueue.cancelTask(taskId);
```
taskId can be used to later cancel the task.

NOTE: The return type could be a promise instead of ID, for convenience and chaining of tasks. If so, then [AbortController](https://developer.mozilla.org/en-US/docs/Web/API/AbortController) is a standard way to cancel pending promises.

#### User-defined task queues
Developers can define their own “virtual” serial task queues:
```
myQueue = new TaskQueue(‘myCustomQueue’, "default");
myQueue.postTask(task, <list of args for task>);
```
where task is a function.

User-defined task queues enables the app to manage a group of tasks, such as updating priority, canceling, draining (synchronously executing tasks) when the page is hidden etc.

Updating priority of entire queue: ```myQueue.updatePriority(<new priority>);```
Updating priority of specific task is equivalent to canceling that task and re-posting at a different priority. 
Flushing the queue: ```myQueue.flush();```

TODO: supporting additional priorities, beyond small set of semantic priorities. Add API ideas for this.

### Open Questions & Challenges

- DOM read-write phase: either exposing the phase or allowing tasks to specify read vs write etc
- API for frame rate throttling: 30 vs. 60fps
- handling 3P and non-cooperating script (directly embedded) in the page 
- lowering priority of event handlers (similar to “passive”)

## Appendix: Scheduler case studies
NOTE: See [recent Slides here](https://docs.google.com/presentation/d/1HGBOAfVhmWoyOt2ETk-1Y2dOvuMyRnQ5AF7VrPBvfX0/edit).

### Case study 1: Maps’ Job Scheduler
The scheduler attempts to render at the native framerate (usually ~60fps) but falling back to unit fractions of the native framerate (e.g. 1/2 native at ~30fps, 1/3 native at ~20fps, etc) if the native framerate cannot be achieved.
It works by classifying all work into several stages:
1. Input: updating model state in response to user input.
2. Animation: updating model state based on the current time.
3. Rendering: drawing to the screen based on current model state.
4. Other: everything else
Note that 1, 2, and 3 must be done on every frame and is scheduled via rAF, everything else does not need to be done on every frame and is scheduled either through rIC OR in deferred manner to yield to the browser (postmessage after rAF, or settimeout 0). 
In response to events, Jobs of one of these types are created and scheduled with the JobScheduler to be run.

Maps needs throttling of frame-rate in the following cases:

* on start-up, for prioritizing initialization over animation FPS 
* when switching into 3d Earth mode, and there's lots of data fetching and 3d model building to do, and it's not worth showing 60fps of gradual build-up of this.

### Case-study 2: React Scheduler
Link to [code is here](https://github.com/facebook/react/blob/43a137d9c13064b530d95ba51138ec1607de2c99/packages/react-scheduler/src/ReactScheduler.js)

It works by scheduling a rAF, noting the time for the start of the frame, then scheduling a postMessage which gets scheduled after paint. Within the postMessage handler do as much work as possible until time + frame rate.
Eeparating the "idle call" into a separate event tick ensures yielding to the browser work, and counting it against the available time.

Frame rate is dynamically adapted. The scheduler [defaults to a target of 30fps](https://github.com/facebook/react/blob/43a137d9c13064b530d95ba51138ec1607de2c99/packages/react-scheduler/src/ReactScheduler.js#L176) for standard units of work. It detects higher frame rate by timing successive scheduling of frames, and increasing to a higher target FPS if appropriate. 

Instead of task priority levels, it uses expiration times. This enables dynamic adjustment: something that starts as low priority gets higher as it approaches the deadline. Expired tasks are the most important.

Whenever enqueuing via rAF, they also set a 100ms timeout, if the timeout is fired first it cancels the rAF and executes its associated tasks. This is a workaround for rAF not running in background & on occlusion. 



