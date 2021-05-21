## Case studies: Userspace schedulers
Schedulers have been built in userspace in an attempt to chunk up main thread work and schedule it at appropriate times, in order to improve responsiveness and maintain high and smooth frame-rate.
The specific schedulers we looked at are: [Google Maps Scheduler](https://github.com/spanicker/main-thread-scheduling#case-study-1-maps-job-scheduler) and [React Scheduler](https://github.com/spanicker/main-thread-scheduling#case-study-2-react-scheduler). These [case studies](https://github.com/spanicker/main-thread-scheduling#appendix-scheduler-case-studies) demonstrate that schedulers can be (and have been) built as JS libraries, and also point to the platform gaps that they suffer from.

## Scheduler anatomy: What it takes to build an effective scheduler
We analyzed various scheduling systems, including userspace schedulers above, and determined that the following are core aspects of an effective scheduling system for main thread:

### 1. Set of tasks with priority
Tasks are work items posted by application to be run by scheduler (typically async). Tasks can be posted at specific priority, based on a pre-determined set of priorities.

### 2. “virtual” task-queues for managing groups of tasks
This is to allow the app to:

* dynamically update priority or cancel a group of tasks
* synchronously run queued tasks (flush the queue) when the user navigates away etc

### 3. API for posting tasks
API to enable posting tasks -- at a pre-determined set of priority levels.

### 4. run-loop
A mechanism to execute tasks at an appropriate time, relative to the current state of the user and the browser.

**What does the run-loop need for effective scheduling?**
#### 4a. Knowledge

The run-loop requires knowledge of:
 1. browser's rendering pipeline
  * timing of next frame 
  * time budget within current frame
 2. state of input and user interaction
  * is input pending 
  * how long do we have before input should be serviced
  * loading, navigation

#### b. Coordination
The run-loop requires effective coordination with other work on the main thread:

 1. fetches and network responses
 2. browser initiated callbacks: eg. onreadystatechange in xhr, post-message from worker etc
 3. browser’s internal work: eg. GC
 4. other developer scheduled callbacks: eg. settimeout
 5. propagation of priority across a series of related async calls
 6. rendering: tasks may be reprioritized depending on renderer state
 7. knowledge of read / write renderinng phases to avoid layout thrashing from interleaved reads & writes

### Priorities for tasks

For work that the user has initiated by interacting with the app, the app developer would have to determine what action needs to be taken, and how to schedule work to target appropritate timing that is compatible with browser's rendering pipeline.

Input handlers (tap, click etc) often need to schedule a combination of different kinds of work:
* kicking off some immediate work as microtasks eg. fetching from local cache
* scheduling data fetches over the network
* rendering in the current frame eg. to respond to user typing, toggle the *like* button, start an animation when clicking on a comment list etc.
* rendering over the course of next new frames, as fetches complete and data becomes available to prepare and render results.

#### 1. "Immediate" priority
Urgent work that must happen immediately.
This is essentially microtask timing: occurs right after current task and does not yield to the browser's event loop.

NOTE: [queueMicrotask](https://fergald.github.io/docs/explainers/queueMicrotask.html) provides a direct API for submitting microtasks.

NOTE: we've seen bad cases where developers accidentally do large, non-urgent work in microtasks -- with promise.then and await, without realizing it blocks rendering.

#### 2. "render-blocking" priority (render-immediate?)
Urgent rendering work that must happen in the limited time *within the current frame*.
This is typically work in requestAnimationFrame: i.e. rendering work for ongoing animations and dom manipulation that needs to render right away.
Tasks posted at this priority can delay rendering of the current frame, and therefore should finish quickly (otherwise use "default" priority).

#### 2. "default" priority (or render-normal?)
User visible work that is needed to *prepare for the next frame* (or future frames).
Normal work that is important, but can take a while to finish.
This is typically rendering that is needed in response to user interaction, but has dependency on network or I/O, and should be rendered over next couple frames - as the needed data becomes available.
This work should not delay current frame rendering, but should execute immediately afterwards to pipeline and target the next frame.

NOTE: This is essentially setTimeout(0) without clamping; see other [workarounds used today](https://github.com/spanicker/main-thread-scheduling#3-after-paint-callback)

Eg. user zooms into a map, fetching of the maps tiles OR atleast post-processing of fetch responses should be posted as "default" priority work to render over subsequent frames.
Eg. user clicks a (long) comment list, it can take a while to fetch all the comments from the server; the fetches should be handled as "default" priority (and potentially start a spinner or animation, posted at "render-blocking" priority).

NOTE: while it *may* make sense to kick off fetches in input-handler, handling fetch responses in microtasks can be problematic, and could block user input & urgent rendering work.

#### 3. "idle"
Work that is typically not visible to the user or initiated by the user, and is not time critical.
Eg. analytics, backups, syncs, indexing, etc.

requestIdleCallback (rIC) is the API for idle priority work.

## Appendix: Scheduler case studies
NOTE: See [recent Slides here](https://docs.google.com/presentation/d/1HGBOAfVhmWoyOt2ETk-1Y2dOvuMyRnQ5AF7VrPBvfX0/edit).

### Case study 1: Maps’ Job Scheduler
The scheduler attempts to render at the native framerate (usually ~60 fps) but falling back to unit fractions of the native framerate (e.g. 1/2 native at ~30 fps, 1/3 native at ~20 fps, etc) if the native framerate cannot be achieved.
It works by classifying all work into several stages:
1. Input: updating model state in response to user input.
2. Animation: updating model state based on the current time.
3. Rendering: drawing to the screen based on current model state.
4. Other: everything else
Note that 1, 2, and 3 must be done on every frame and is scheduled via rAF, everything else does not need to be done on every frame and is scheduled either through rIC OR in deferred manner to yield to the browser (postmessage after rAF, or settimeout 0). 
In response to events, Jobs of one of these types are created and scheduled with the JobScheduler to be run.

Maps needs throttling of frame-rate in the following cases:

* on start-up, for prioritizing initialization over animation FPS 
* when switching into 3d Earth mode, and there's lots of data fetching and 3d model building to do, and it's not worth showing 60 fps of gradual build-up of this.

### Case-study 2: React Scheduler
Link to [code is here](https://github.com/facebook/react/blob/43a137d9c13064b530d95ba51138ec1607de2c99/packages/react-scheduler/src/ReactScheduler.js)

It works by scheduling a rAF, noting the time for the start of the frame, then scheduling a postMessage which gets scheduled after paint. Within the postMessage handler do as much work as possible until time + frame rate.
Separating the "idle call" into a separate event tick ensures yielding to the browser work, and counting it against the available time.

Frame rate is dynamically adapted. The scheduler [defaults to a target of 30 fps](https://github.com/facebook/react/blob/43a137d9c13064b530d95ba51138ec1607de2c99/packages/react-scheduler/src/ReactScheduler.js#L176) for standard units of work. It detects higher frame rate by timing successive scheduling of frames, and increasing to a higher target FPS if appropriate. 

Instead of task priority levels, it uses expiration times. This enables dynamic adjustment: something that starts as low priority gets higher as it approaches the deadline. Expired tasks are the most important.

Whenever enqueuing via rAF, they also set a 100ms timeout, if the timeout is fired first it cancels the rAF and executes its associated tasks. This is a workaround for rAF not running in background & on occlusion. 

