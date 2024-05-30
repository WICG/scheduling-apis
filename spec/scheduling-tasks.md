# Scheduling Tasks and Continuations # {#sec-scheduling-tasks-and-continuations}

## Task and Continuation Priorities ## {#sec-task-priorities}

This spec formalizes three priorities to support scheduling tasks:

<pre class='idl'>
  enum TaskPriority {
    "user-blocking",
    "user-visible",
    "background"
  };
</pre>

<dfn enum-value for=TaskPriority>user-blocking</dfn> is the highest priority, and it is meant for
tasks that should run as soon as possible, such that running them at a lower priority would degrade
user experience. This could be (chunked) work that is directly in response to user input, or
updating the in-viewport UI state, for example.

<dfn enum-value for=TaskPriority>user-visible</dfn> is the second highest priority, and it is meant
for tasks that will be visible to the user, but either not immediately or are not essential to user
experience. These tasks are either less important or less urgent than user-blocking tasks. This is
the default priority.

<dfn enum-value for=TaskPriority>background</dfn> is the lowest priority, and it is meant to be used
for tasks that are not time-critical, such as background log processing or initializing certain
third party libraries.

Continuation priorities mirror task priorities, with an additional option to inherit the current
priority:

<pre class='idl'>
  enum ContinuationPriority {
    "user-blocking",
    "user-visible",
    "background",
    "inherit"
  };
</pre>

Note: Tasks scheduled through a given {{Scheduler}} run in *strict priority order*, meaning the
scheduler will always run "{{TaskPriority/user-blocking}}" tasks before
"{{TaskPriority/user-visible}}" tasks, which in turn always run before "{{TaskPriority/background}}"
tasks. Continuation priorities are slotted in just above their {{TaskPriority}} counterparts, e.g.
a {{ContinuationPriority/user-visible}} continuation has a higher [=scheduler task queue/effective
priority=] than a {{TaskPriority/user-visible}} task.

## The `Scheduler` Interface ## {#sec-scheduler}

