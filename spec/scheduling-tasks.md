# Scheduling Tasks # {#sec-scheduling-tasks}

## Task Priorities ## {#sec-task-priorities}

This spec formalizes three priorities to support scheduling tasks:

<pre class='idl'>
  enum TaskPriority {
    "user-blocking",
    "user-visible",
    "background"
  };
</pre>

<dfn enum-value for=TaskPriority>user-blocking</dfn> is the highest priority, and is meant to be
used for tasks that are blocking the user's ability to interact with the page, such as rendering the
core experience or responding to user input.

<dfn enum-value for=TaskPriority>user-visible</dfn> is the second highest priority, and is meant to
be used for tasks that are observable to the user but not necessarily blocking user actions, such as
updating secondary parts of the page. This is the default priority.

<dfn enum-value for=TaskPriority>background</dfn> is the lowest priority, and is meant to be used
for tasks that are not time-critical, such as background log processing or initializing certain
third party libraries.

Note: Tasks scheduled through a given {{Scheduler}} run in *strict priority order*, meaning the
scheduler will always run "{{TaskPriority/user-blocking}}" tasks before
"{{TaskPriority/user-visible}}" tasks, which in turn always run before "{{TaskPriority/background}}"
tasks.

<div algorithm>
  {{TaskPriority}} |p1| is <dfn for="TaskPriority">less than</dfn>
  {{TaskPriority}} |p2| if |p1| is less than |p2| in the
  following total ordering:
  "{{TaskPriority/background}}" < "{{TaskPriority/user-visible}}" < "{{TaskPriority/user-blocking}}"
</div>


## The `Scheduler` Interface ## {#sec-scheduler}

<xmp class='idl'>
  dictionary SchedulerPostTaskOptions {
    AbortSignal signal;
    TaskPriority priority;
    [EnforceRange] unsigned long long delay = 0;
  };

  callback SchedulerPostTaskCallback = any ();

  [Exposed=(Window, Worker)]
  interface Scheduler {
    Promise<any> postTask(SchedulerPostTaskCallback callback,
                          optional SchedulerPostTaskOptions options = {});
  };
</xmp>

Note: The {{SchedulerPostTaskOptions/signal}} option can be either an {{AbortSignal}} or a
{{TaskSignal}}, but is defined as an {{AbortSignal}} since it is a superclass of {{TaskSignal}}. For
cases where the priority might change, a {{TaskSignal}} is needed. But for cases where only
cancellation is needed, an {{AbortSignal}} would suffice, potentially making it easier to integrate
the API into existing code that uses {{AbortSignal|AbortSignals}}.

<dl class="domintro non-normative">
  <dt><code>result = scheduler . {{Scheduler/postTask()|postTask}}( |callback|, |options| )</code></dt>
  <dd>
    <p>Returns a promise that is fulfilled with the return value of |callback|, or rejected with the
    {{AbortSignal}}'s [=AbortSignal/abort reason=] if the task is aborted. If |callback| throws an
    error during execution, the promise returned by {{Scheduler/postTask()}} will be rejected with
    that error.

    <p>The task's {{TaskPriority|priority}} is determined by the combination of |option|'s
    {{SchedulerPostTaskOptions/priority}} and {{SchedulerPostTaskOptions/signal}}:

    <ul>
      <li><p>If |option|'s {{SchedulerPostTaskOptions/priority}} is specified, then that
      {{TaskPriority}} will be used to schedule the task, and the task's priority is immutable.

      <li><p>Otherwise, if |option|'s {{SchedulerPostTaskOptions/signal}} is specified and is a
      {{TaskSignal}} object, then the task's priority is determined by |option|'s
      {{SchedulerPostTaskOptions/signal}}'s [=TaskSignal/priority=]. In this case the task's
      priority is *dynamic*, and can be changed by calling
      {{TaskController/setPriority()|controller.setPriority()}} for the associated
      {{TaskController}}.

      <li><p>Otherwise, the task's priority defaults to "{{TaskPriority/user-visible}}".
    </ul>

    <p>If |option|'s {{SchedulerPostTaskOptions/signal}} is specified, then the
    {{SchedulerPostTaskOptions/signal}} is used by the {{Scheduler}} to determine if the task is
    aborted.

    <p>If |option|'s {{SchedulerPostTaskOptions/delay}} is specified and greater than 0, then the
    execution of the task will be delayed for at least {{SchedulerPostTaskOptions/delay}}
    milliseconds.
  </dd>
