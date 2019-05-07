### II. Built-in API
The run-loop could be built into the browser and integrated closely with the browser’s event-loop. This would automatically move [#4](https://github.com/spanicker/main-thread-scheduling/blob/master/README.md#4-run-loop) into the browser and [#3](https://github.com/spanicker/main-thread-scheduling/blob/master/README.md#3-api-for-posting-tasks) becomes the platform exposed API. The API sketch follows.

We propose adding default task queues with three semantic priorities, i.e. enum TaskQueuePriority, can be one of these:

* Immediate
* Render-blocking
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

myQueue = TaskQueue.default("render-blocking") 
```
returns the global task queue with priority “render-blocking”, for posting to main thread.
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

- DOM read-write phase: enabling tasks to target read vs write phases
- API for frame rate throttling: 30 vs. 60fps
- handling 3P and non-cooperating script (directly embedded) in the page 
- lowering priority of event handlers (similar to “passive”)

