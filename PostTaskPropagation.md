# Propagating and Inheriting `postTask` Priority

A shared `TaskSignal` represents a relationship between two tasks, and two tasks
that share a signal can be reprioritized together. A frequent request we see
from web developers pertaining to scheduling is the desire to inherit or
propagate the currently running task's priority. Consider the following example:

```javascript
function asyncSubtask() {}

function task1() {
  // ... do task1 work ...
  scheduler.postTask(asyncSubtask, { priority: ?? });
  // ... do more work ...
}

scheduler.postTask(task1, { priority: 'background' });
```

When `task1` runs, it might be the case that either or both of the following hold:
1. asyncSubtask should be have the same priority as task1.
2. asyncSubtask should be canceled if task1 is aborted.

`TaskSignals` can solve both (1) and (2), but in the MVP API they need to be
*explicitly passed* to any function that might need them, which can be onerous.

Any function that needs the current signal would need to be modified to take an
argument. The example can be rewritten as follows:

```javascript
function asyncSubtask() {}

function task1(signal) {
  // ... do task1 work ...
  scheduler.postTask(asyncSubtask, { signal });
  // ... do more work ...
}

const controller = new TaskController('background');
scheduler.postTask(task1, { signal }, signal);
```

Rather than forcing developers to explicitly pass signals everywhere, we are
proposing to expose the current `TaskSignal` so it can be inherited across async
boundaries. This would work for both task callbacks (e.g. `postTask`) and for
Promises. For example:

```javascript
function asyncSubtask() {}

function task1() {
  // ... do task1 work ...

  // Inherit the current signal.
  let res = scheduler.postTask(asyncSubtask, { scheduler.currentTaskSignal});
  res.then(() => {
    // The currentTaskSignal is retained across this async boundary as well,
    // i.e. when the microtask runs.
    scheduler.postTask(asyncSubtask, { scheduler.currentTaskSignal});
  });
  // ... do more work ...
}

const controller = new TaskController('background');
scheduler.postTask(task1, { signal });
```

If the priority doesn't need to be changed, i.e. a `TaskController` wasn't
created, a special `scheduler.currentTaskSignal` can be created so that
propagation can still occur:

```javascript
function asyncSubtask() {}

function task1() {
  // logs 'background'.
  console.log(scheduler.currentTaskSignal.priority;
}

scheduler.postTask(task1, { priority: 'background' });
```

It's possible to add further sugar and make priority inheritance even cleaner:

```javascript
function asyncSubtask() {}

function task1() {
  // Inherit the current signal.
  let res = scheduler.postTask(asyncSubtask, { priority: 'inherit' });
}

const controller = new TaskController('background');
scheduler.postTask(task1, { signal });
```
