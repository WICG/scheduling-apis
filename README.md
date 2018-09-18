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
The specific schedulers we looked at are: Google Maps Scheduler and React Scheduler. These case studies demonstrate that schedulers can be (and have been) built as JS libraries, and also point to the platform gaps that they suffer from.

### High level goals
We want to explore two avenues:
### a. JS library
develop a freely available “standardized” (potential LAPI) scheduling library, written in JS.
### b. Platform primitives
develop primitives to fill platform gaps so that JS schedulers can be successful and so that it is easier to serve the goal of “improved responsiveness guarantees”.

### Platform Gaps
### The yielding & coordination issue
JS should schedule work while yielding to the browser for rendering and input.
JS schedulers need to be able to schedule chunks of work, and importantly, yield to the browser -- so that the frame is not overrun and so the browser is able to do its rendering work, and other important work like handling input.
Currently JS schedulers have to guess when the browser needs to do pertinent work, when it will schedule posted work, and how much browser-side work is remaining.
While rAF is suited for render related work that needs to happen per frame, there is lot of other work that is lower priority and should get out of the way of input and render. OTOH there is work that is higher priority than rendering at a given time eg. fetching critical components during loading.

Also, the browser doesn’t have insight into JS work and knowledge of priority that could help it to more effectively schedule this, as well as schedule it appropriately relative to browser’s own work and other async app work (such as processing network responses).


