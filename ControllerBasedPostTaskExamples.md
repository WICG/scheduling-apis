# Controller-Based postTask API

The purpose of this is to explore what a controller-based postTask API might
look like. This API shape is consistent with how we control exisiting async
APIs (namely aborting) and how we might control them in the future (e.g.
priority).

## Examples

**E.g. Scheduling a task.**
For convenience, providing an explicit priority is allowed when signals are not
passed.

```javascript
// postTask returns a Promise.
scheduler.postTask(foo, {priority: 'high'}).then(() => console.log('done'));
```

**E.g. Scheduling and controlling a task.**
```javascript
// Create a controller that is used for both cancellation and for changing priority.
// The priority is derived from the signal (see note below on signals vs. priority option).
const controller = new TaskController({priority: 'low'});
scheduler.postTask(foo, { signals: controller.signals });

// ... do work ...

// Update the task's priority.
controller.setPriority('high');

// Cancel the task.
controller.abort();
```

**E.g. Share an AbortSignal between postTask and fetch.**
```javascript
const controller = new TaskController({priority: 'low'});
const res = scheduler.postTask(foo, { signals: controller.signals });
fetch(url, { signal: controller.signals['abort'] });

// Cancel the task and fetch.
controller.abort();
```

**E.g. Controlling related tasks.**
Rather than support explicit task queues, tasks that need to be controlled
together share a controller.
```javascript
function fancyLog(msg) { ... }

const loggingTaskContoller = new TaskController({priority: 'low'});
scheduler.postTask(fancyLog, { signals: loggingTaskContoller.signals }, 'foo');
scheduler.postTask(fancyLog, { signals: loggingTaskContoller.signals }, 'bar');
scheduler.postTask(fancyLog, { signals: loggingTaskContoller.signals }, 'baz');

// Change the priority of all of the tasks.
loggingTaskContoller.setPriority('high');

// Cancel all pending logging tasks.
// Note: without changing Abort[Controller|Signal], loggingTaskContoller cannot
// be used to post further tasks, which is semantically different than clearing
// a task queue.
loggingTaskContoller.abort();
```

## Higher-level Abstractions

The higher-level abstractions we originally proposed can be built in userspace.
For example, consider the following for userspace task queues, which abstracts
some of the more low-level controller details:

```javascript
class TaskQueue {
  constructor(priority) {
    this.priority = priority;
    this.controller = new TaskController({priority});
  }

  enqueue(task) {
    // Assuming postTask is also FIFO, no need to track the tasks for simple
    // FIFO task queues.
    return scheduler.postTask(task, { signals: controller.signals };
  }

  setPriority(priority) {
    this.priority = priority;
    controller.setPriority(priority);
  }

  clear() {
    controller.abort();
    // Reset the controller since it is no longer usable.
    this.controller = new TaskController({priority: this.priority});
  }
}
```

## Notes

1. The examples use "signals" instead of "signal" because we need multiple
   signals: one for abort, one for priority, and likely one for enabled.
   Supporting a TaskSignal that encompasses all of these seems antithetical to
   the signal style observer pattern, where a signal indicates a specific
   observable event. The strawman proposal here is that signals is map-like,
   mapping signal name to signal.

2. The shared AbortSignal example is clean because the TaskController is used
   to control the fetch and is created first. If one wanted to use an AbortSignal
   already associated with other async work, the TaskController would need to
   support optional signals in its constructor.

3. There is a tension between the "signals" and "priority" options in postTask().
   If specifying both, one needs to win&mdash;which should be the priority signal.

   We could remove the priority option, but then the simple postTask case would
   require a signal even if no control is required.

   We could also make the priority option take a string or signal, but requiring
   separate arguments for each signal becomes quite verbose and creates another
   potential footgun.

## See Also

* [TAG design principle on aborting](https://w3ctag.github.io/design-principles/#aborting)
