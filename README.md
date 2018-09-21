# Main thread Scheduling

## Motivation: Main thread contention
Most user interactions (like taps, clicks) and rendering require main thread work. Script also executes on the main thread. It is easy for long running script to hold up the main thread and cause responsiveness issues, such as:

* High/variable input latency: critical user interaction events (tap, click, scroll, wheel, etc) are queued behind long tasks, which yields janky and unpredictable user experience.
* High/variable event handling latency: similar to input, but for processing event callbacks (e.g. onload events etc), which delay application updates.
* Janky animations and scrolling: some animation and scrolling interactions require coordination between compositor and main threads; if the main thread is blocked due to a long task, it can affect responsiveness of animations and scrolling.

**Key strategies** for addressing main thread contention and improving responsiveness:
1. Break up script work into chunks and execute asynchronously on main thread
2. Move work off the main thread

These are essentially scheduling problems, improved scheduling will result in better guarantees of responsiveness.
This explainer will focus on #1: scheduling on main thread.
TODO(panicker): link to explainer for #2 Off Main Thread Scheduling.

## Main Thread Scheduling
Schedulers have been built in userspace to chunk up main thread work and schedule it at appropriate times, in order to improve responsiveness and maintain high and smooth frame-rate.
The specific schedulers we looked at are: [Google Maps Scheduler](https://github.com/spanicker/main-thread-scheduling#case-study-1-maps-job-scheduler) and [React Scheduler](https://github.com/spanicker/main-thread-scheduling#case-study-2-react-scheduler). These [case studies](https://github.com/spanicker/main-thread-scheduling#appendix-scheduler-case-studies) demonstrate that schedulers can be (and have been) built as JS libraries, and also point to the platform gaps that they suffer from.

### High level goals
We want to explore two avenues:
#### a. High level API
a higher level scheduler API, potentially part of [“standardized” library](https://github.com/tc39-transfer/proposal-javascript-standard-library/blob/master/slides-JS-std-lib-July-2018.pdf).
#### b. Low level API & Platform primitives
develop primitives to fill platform gaps so that (above higher level) scheduler library can be successful and so that it is easier to serve the goal of “improved responsiveness guarantees”.

### Platform Gaps
**The yielding & coordination issue**

JS should schedule work while yielding to the browser for rendering and input.
JS schedulers need to be able to schedule chunks of work, and importantly, yield to the browser -- so that the frame is not overrun and so the browser is able to do its rendering work, and other important work like handling input.
Currently JS schedulers have to guess when the browser needs to do pertinent work, when it will schedule posted work, and how much browser-side work is remaining.
While rAF is suited for render related work that needs to happen per frame, there is lot of other work that is lower priority and should get out of the way of input and render. OTOH there is work that is higher priority than rendering at a given time eg. fetching critical components during loading.

Also, the browser doesn’t have insight into JS work and knowledge of priority that could help it to more effectively schedule this, as well as schedule it appropriately relative to browser’s own work and other async app work (such as processing network responses).

### Requirements for new Platform primitives
The following issues require platform primitives to address, and constitute the requirements for solutions:
#### 1. Able to get out of the way of important work (input, rendering etc).
NOTE: [shouldYield proposal](https://discourse.wicg.io/t/shouldyield-enabling-script-to-yield-to-user-input/2881) targets this issue. Eg. from shouldYield: \
during page load, an app needs to initialize a set of components and scripts. These are ordered by priority: for example, first installing event handlers on primary buttons, then a search box, then a messaging widget, and then finally moving on to analytics scripts and ads.
The developer wants to complete this work as fast as possible. For example, the messaging widget should be initialized by the time the user interacts with it. However when the user taps one of the primary buttons, they shouldn’t block until the entire page is ready.

#### 2. Able to schedule work at a higher priority than rendering 
Using rAF doesn’t fit in some cases, where it is not rendering work:

* Eg. when user zooms on Google Map, it is more important to quickly fetch Maps tiles than to render.
* Eg. during page navigation, it could be more important to fetch and prepare the critical content of the page, than rendering.

#### 3. Able to schedule work reliably at “normal” priority
JS schedulers need to schedule “normal” priority work, that execute at an appropriate time (eg. after paint), to spread out work while yielding to the browser (as opposed to using rIC for “idle time” work or rAF for rendering work). 
Currently they use workarounds which are inefficient and often buggy compared to first class platform support:

* messagechannel workaround (google3 nexttick used by Maps etc): use a private message channel to postMessage empty messages. A [bug](https://bugs.chromium.org/p/chromium/issues/detail?id=867133) currently prevents yielding.
* postmessage after each rAF ([used by ReactScheduler](https://github.com/facebook/react/blob/43a137d9c13064b530d95ba51138ec1607de2c99/packages/react-scheduler/src/ReactScheduler.js#L278)): using rAF is high overhead due to cost of rendering machinery, and guessing the idle budget without knowledge of browser internals is prone to cause jank.
* settimeout 0: doesn’t work well, clamped to 1ms and to 4ms after N recursions.
* “await yield” pattern in JS: causes a microtask to be queued 

**Why not just use rIC?**
rIC is suited to idle time work, not normal priority work AFTER yielding to browser (for important work). By design, rIC has the risk of starvation and getting postponed indefinitely.

#### 4. Able to prioritize network fetches and timing of responses
Processing of network responses (parsing and execution) happens async and can occur at inopportune times relative to other ongoing work which could be more important.
Certain responses are time sensitive (eg. when needed to respond to user interaction) while others could be lower priority (eg. optimistic prefetching).

#### 5. [MAYBE?] Able to classify priority for input (handlers)
Similar to #4 above, but for input.

* certain input is low priority (relative to current work in the app)
* certain input is urgent and needs to be processed immediately without synchronizing to rendering (waiting until rAF)
TODO: Add examples.

#### 6. Able to target lower or different frame rate
Apps do not have access to easily learn the browser’s current target frame rate, and have to infer this withbook-keeping and guessing.
Furthermore, apps are not easily able to target a different frame rate, or ask the browser to target different frame rate; default targeting 60fps can often result in starving of other necessary work.
Use-cases:

* Eg. Maps is building a throttling scheduler (non-trivial effort) for the purpose of targeting a lower frame rate during certain cases like zooming, when a lot of tiles need to be loaded, and rendering work can easily starve the loading work.
* Eg. The React scheduler defaults to a target of 30fps with their own book-keeping, and have built [detection](https://github.com/facebook/react/blob/43a137d9c13064b530d95ba51138ec1607de2c99/packages/react-scheduler/src/ReactScheduler.js#L333) (by timing successive scheduling of frames) for increasing to a higher target FPS. 

Some of the above could be addressed with JS library except for changing browser's target frame rate, as well as accurately knowing what the current target rate is.


### Why a standardized library?
Above covers gaps in the platform, in addition there are other problems that a (higher level) standardized scheduling library would address:
#### i. Easier to use disparate set of scheduling APIs
Too many disparate scheduling APIs (rAF, rIC, settimeout) that require managing time budgets and bookkeeping -- that developers can’t understand when/how to use correctly.

#### ii. Address userspace “coordination” issue (multi-actor problem)
JS needs to cooperatively schedule between different parts of the app, and they need a common set of priorities for tasks.
Some parts of the app may be using a JS scheduler with priorities but other parts of the app may not or may use a different priority mechanism (eg. embedded libraries). So low priority work in one system can get prioritized over high priority work in another.\
Some motivating discussion here: https://github.com/w3c/requestidlecallback/issues/68

#### iii. Easier to reason about and track priority
JS library could make it easy to trace back current work to what triggered the work and corresponding priority, and make it easier to connect the dots. 
For instance, in response to high priority user interaction, work is flowing through the system (fetches, post-processing, followed by rendering) and should inherit the original priority. 

#### iv. Dynamically update task priority and cancelling tasks
The priority of a posted task is not static and can change after posting.
For instance work that was initially post as opportunistic prefetching, can become urgent if the current user interaction needs it.\
Eg. React Scheduler uses expiration time instead of priority, so the times can dynamically update, and expired tasks are the highest priority.
TODO(panicker): To what extent can this be addressed with higher level vs. lower level API.

## API Sketch
NOTE: these are early, premature API sketches, read as such. Feedback is appreciated.

### Semantic priority for queue
Semantic priority i.e. enum TaskQueuePriority can be one of these: 

* "user-blocking"
* "user-visible" (similar priority as rAF)
* "default"
* "background" (similar priority as rIC)

NOTE: These match up with GCD and somewhat match our own internal TaskTraits.

### Default set of Serial Task queues
Tasks are guaranteed to start and finish in the order submitted, i.e. a task does not start until the previous task has completed.

A set of global (default) serial task queues will be made available to post work on main thread. There will be a global queue for each priority level.

NOTE: syntax is likely to change for compatibility for posting work off main thread variant (TODO: Link to repo).

```
function mytask() {
  ...
}

myQueue = TaskQueue.default("user-blocking") 
```
returns the global task queue with priority “user-blocking”, for posting to main thread.
```
myQueue.postTask(mytask, <list of args>).then(doSomethingElse);
```
where task is a function.


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

### Case-study 2: React Scheduler
Link to [code is here](https://github.com/facebook/react/blob/43a137d9c13064b530d95ba51138ec1607de2c99/packages/react-scheduler/src/ReactScheduler.js)

It works by scheduling a rAF, noting the time for the start of the frame, then scheduling a postMessage which gets scheduled after paint. Within the postMessage handler do as much work as possible until time + frame rate.
Eeparating the "idle call" into a separate event tick ensures yielding to the browser work, and counting it against the available time.

Frame rate is dynamically adapted. The scheduler [defaults to a target of 30fps](https://github.com/facebook/react/blob/43a137d9c13064b530d95ba51138ec1607de2c99/packages/react-scheduler/src/ReactScheduler.js#L176) for standard units of work. It detects higher frame rate by timing successive scheduling of frames, and increasing to a higher target FPS if appropriate. 

Instead of task priority levels, it uses expiration times. This enables dynamic adjustment: something that starts as low priority gets higher as it approaches the deadline. Expired tasks are the most important.

Whenever enqueuing via rAF, they also set a 100ms timeout, if the timeout is fired first it cancels the rAF and executes its associated tasks. This is a workaround for rAF not running in background & on occlusion. 



