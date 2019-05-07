# Main-thread Scheduling API
For an overview, see: [Slides presented at TPAC 2018](https://docs.google.com/presentation/d/12lkTrTwGedKSFqOFhQTsEdcLI3ydRiAdom_9uQ2FgsM/edit?usp=sharing)

Also this [talk from Chrome Dev Summit](https://youtu.be/mDdgfyRB5kg) covers the problem and larger direction.

## Motivation: Main thread contention
Consider a "search-as-you-type" application:

This app needs to be responsive to user input i.e. user typing in the
search-box. At the same time any animations on the page must be rendered
smoothly, also the work for fetching and preparing search results and updating
the page must also progress quickly. 

This is a lot of different deadlines to meet for the app developer. It is easy
for any long running script work to hold up the main thread and cause
responsiveness issues for typing, rendering animations or updating search
results.

This problem can be tackled by systematically chunking and scheduling main
thread work i.e. prioritizing and executing work async at an appropriate time
relative to current situation of user and browser. A Main Thread Scheduler
provides improved guarantees of responsiveness.

## API Shape
We intend to pursue a two-pronged approach:

* I. Ship primitives to enable Javascript / userland schedulers to succeed:
above components of scheduling can be built in javascript. However there are
gaps that need to be filled for
[4a](UserspaceSchedulers.md#4a-knowledge)
and
[4b](UserspaceSchedulers.md#4b-coordination).
These can be tackled as a set of APIs to plug these gaps.
* II. Show proof-of-concept for a native platform scheduler, that is directly
  integrated into the browser's event-loop.

More details below, for each approach. 