</dl>


A {{Scheduler}} object has an associated <dfn for="Scheduler">static priority task queue map</dfn>,
which is a [=map=] from {{TaskPriority}} to [=scheduler task queue=]. This map is initialized to a
new empty [=map=].

A {{Scheduler}} object has an associated <dfn for="Scheduler">dynamic priority task queue map</dfn>,
which is a [=map=] from {{TaskSignal}} to [=scheduler task queue=]. This map is initialized to a new
empty [=map=].

Note: We implement *dynamic prioritization* by enqueuing tasks associated with a specific
{{TaskSignal}} into the same [=scheduler task queue=], and changing that queue's priority in
response to `prioritychange` events. The [=Scheduler/dynamic priority task queue map=] holds the
[=scheduler task queues=] whose priorities can change, and the map key is the {{TaskSignal}} which
all tasks in the queue are associated with.
<br/><br/>
The values of the [=Scheduler/static priority task queue map=] are [=scheduler task queues=] whose
priorities do not change. Tasks with *static priorities* &mdash; those that were scheduled with an
explicit {{SchedulerPostTaskOptions/priority}} option or a {{SchedulerPostTaskOptions/signal}}
option that is null or is an {{AbortSignal}} &mdash; are placed in these queues, based on
{{TaskPriority}}, which is the key for the map.
<br/><br/>
An alternative, and logicially equivalent implementation, would be to maintain a single
per-{{TaskPriority}} [=scheduler task queue=], and move tasks between [=scheduler task queues=] in
response to a {{TaskSignal}}'s [=TaskSignal/priority=] changing, inserting based on [=scheduler
task/enqueue order=]. This approach would simplify [=selecting the task queue of the next scheduler
task=], but make priority changes more complex.


A {{Scheduler}} object has a numeric <dfn for="Scheduler">next enqueue order</dfn> which is
initialized to 1.

Note: The [=Scheduler/next enqueue order=] is a strictly increasing number that is used to determine
task execution order across [=scheduler task queues=] of the same {{TaskPriority}} within the same
{{Scheduler}}. A logically equivalent alternative would be to place the [=Scheduler/next enqueue
order=] on the [=event loop=], since the only requirements are that the number be strictly
increasing and not be repeated within a {{Scheduler}}.

Issue: Would it be simpler to just use a timestamp here?

The <dfn method for=Scheduler title="postTask(callback, options)">postTask(|callback|, |options|)</dfn>
method steps are to return the result of [=scheduling a postTask task=] for [=this=] given
|callback| and |options|.


## Definitions ## {#sec-scheduling-tasks-definitions}

A <dfn>scheduler task</dfn> is a [=/task=] with an additional numeric
<dfn for="scheduler task">enqueue order</dfn> [=struct/item=], initially set to 0.

The following [=task sources=] are defined as <dfn>scheduler task sources</dfn>,
and must only be used for [=scheduler tasks=].

: The <dfn>posted task task source</dfn>
:: This [=task source=] is used for tasks scheduled through {{Scheduler/postTask()}}.

<br/>

A <dfn>scheduler task queue</dfn> is a [=struct=] with the following [=struct/items=]:

: <dfn for="scheduler task queue">priority</dfn>
:: A {{TaskPriority}}.
: <dfn for="scheduler task queue">tasks</dfn>
:: A [=set=] of [=scheduler tasks=].
: <dfn for="scheduler task queue">removal steps</dfn>
:: An algorithm.

