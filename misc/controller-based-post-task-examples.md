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
// New. postTask returns a Promise.
scheduler.postTask(foo, {priority: 'high'}).then(() => console.log('done'));

// Old.
scheduler.postTask(foo, {priority: 'high'}).result.then(() => console.log('done'));
```

**E.g. Scheduling and controlling a task.**
```javascript
// New.

// Create a controller that is used for both cancellation and for changing priority.
// The priority is derived from the signal (see note below on signals vs. priority option).
const controller = new TaskController({priority: 'low'});
scheduler.postTask(foo, {signals: controller.signals});

// ... do work ...

// Update the task's priority.
controller.setPriority('high');

// Cancel the task.
controller.abort();

// Old.
const task = scheduler.postTask(foo, {priority: 'low'});

// ... do work ...

// Update the task's priority.
scheduler.getTaskQueue('high').take(task);
// Note: we're exploring an API simplification that would change this to
// task.setPriority('high');

// Cancel the task.
task.cancel();
```

**E.g. Share an AbortSignal between postTask and fetch.**
```javascript
// New.
const controller = new TaskController({priority: 'low'});
const res = scheduler.postTask(foo, {signals: controller.signals});
fetch(url, {signal: controller.signals['abort']});

// Cancel the task and fetch.
controller.abort();

// Old.

const controller = new AbortController();
const task = scheduler.postTask(foo, {priority: 'low'});
// The fetch and other async work would need to be cancelled separately.
task.result.catch(() => controller.abort());
fetch(url, {signal: controller.signal});

// Cancel the task and fetch.
task.cancel();

```

**E.g. Controlling related tasks.**
Rather than support explicit task queues, tasks that need to be controlled
together share a controller.
```javascript
function fancyLog(msg) { ... }

const loggingTaskContoller = new TaskController({priority: 'low'});
scheduler.postTask(fancyLog, {signals: loggingTaskContoller.signals}, 'foo');
scheduler.postTask(fancyLog, {signals: loggingTaskContoller.signals}, 'bar');
scheduler.postTask(fancyLog, {signals: loggingTaskContoller.signals}, 'baz');

// Change the priority of all of the tasks.
loggingTaskContoller.setPriority('high');

// Cancel all pending logging tasks.
// Note: without changing Abort[Controller|Signal], loggingTaskContoller cannot
// be used to post further tasks, which is semantically different than clearing
// a task queue.
loggingTaskContoller.abort();

// Old, using native TaskQueues.

const loggingTaskQueue = new TaskQueue({priority: 'low'});
scheduler.postTask(fancyLog, {}, 'foo');
scheduler.postTask(fancyLog, {}, 'bar');
scheduler.postTask(fancyLog, {}, 'baz');

// Change the priority of all of the tasks.
loggingTaskQueue.setPriority('high');

// Cancel all pending logging tasks.
loggingTaskQueue.clear();
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