<xmp class='idl'>
  dictionary SchedulerPostTaskOptions {
    AbortSignal signal;
    TaskPriority priority;
    [EnforceRange] unsigned long long delay = 0;
  };

  enum SchedulerSignalInherit {
    "inherit"
  };

  dictionary SchedulerYieldOptions {
    (AbortSignal or SchedulerSignalInherit) signal;
    ContinuationPriority priority;
  };

  callback SchedulerPostTaskCallback = any ();

  [Exposed=(Window, Worker)]
  interface Scheduler {
    Promise<any> postTask(SchedulerPostTaskCallback callback,
                          optional SchedulerPostTaskOptions options = {});
    Promise<undefined> yield(optional SchedulerYieldOptions options = {});
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
    <p>Returns a promise that is fulfilled with the return value of |callback| or rejected with the
    {{AbortSignal}}'s [=AbortSignal/abort reason=], if the task is aborted. If |callback| throws an
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

  <dt><code>result = scheduler . {{Scheduler/yield()|yield}}( |options| )</code></dt>
  <dd>
    <p>Returns a promise that is fulfilled with <code>undefined</code> or rejected with the
    {{AbortSignal}}'s [=AbortSignal/abort reason=], if the continuation is aborted.

    <p>By default, the priority of the continuation and the signal used to abort it are inherited from
    the originating task, but they can optionally be specified in a similar manner as
    {{Scheduler/postTask()}} through the {{SchedulerYieldOptions/signal}} and
    {{SchedulerYieldOptions/priority}} |options|.

    <p>For determining the {{AbortSignal}} used to abort the continuation:
    <ul>
      <li>If neither the {{SchedulerYieldOptions/signal}} nor the {{SchedulerYieldOptions/priority}}
      |options| are specified, then |option|'s {{SchedulerYieldOptions/signal}} is defaulted to
      "{{SchedulerSignalInherit/inherit}}".

      <li><p>If |option|'s {{SchedulerYieldOptions/signal}} is "{{SchedulerSignalInherit/inherit}}"
      and the originating task was scheduled with via {{Scheduler/postTask()}} with an
      {{AbortSignal}}, then that signal is used to determine if the continuation is aborted.

      <li><p>Otherwise if |option|'s {{SchedulerYieldOptions/signal}} is specified, then that is
      used to determine if the continuation is aborted.
    </ul>

    <p>For determining the continuation's priority:
    <ul>
      <li>If neither the {{SchedulerYieldOptions/signal}} nor the {{SchedulerYieldOptions/priority}}
      |options| are specified, then |option|'s {{SchedulerYieldOptions/priority}} is defaulted to
      "{{SchedulerSignalInherit/inherit}}".

      <li><p>If |option|'s {{SchedulerYieldOptions/priority}} is "{{ContinuationPriority/inherit}}",
      or if |option|'s {{SchedulerYieldOptions/priority}} is not set and
      {{SchedulerYieldOptions/signal}} is "{{SchedulerSignalInherit/inherit}}", then the originating
      task's priority is used (a {{TaskSignal}} or fixed priority). If the originating task did not
      have a priority, then "{{ContinuationPriority/user-visible}}" is used.

      <li><p>Otherwise if |option|'s {{SchedulerPostTaskOptions/priority}} is specified, then that
      {{ContinuationPriority}} will be used to schedule the continuation, and the continuation's
      priority is immutable.

      <li><p>Otherwise, if |option|'s {{SchedulerYieldOptions/signal}} is specified and is a
      {{TaskSignal}} object, then the continuation's priority is determined dynamically by
      |option|'s {{SchedulerYieldOptions/signal}}'s [=TaskSignal/priority=].

      <li><p>Otherwise, the continuation's priority defaults to
      "{{ContinuationPriority/user-visible}}".
    </ul>

</dl>


A {{Scheduler}} object has an associated <dfn for="Scheduler">static priority task queue map</dfn>,
which is a [=map=] from ({{TaskPriority}}, boolean) to [=scheduler task queue=]. This map is
initialized to a new empty [=map=].

A {{Scheduler}} object has an associated <dfn for="Scheduler">dynamic priority task queue map</dfn>,
which is a [=map=] from ({{TaskSignal}}, boolean) to [=scheduler task queue=]. This map is
initialized to a new empty [=map=].

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
task/enqueue order=]. This approach would simplify [=selecting the next scheduler task queue from
all schedulers=], but make priority changes more complex.

The <dfn method for=Scheduler title="postTask(callback, options)">postTask(|callback|, |options|)</dfn>
method steps are to return the result of [=scheduling a postTask task=] for [=this=] given
|callback| and |options|.

The <dfn method for=Scheduler title="yield(options)">yield(|options|)</dfn> method steps are to
return the result of [=scheduling a yield continuation=] for [=this=] given |options|.


## Definitions ## {#sec-scheduling-tasks-definitions}

A <dfn>scheduler task</dfn> is a [=/task=] with an additional numeric
<dfn for="scheduler task">enqueue order</dfn> [=struct/item=], initially set to 0.

The following [=task sources=] are defined as <dfn>scheduler task sources</dfn>,
and must only be used for [=scheduler tasks=].

: The <dfn>posted task task source</dfn>
:: This [=task source=] is used for tasks scheduled through {{Scheduler/postTask()}} or {{Scheduler/yield()}}.

<br/>

A <dfn>scheduler task queue</dfn> is a [=struct=] with the following [=struct/items=]:

: <dfn for="scheduler task queue">priority</dfn>
:: A {{TaskPriority}}.
: <dfn for="scheduler task queue">is continuation</dfn>
:: A boolean.
: <dfn for="scheduler task queue">tasks</dfn>
:: A [=set=] of [=scheduler tasks=].
: <dfn for="scheduler task queue">removal steps</dfn>
:: An algorithm.

<br/>