<br/>

A <dfn>task handle</dfn> is a [=struct=] with the following [=struct/items=]:

: <dfn for="task handle">task</dfn>
:: A [=scheduler task=] or null.
: <dfn for="task handle">queue</dfn>
:: A [=scheduler task queue=] or null.
: <dfn for="task handle">abort steps</dfn>
:: An algorithm.
: <dfn for="task handle">task complete steps</dfn>
:: An algorithm.

## Processing Model ## {#sec-scheduling-tasks-processing-model}

<div algorithm>
  A [=scheduler task=] |t1| is <dfn for="scheduler task">older than</dfn> [=scheduler task=] |t2| if
  |t1|'s [=scheduler task/enqueue order=] less than |t2|'s [=scheduler task/enqueue order=].
</div>

<div algorithm>
  To <dfn>create a scheduler task queue</dfn> with {{TaskPriority}} |priority| and |removalSteps|:

  1. Let |queue| be a new [=scheduler task queue=].
  1. Set |queue|'s [=scheduler task queue/priority=] to |priority|.
  1. Set |queue|'s [=scheduler task queue/tasks=] to a new empty [=set=].
  1. Set |queue|'s [=scheduler task queue/removal steps=] to |removalSteps|.
  1. Return |queue|.
</div>

<div algorithm>
  To <dfn>create a task handle</dfn> given a promise |result| and an {{AbortSignal}} or null
  |signal|:

  1. Let |handle| be a new [=task handle=].
  1. Set |handle|'s [=task handle/task=] to null.
  1. Set |handle|'s [=task handle/queue=] to null.
  1. Set |handle|'s [=task handle/abort steps=] to the following steps:
    1. [=Reject=] |result| with |signal|'s [=AbortSignal/abort reason=].
    1. If |task| is not null, then
      1. [=scheduler task queue/Remove=] |task| from |queue|.
      1. If |queue| is [=scheduler task queue/empty=], then run |queue|'s [=scheduler task
         queue/removal steps=].
  1. Set |handle|'s [=task handle/task complete steps=] to the following steps:
    1. If |signal| is not null, then [=AbortSignal/remove=] |handle|'s [=task handle/abort steps=]
       from |signal|.
    1. If |queue| is [=scheduler task queue/empty=], then run |queue|'s [=scheduler task
       queue/removal steps=].
  1. Return |handle|.
</div>

<div algorithm>
  A [=scheduler task queue=] |queue|'s <dfn for="scheduler task queue">first runnable task</dfn> is
  the first [=scheduler task=] in |queue|'s [=scheduler task queue/tasks=] that is
  [=task/runnable=].
</div>

### Queueing and Removing Scheduler Tasks ### {#sec-queuing-scheduler-tasks}

<div algorithm>
  To <dfn>queue a scheduler task</dfn> on a [=scheduler task queue=] |queue|, which performs a
  series of steps |steps|, given a numeric |enqueue order|, a [=task source=] |source|, and a
  [=document=] |document|:

  1. Let |task| be a new [=scheduler task=].
  1. Set |task|'s [=scheduler task/enqueue order=] to |enqueue order|.
  1. Set |task|'s <a attribute for="task">steps</a> to |steps|.
  1. Set |task|'s <a attribute for="task">source</a> to |source|.
  1. Set |task|'s <a attribute for="task">document</a> to |document|.
  1. Set |task|'s <a attribute for="task">script evaluation environment settings object set</a> to a
     new empty [=set=].
  1. [=set/Append=] |task| to |queue|'s [=scheduler task queue/tasks=].
  1. Return |task|.

  Issue: We should consider refactoring the HTML spec to add a constructor for [=/task=]. One
  problem is we need the new task to be a [=scheduler task=] rather than a [=/task=].
</div>

<div algorithm>
  To <dfn for="scheduler task queue">remove</dfn> a [=scheduler task=] |task| from [=scheduler task
  queue=] |queue|, [=set/remove=] |task| from |queue|'s [=scheduler task queue/tasks=].
