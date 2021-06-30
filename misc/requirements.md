## Thoughts on API Requirements

### 1. Able to get out of the way of important work (input, rendering etc).
NOTE: shouldYield proposal targets this issue. Eg. from shouldYield: 
during page load, an app needs to initialize a set of components and scripts. These are ordered by priority: for example, first installing event handlers on primary buttons, then a search box, then a messaging widget, and then finally moving on to analytics scripts and ads. The developer wants to complete this work as fast as possible. For example, the messaging widget should be initialized by the time the user interacts with it. However when the user taps one of the primary buttons, they shouldn’t block until the entire page is ready.

### 2. Able to schedule work reliably at “normal” priority, without unnecessarily invoking rendering
JS schedulers need to schedule “normal” priority work, that execute at an appropriate time (eg. after paint), to spread out work while yielding to the browser (as opposed to using rIC for “idle time” work or rAF for rendering work). Currently they use workarounds which are inefficient and often buggy compared to first class platform support.
Most workarounds use rAF as a mechanism to schedulue non-rendering work, this is problematic:
using rAF is high overhead due to cost of rendering machinery
guessing the idle budget without knowledge of browser internals is prone to cause jank. rAF should not be used for work that is not tied to frame rendering.
tieing to rAF can slow down the more important posted work as it is now competing with expensive rendering. Examples: when user zooms on Google Map, it is more important to quickly fetch Maps tiles than to render.
Known workarounds for "normal" priority scheduling:

* postmessage after each rAF (used by ReactScheduler):
* messagechannel workaround (google3 nexttick used by Maps etc): use a private message channel to postMessage empty messages; also tacked on after rAF. A bug currently prevents yielding.
* settimeout 0: doesn’t work well, clamped to 1ms (in Chromium) and to 4ms after N recursions.
* “await yield” pattern in JS: causes a microtask to be queued

Why not just use rIC? rIC is suited to idle time work, not normal priority work AFTER yielding to browser (for important work). By design, rIC has the risk of starvation and getting postponed indefinitely.

### 3. Support task cancellation and dynamically updating task priority
The priority of a posted task is not static and can change after posting. For instance work that was initially post as opportunistic prefetching, can become urgent if the current user interaction needs it.
Eg. React Scheduler uses expiration time instead of priority, so the times can dynamically update, and expired tasks are the highest priority.
NOTE: The lower level API needs to provide primitive for task cancellation. The higher level API should support invoking cancellation and dynamically updating priority.

### 4. Able to prioritize network fetches and timing of responses
Processing of network responses (parsing and execution) happens async and can occur at inopportune times relative to other ongoing work which could be more important. Certain responses are time sensitive (eg. when needed to respond to user interaction) while others could be lower priority (eg. optimistic prefetching).

### 5. [MAYBE?] Able to classify priority for input (handlers)
Similar to #4 above, but for input.
certain input is low priority (relative to current work in the app)
certain input is urgent and needs to be processed immediately without synchronizing to rendering (waiting until rAF) TODO: Add examples.

### 6. Able to target lower or different frame rate
Apps do not have access to easily learn the browser’s current target frame rate, and have to infer this withbook-keeping and guessing. Furthermore, apps are not easily able to target a different frame rate, or ask the browser to target different frame rate; default targeting 60fps can often result in starving of other necessary work. Use-cases:

* Eg. Maps is building a throttling scheduler (non-trivial effort) for the purpose of targeting a lower frame rate during certain cases like zooming, when a lot of tiles need to be loaded, and rendering work can easily starve the loading work.
* Eg. The React scheduler defaults to a target of 30fps with their own book-keeping, and have built detection (by timing successive scheduling of frames) for increasing to a higher target FPS.
* Eg. during page (or SPA) navigation, it is often more important to fetch and prepare the critical content of the page, than rendering.
Some of the above could be addressed with JS library except for changing browser's target frame rate, as well as accurately knowing what the current target rate is.
