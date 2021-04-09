
### API Option A: run-loop is built into the browser
The run-loop could be built into the browser and integrated closely with the browser’s event-loop. This would automatically move #4 into the browser and #3 becomes the platform exposed API. The API sketch follows.

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
### API Option B: run-loop is built in a JS library
The run-loop could be built into a JS scheduling library. This would mean that #3 is defined in JS and not a platform primitive. 
The platform exposed API is essentially focused on exposing what's needed for the run-loop:

* 4a. can be addressed with shouldYield proposal.
* 4b. is really difficult to reason about and expose to JS.

The platform exposed API would also fill in the gaps for how to post work at specific priorities:

* Posting work at default priority: ```var handle = window.requestDefaultCallback(callback[, options]) ```

TODO: API Sketch / sample code for JS scheduler. 
Eg. React Scheduler, Maps Scheduler <links>

### Pros & Cons:API Option A vs B
#### API Option A: Cons
* Really difficult to reason about and expose all necessary signals in [#4](https://github.com/spanicker/main-thread-scheduling#4-run-loop), especially [4b.](https://github.com/spanicker/main-thread-scheduling#b-run-loop-requires-effective-coordination-with-other-work-on-the-main-thread) 
* Not possible to expose priorities 

A key thing here is understanding what subset of [4b.](https://github.com/spanicker/main-thread-scheduling#b-run-loop-requires-effective-coordination-with-other-work-on-the-main-thread) is necessary for effective scheduling and what it might take to support that.

#### API Option B: Cons
* potentially tougher interop story?