</div>

<div algorithm>
  A [=scheduler task queue=] |queue| is <dfn for="scheduler task queue">empty</dfn> if |queue|'s
  [=scheduler task queue/tasks=] is [=list/empty=].
</div>


### Scheduling Tasks ### {#sec-scheduler-alg-scheduling-tasks}

<div algorithm>
  To <dfn>schedule a postTask task</dfn> for {{Scheduler}} |scheduler| given a
  {{SchedulerPostTaskCallback}} |callback| and {{SchedulerPostTaskOptions}} |options|:

  1. Let |result| be [=a new promise=].
  1. Let |signal| be |options|["{{SchedulerPostTaskOptions/signal}}"] if
     |options|["{{SchedulerPostTaskOptions/signal}}"] [=map/exists=], or otherwise null.
  1. If |signal| is not null and it is [=AbortSignal/aborted=], then [=reject=] |result| with
     |signal|'s [=AbortSignal/abort reason=] and return |result|.
  1. Let |handle| be the result of [=creating a task handle=] given |result| and |signal|.
  1. If |signal| is not null, then [=AbortSignal/add=] |handle|'s [=task handle/abort steps=] to
     |signal|.
  1. Let |priority| be |options|["{{SchedulerPostTaskOptions/priority}}"] if
     |options|["{{SchedulerPostTaskOptions/priority}}"] [=map/exists=], or otherwise null.
  1. Let |enqueueSteps| be the following steps:
    1. Set |handle|'s [=task handle/queue=] to the result of [=selecting the scheduler task queue=]
       for |scheduler| given |signal| and |priority|.
    1. [=Schedule a task to invoke a callback=] for |scheduler| given |callback|, |result|, and
       |handle|.
  1. Let |delay| be |options|["{{SchedulerPostTaskOptions/delay}}"].
  1. If |delay| is greater than 0, then [=run steps after a timeout=] given |scheduler|'s [=relevant
     global object=], "`scheduler-postTask`", |delay|, and the following steps:
    1. If |signal| is null or |signal| is not [=AbortSignal/aborted=], then run |enqueueSteps|.
  1. Otherwise, run |enqueueSteps|.
  1. Return |result|.
</div>