A <dfn>scheduling state</dfn> is a [=struct=] with the following [=struct/items=]:

: <dfn for="scheduling state">abort source</dfn>
:: An {{AbortSignal}} object or, initially null.
: <dfn for="scheduling state">priority source</dfn>
:: A {{TaskSignal}} object or null, initially null.

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
  To <dfn>create a scheduler task queue</dfn> with {{TaskPriority}} |priority|, a boolean
  |isContinuation|, and an algorithm |removalSteps|:

  1. Let |queue| be a new [=scheduler task queue=].
  1. Set |queue|'s [=scheduler task queue/priority=] to |priority|.
  1. Set |queue|'s [=scheduler task queue/is continuation=] to |isContinuation|.
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

<div algorithm>
  A [=scheduler task queue=] |queue|'s <dfn for="scheduler task queue">effective priority</dfn> is
  computed as the third column of the row matching the |queue|'s [=scheduler task queue/priority=]
  and [=scheduler task queue/is continuation=]:

  <p><table>
   <thead>
    <tr><th>Priority<th>Is Continuation<th>Effective Priority
   <tbody>
    <tr><td>"{{TaskPriority/background}}"<td>`false`<td>0
    <tr><td>"{{TaskPriority/background}}"<td>`true`<td>1
    <tr><td>"{{TaskPriority/user-visible}}"<td>`false`<td>2
    <tr><td>"{{TaskPriority/user-visible}}"<td>`true`<td>3
    <tr><td>"{{TaskPriority/user-blocking}}"<td>`false`<td>4
    <tr><td>"{{TaskPriority/user-blocking}}"<td>`true`<td>5
  </table>
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

### Scheduling Tasks and Continuations ### {#sec-scheduler-alg-scheduling-tasks-and-continuations}

<div algorithm>
  To <dfn>schedule a postTask task</dfn> for {{Scheduler}} |scheduler| given a
  {{SchedulerPostTaskCallback}} |callback| and {{SchedulerPostTaskOptions}} |options|:

  1. Let |result| be [=a new promise=].
  1. Let |state| be the result of [=computing the scheduling state from options=] given |scheduler|,
     |options|["{{SchedulerPostTaskOptions/signal}}"] if it [=map/exists=], or otherwise null, and
     |options|["{{SchedulerPostTaskOptions/priority}}"] if it [=map/exists=], or otherwise null.
  1. Let |signal| be |state|'s [=scheduling state/abort source=].
  1. If |signal| is not null and it is [=AbortSignal/aborted=], then [=reject=] |result| with
     |signal|'s [=AbortSignal/abort reason=] and return |result|.
  1. Let |handle| be the result of [=creating a task handle=] given |result| and |signal|.
  1. If |signal| is not null, then [=AbortSignal/add=] |handle|'s [=task handle/abort steps=] to
     |signal|.
  1. Let |enqueueSteps| be the following steps:
    1. Set |handle|'s [=task handle/queue=] to the result of [=selecting the scheduler task queue=]
       for |scheduler| given |state|'s [=scheduling state/priority source=] and false.
    1. [=Schedule a task to invoke an algorithm=] for |scheduler| given |handle| and the following
       steps:
      1. Let |event loop| be the |scheduler|'s [=relevant agent=]'s [=agent/event loop=].
      1. Set |event loop|'s [=event loop/current scheduling state=] to |state|.
      1. Let |callbackResult| be the result of [=invoking=] |callback|. If that threw an exception,
         then [=reject=] |result| with that, otherwise resolve |result| with |callbackResult|.
      1. Set |event loop|'s [=event loop/current scheduling state=] to null.
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
  To <dfn>schedule a yield continuation</dfn> for {{Scheduler}} |scheduler| given
  {{SchedulerYieldOptions}} |options|:

  1. Let |result| be [=a new promise=].
  1. Let |abortOption| be |options|["{{SchedulerYieldOptions/signal}}"] if it [=map/exists=],
     otherwise null.
  1. Let |priorityOption| be |options|["{{SchedulerPostTaskOptions/priority}}"] if it
     [=map/exists=], otherwise null.
  1. If |abortOption| is null and |priorityOption| is null, then set |abortOption| to
     "{{SchedulerSignalInherit/inherit}}" and set |priorityOption| to
     "{{SchedulerSignalInherit/inherit}}".
  1. Otherwise if |abortOption| is "{{SchedulerSignalInherit/inherit}}" and |priorityOption| is null,
     then set |priorityOption| to "{{SchedulerSignalInherit/inherit}}".
  1. Let |state| be the result of [=computing the scheduling state from options=] given |scheduler|,
     |abortOption|, and |priorityOption|.
  1. Let |signal| be |state|'s [=scheduling state/abort source=].
  1. If |signal| is not null and it is [=AbortSignal/aborted=], then [=reject=] |result| with
     |signal|'s [=AbortSignal/abort reason=] and return |result|.
  1. Let |handle| be the result of [=creating a task handle=] given |result| and |signal|.
  1. If |signal| is not null, then [=AbortSignal/add=] |handle|'s [=task handle/abort steps=] to
     |signal|.
  1. Set |handle|'s [=task handle/queue=] to the result of [=selecting the scheduler task queue=]
     for |scheduler| given |state|'s [=scheduling state/priority source=] and true.
  1. [=Schedule a task to invoke an algorithm=] for |scheduler| given |handle| and the following
     steps:
    1. Resolve |result|.
  1. Return |result|.
