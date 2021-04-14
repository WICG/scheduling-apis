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
boundaries. The current `TaskSignal` is propagated through `postTask` and
through any Promise chains that begin inside of a `postTask` task, but will not
propagate through other callbacks (e.g., asynchronous event handlers,
`setTimeout`, etc.). When there is no current `TaskSignal`,
`scheduler.currentTaskSignal` will return a default `TaskSignal`, representing
a default priority with no way to cancel the task. 
For example:

```javascript
function asyncSubtask() {}

function task1() {
  // ... do task1 work ...

  // Inherit the current signal.
  let res = scheduler.postTask(asyncSubtask, {signal: scheduler.currentTaskSignal});
  res.then(() => {
    // The currentTaskSignal is retained across this async boundary as well,
    // i.e. when the microtask runs.
    scheduler.postTask(asyncSubtask, {signal: scheduler.currentTaskSignal});
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
  console.log(scheduler.currentTaskSignal.priority);
}

scheduler.postTask(task1, { priority: 'background' });
```

It is also possible to mix and match priorities and `TaskSignals`.
In this example, if `controller.abort()` is called before `asyncSubtask()`
runs, it will still be cancelled, even though it is running at a different
priority than `controller.signal.priority`. This is accomplished by creating an
implicit `TaskSignal` with no associated `TaskController` instead of inheriting
`controller.signal` in its entirety. This implicit `TaskSignal`
[follows](https://dom.spec.whatwg.org/#abortsignal-follow) the
`controller.signal` for abort, but has its own priority that does not change
when `controller.signal.priority` changes.

```javascript
function asyncSubtask() {
  // logs 'background'.
  console.log(scheduler.currentTaskSignal.priority);
}

function task1() {
  // ... do task1 work ...
  scheduler.postTask(asyncSubtask,
                     {signal: scheduler.currentTaskSignal, priority: 'background'});
  // ... do more work ...
}

const controller = new TaskController('user-blocking');
scheduler.postTask(task1, { controller.signal });
```