Issue: [=Run steps after a timeout=] doesn't necessarily account for suspension; see
[whatwg/html#5925](https://github.com/whatwg/html/issues/5925).

<div algorithm>
  To <dfn>select the scheduler task queue</dfn> for a {{Scheduler}} |scheduler| given an
  {{AbortSignal}} or null |signal|, and a {{TaskPriority}} or null |priority|:

  1. If |priority| is null, |signal| is not null and [=implements=] the {{TaskSignal}} interface,
     and |signal| [=TaskSignal/has fixed priority=], then set |priority| to |signal|'s
     [=TaskSignal/priority=].
  1. If |priority| is null and |signal| is not null and [=implements=] the {{TaskSignal}} interface,
     then
    1. If |scheduler|'s [=Scheduler/dynamic priority task queue map=] does not [=map/contain=]
       |signal|, then
      1. Let |queue| be the result of [=creating a scheduler task queue=] given |signal|'s
         [=TaskSignal/priority=] and the following steps:
          1. [=map/Remove=] [=Scheduler/dynamic priority task queue map=][|signal|].
      1. Set [=Scheduler/dynamic priority task queue map=][|signal|] to |queue|.
      1. [=TaskSignal/Add a priority change algorithm=] to |signal| that runs the following steps:
        1. Set |queue|'s [=scheduler task queue/priority=] to |signal|'s {{TaskSignal/priority}}.
    1. Return [=Scheduler/dynamic priority task queue map=][|signal|].
  1. Otherwise |priority| is used to determine the task queue:
    1. If |priority| is null, set |priority| to "{{TaskPriority/user-visible}}".
    1. If |scheduler|'s [=Scheduler/static priority task queue map=] does not [=map/contain=]
       |priority|, then
      1. Let |queue| be the result of [=creating a scheduler task queue=] given |priority| and the
         following steps:
        1. [=map/Remove=] [=Scheduler/static priority task queue map=][|priority|].
      1. Set [=Scheduler/static priority task queue map=][|priority|] to |queue|.
    1. Return [=Scheduler/static priority task queue map=][|priority|].
</div>

<div algorithm>
  To <dfn>schedule a task to invoke a callback</dfn> for {{Scheduler}} |scheduler| given a
  {{SchedulerPostTaskCallback}} |callback|, a promise |result|, and a [=task handle=] |handle|:

  1. Let |global| be the [=relevant global object=] for |scheduler|.
  1. Let |document| be |global|'s <a attribute for="Window">associated `Document`</a> if |global| is
     a {{Window}} object; otherwise null.
  1. Let |enqueue order| be |scheduler|'s [=Scheduler/next enqueue order=].
  1. Increment |scheduler|'s [=Scheduler/next enqueue order=] by 1.
  1. Set |handle|'s [=task handle/task=] to the result of [=queuing a scheduler task=] on |handle|'s
     [=task handle/queue=] given |enqueue order|, the [=posted task task source=], and |document|,
     and that performs the following steps:
    1. Let |callback result| be the result of [=invoking=] |callback|. If that threw an exception,
       then [=reject=] |result| with that, otherwise resolve |result| with |callback result|.
    1. Run |handle|'s [=task handle/task complete steps=].

  Issue: Because this algorithm can be called from [=in parallel=] steps, parts of this and other
  algorithms are racy. Specifically, the [=Scheduler/next enqueue order=] should be updated
  atomically, and accessing the [=scheduler task queues=] should occur atomically. The latter also
  affects the event loop task queues (see [this issue](https://github.com/whatwg/html/issues/6475)).
</div>

### Selecting the Next Task to Run ### {#sec-scheduler-alg-select-next-task}

<div algorithm>
  A {{Scheduler}} |scheduler| <dfn lt="has a runnable task|have a runnable task">has a runnable
  task</dfn> if the result of [=getting the runnable task queues=] for |scheduler| is
  non-[=list/empty=].
</div>

<div algorithm>
  To <dfn>get the runnable task queues</dfn> for a {{Scheduler}} |scheduler|:

  1. Let |queues| be the result of [=map/get the values|getting the values=] of |scheduler|'s
     [=Scheduler/static priority task queue map=].
  1. [=list/Extend=] |queues| with the result of [=map/get the values|getting the values=] of
     |scheduler|'s [=Scheduler/dynamic priority task queue map=].
  1. [=list/Remove=] from |queues| any |queue| such that |queue|'s [=scheduler task queue/tasks=] do
     not contain a [=task/runnable=] [=scheduler task=].
  1. Return |queues|.
</div>

<div algorithm>
  The result of <dfn>selecting the task queue of the next scheduler task</dfn> for {{Scheduler}}
  |scheduler| is a [=set=] of [=scheduler tasks=] as defined by the following steps:

  1. Let |queues| be the result of [=getting the runnable task queues=] for |scheduler|.
  1. If |queues| is [=list/empty=] return null.
  1. [=set/Remove=] from |queues| any |queue| such that |queue|'s [=scheduler task queue/priority=]
     is [=TaskPriority/less than=] any other [=set/item=] of |queues|.
  1. Let |queue| be the [=scheduler task queue=] in |queues| whose [=scheduler task queue/first
     runnable task=] is the [=scheduler task/older than|oldest=].
     <br/><span class=note>Two tasks cannot have the same age since [=scheduler task/enqueue order=]
     is unique.</span>
  1. Return |queue|'s [=scheduler task queue/tasks=].

  Note: The next task to run is the oldest, highest priority [=task/runnable=] [=scheduler task=].
</div>

## Examples ## {#sec-scheduling-tasks-examples}

**TODO**(shaseley): Add examples.