</div>

<div algorithm>
  To <dfn>compute the scheduling state from options</dfn> given a {{Scheduler}} object |scheduler|,
  an {{AbortSignal}} object, "{{SchedulerSignalInherit/inherit}}", or null |signalOption| and a
  {{TaskPriority}}, "{{SchedulerSignalInherit/inherit}}", or null |priorityOption|:

  1. Let |result| be a new [=scheduling state=].
  1. Let |inheritedState| be the |scheduler|'s [=relevant agent=]'s [=agent/event loop=]'s
     [=event loop/current scheduling state=].
  1. If |signalOption| is "{{SchedulerSignalInherit/inherit}}", then:
    1. If |inheritedState| is not null, then set |result|'s [=scheduling state/abort source=] to
       |inheritedState|'s [=scheduling state/abort source=].
  1. Otherwise, set |result|'s [=scheduling state/abort source=] to |signalOption|.
  1. If |priorityOption| is "{{SchedulerSignalInherit/inherit}}", then:
    1. If |inheritedState| is not null, then set |result|'s [=scheduling state/priority source=] to
       |inheritedState|'s [=scheduling state/priority source=].
  1. Otherwise if |priorityOption| is not null, then set |result|'s [=scheduling state/priority
     source=] to the result of [=creating a fixed priority unabortable task signal=] given
     |priorityOption|.
  1. Otherwise if |signalOption| is not null and [=implements=] the {{TaskSignal}} interface, then
     set |result|'s [=scheduling state/priority source=] to |signalOption|.
  1. If |result|'s [=scheduling state/priority source=] is null, then set |result|'s [=scheduling
     state/priority source=] to the result of [=creating a fixed priority unabortable task signal=]
     given "{{TaskPriority/user-visible}}".
  1. Return |result|.

  Note: The fixed priority unabortable signals created here can be cached and reused to avoid extra
  memory allocations.
</div>

