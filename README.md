# Main-thread Scheduling API

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
* 3.loading, navigation (including SPA nav)

#### b. run-loop requires effective coordination with other work on the main thread:

* 1. fetches and network responses
* 2. browser initiated callbacks: eg. onreadystatechange in xhr, post-message from worker etc
* 3. browser’s internal work: eg. GC
* 4. rendering: tasks may be reprioritized dependent on renderer state
* 5. other developer scheduled callbacks: eg. settimeout 


## API Shape

### API Option 1: run-loop is built into the browser
The run-loop could be built into the browser and integrated closely with the browser’s event-loop. This would automatically move #4 into the browser and #3 becomes the platform exposed API. The API sketch follows.

#### Semantic priority for queue
We propose adding default task queues with three semantic priorities, i.e. enum TaskQueuePriority, can be one of these: 

##### 1. "microtask"
Work that should be queued as a microtask, without yielding to the browser.

NOTE: Since [queueMicrotask](https://fergald.github.io/docs/explainers/queueMicrotask.html) is going to ship, it is difficult to justify exposing this priority, as it create redundant platform API surface.

##### 2. "user-blocking"
Work that the user has initiated and should yield immediate results, and therefore should start ASAP.
This work must be completed for the user to continue.
Tasks posted at this priority can delay frame rendering, and therefore should finish quickly (otherwise use "default" priority).

This is typically work in input handlers (tap, click) needed to provide the user immediate acknowledgement of their interation, eg. toggling the like button, showing a spinner or starting an animation when clicking on a comment list etc. 

##### 3. "default"
Normal work that is important, but can take a while to finish.
This is typically initiated by the user, but has dependency on network or I/O.
This is essentially setTimeout(0) without clamping; see other [workarounds used today](https://github.com/spanicker/main-thread-scheduling#3-able-to-schedule-work-reliably-at-normal-priority).

Eg. user zooms into a map, fetching of the maps tiles should be posted as "default" priority.
Eg. user clicks a (long) comment list, it can take a while to fetch all the comments from the server; the fetches should be posted as "default" priority (and potentially show a spinner, posted as "user-blocking" priority).

##### 4. "idle"
Work that is not visible to the user, and not time critical.
Eg. analytics, backups, syncs, indexing, etc.

NOTE: idle priority is similar to rIC. TODO: document why we should expose this directly?

NOTE: These priorities roughly match up with [GCD](https://developer.apple.com/documentation/dispatch/dispatchqos/qosclass) and our own [internal TaskTraits](https://cs.chromium.org/chromium/src/base/task/task_traits.h). However the "render" priority level is missing, this is covered by rAF today.

#### Default set of Serial Task queues
Tasks are guaranteed to start and finish in the order submitted, i.e. a task does not start until the previous task has completed.

A set of global (default) serial task queues will be made available to post work on main thread. There will be a global queue for each priority level.

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

### API Option 1: run-loop is built in a JS library
The run-loop could be built into a JS scheduling library. This would mean that #3 is defined in JS and not a platform primitive. 
The platform exposed API is essentially focused on exposing what's needed for the run-loop:

* 4a. can be addressed with shouldYield proposal.
* 4b. is really difficult to reason about and expose to JS.

TODO: API Sketch / sample code for JS scheduler. 
Eg. React Scheduler, Maps Scheduler <links>


## Appendix: Scheduler case studies
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



