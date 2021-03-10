API {#sec-api}
=====================

**TODO**(shaseley): Add an intro sentence here.

Scheduling Tasks {#sec-api-scheduling-tasks}
---------------------

<xmp class='idl'>
  dictionary SchedulerPostTaskOptions {
      (AbortSignal or TaskSignal)? signal = null;
      TaskPriority? priority = null;
      long delay = 0;
  };

  callback SchedulerPostTaskCallback = any ();

  [Exposed=(Window, Worker)] interface Scheduler {
    Promise<any> postTask(SchedulerPostTaskCallback callback, optional SchedulerPostTaskOptions options = {});
  };
</xmp>

Issue: Is that the right way to define signal?

Controlling Tasks {#sec-api-controlling-tasks}
---------------------

### TaskController ### {#sec-api-task-controller}

<pre class='idl'>
  [Exposed=(Window,Worker)] interface TaskController : AbortController {
    constructor(optional TaskPriority priority = "user-visible");

    [SameObject] readonly attribute AbortSignal signal;

    undefined setPriority(TaskPriority priority);
  };
</pre>

Issue: Note that this is different from the current implemenation (signal
property), but I have a patch for this that works **if** this is what we want
to do here.

### TaskSignal ### {#sec-api-task-signal}

<pre class='idl'>
  [Exposed=(Window, Worker)] interface TaskSignal : AbortSignal {
    readonly attribute TaskPriority priority;
    attribute EventHandler onprioritychange;
  };
</pre>

Usage Examples {#sec-usage-examples}
---------------------

**TODO**(shaseley): Fill this in.