<div algorithm>
  To <dfn>select the scheduler task queue</dfn> for a {{Scheduler}} |scheduler| given a
  {{TaskSignal}} object |signal| and a boolean |isContinuation|:

  1. If |signal| does not [=TaskSignal/have fixed priority=], then
    1. If |scheduler|'s [=Scheduler/dynamic priority task queue map=] does not [=map/contain=]
       (|signal|, |isContinuation|), then
      1. Let |queue| be the result of [=creating a scheduler task queue=] given |signal|'s
         [=TaskSignal/priority=], |isContinuation|, and the following steps:
          1. [=map/Remove=] [=Scheduler/dynamic priority task queue map=][(|signal|, |isContinuation|)].
      1. Set [=Scheduler/dynamic priority task queue map=][(|signal|, |isContinuation|)] to
         |queue|.
      1. [=TaskSignal/Add a priority change algorithm=] to |signal| that runs the following steps:
        1. Set |queue|'s [=scheduler task queue/priority=] to |signal|'s {{TaskSignal/priority}}.
    1. Return [=Scheduler/dynamic priority task queue map=][(|signal|, |isContinuation|)].
  1. Otherwise
    1. Let |priority| be |signal|'s [=TaskSignal/priority=].
    1. If |scheduler|'s [=Scheduler/static priority task queue map=] does not [=map/contain=]
       (|priority|, |isContinuation|) , then
      1. Let |queue| be the result of [=creating a scheduler task queue=] given |priority|,
         |isContinuation|, and the following steps:
        1. [=map/Remove=] [=Scheduler/static priority task queue map=][(|priority|, |isContinuation|)].
      1. Set [=Scheduler/static priority task queue map=][(|priority|, |isContinuation|)] to |queue|.
    1. Return [=Scheduler/static priority task queue map=][(|priority|, |isContinuation|)].
</div>

<div algorithm>
  To <dfn>schedule a task to invoke an algorithm</dfn> for {{Scheduler}} |scheduler| given a
  [=task handle=] |handle| and an algorithm |steps|:

  1. Let |global| be the [=relevant global object=] for |scheduler|.
  1. Let |document| be |global|'s <a attribute for="Window">associated `Document`</a> if |global| is
     a {{Window}} object; otherwise null.
  1. Let |event loop| be the |scheduler|'s [=relevant agent=]'s [=agent/event loop=].
  1. Let |enqueue order| be |event loop|'s [=event loop/next enqueue order=].
  1. Increment |event loop|'s [=event loop/next enqueue order=] by 1.
  1. Set |handle|'s [=task handle/task=] to the result of [=queuing a scheduler task=] on |handle|'s
     [=task handle/queue=] given |enqueue order|, the [=posted task task source=], and |document|,
     and that performs the following steps:
    1. Run |steps|.
    1. Run |handle|'s [=task handle/task complete steps=].

  Issue: Because this algorithm can be called from [=in parallel=] steps, parts of this and other
  algorithms are racy. Specifically, the [=event loop/next enqueue order=] should be updated
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
  To <dfn>select the next scheduler task queue from all schedulers</dfn> given an [=event loop=]
  |event loop|, perform the following steps. They return a [=scheduler task queue=] or null if no
  {{Scheduler}} associated with the |event loop| [=has a runnable task=].

  1. Let |queues| be an empty [=set=].
  1. Let |schedulers| be the [=set=] of all {{Scheduler}} objects whose [=relevant agent's=]
     [=agent/event loop=] is |event loop| and that [=have a runnable task=].
  1. For each |scheduler| in |schedulers|, [=list/extend=] |queues| with the result of [=getting the
     runnable task queues=] for |scheduler|.
  1. If |queues| is [=list/empty=] return null.
  1. [=set/Remove=] from |queues| any |queue| such that |queue|'s [=scheduler task queue/effective
     priority=] is less than any other [=set/item=] of |queues|.
  1. Let |queue| be the [=scheduler task queue=] in |queues| whose [=scheduler task queue/first
     runnable task=] is the [=scheduler task/older than|oldest=].
     <br/><span class=note>Two tasks cannot have the same age since [=scheduler task/enqueue order=]
     is unique.</span>
  1. Return |queue|.

  Note: The next task to run is the oldest, highest priority [=task/runnable=] [=scheduler task=]
  from all {{Scheduler}}s associated with the [=event loop=].
 </div>


## Examples ## {#sec-scheduling-tasks-examples}

**TODO**(shaseley): Add examples.
