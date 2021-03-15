Scheduling Tasks {#sec-scheduling-tasks}
=====================

**TODO**: Add an intro for this section.

Task Priorities {#sec-task-priorities}
---------------------

This spec formalizes three priorities to support scheduling tasks:

<pre class='idl'>
  enum TaskPriority {
      "user-blocking",
      "user-visible",
      "background"
  };
</pre>

{{TaskPriority/user-blocking}} is the highest priority, and is meant to be used
for tasks that are blocking the user's ability to interact with the page, such
as rendering the core experience or responding to user input.

{{TaskPriority/user-visible}} is the second highest priority, and is meant to
be used for tasks that visible to the user but not necessarily blocking user
actions, such as rendering secondary parts of the page. This is the default
priority.

{{TaskPriority/background}} is the lowest priority, and is meant to be used for
tasks that are not time-critical, such as background log processing or
initializing certain third party libraries.

Note: Tasks scheduled through a given {{Scheduler}} run in *strict priority
order*, meaning the scheduler will always run {{TaskPriority/user-blocking}}
tasks before {{TaskPriority/user-visible}} tasks, which in turn always run
before {{TaskPriority/background}} tasks.

<div algorithm>
  {{TaskPriority}} |p1| is <dfn for="TaskPriority">less than</dfn>
  {{TaskPriority}} |p2| if |p1| is less than |p2| in the
  following total ordering:
    * {{TaskPriority/background}} < {{TaskPriority/user-visible}} < {{TaskPriority/user-blocking}}
</div>


The `Scheduler` Interface {#sec-scheduler}
---------------------

<xmp class='idl'>
  dictionary SchedulerPostTaskOptions {
      AbortSignal? signal = null;
      TaskPriority? priority = null;
      long delay = 0;
  };

  callback SchedulerPostTaskCallback = any ();

  [Exposed=(Window, Worker)] interface Scheduler {
    Promise<any> postTask(SchedulerPostTaskCallback callback,
                          optional SchedulerPostTaskOptions options = {});
  };
</xmp>

Note: The {{SchedulerPostTaskOptions/signal}} option can be either an
{{AbortSignal}} or a {{TaskSignal}}, but is defined as an {{AbortSignal}} since
it is a superclass of {{TaskSignal}}. For cases where the priority might
change, a {{TaskSignal}} is needed. But for cases where only cancellation is
needed, an {{AbortSignal}} would suffice, potentially making it easier to
integrate the API into existing code that uses {{AbortSignal}}s.

Note: If the {{SchedulerPostTaskOptions/signal}} is set to a {{TaskSignal}} and
a {{SchedulerPostTaskOptions/priority}} is also provided, the {{TaskSignal}} is
treated as an {{AbortSignal}}, meaning priority change events will not impact
the task, but abort events will.


A {{Scheduler}} object has an associated <dfn for="Scheduler">static priority
task queue map</dfn>, which is a [=map=] from {{TaskPriority}} to [=scheduler
task queue=].  This map is empty unless otherwise stated.

A {{Scheduler}} object has an associated <dfn for="Scheduler">dynamic priority
task queue map</dfn>, which is a [=map=] from {{TaskSignal}} to [=scheduler
task queue=]. This map is empty unless otherwise stated.

Note: These two [=maps=] are how this specification implements
*dynamic prioritization*, or changing a tasks's priority in response
to an invocation of a {{TaskController}}'s {{TaskController/setPriority()}}.
<br/><br/>
The values of the <a for=Scheduler>static priority task queue map</a>
are [=scheduler task queues=] whose [=scheduler task queue/priority=] is fixed.
We use these task queues for tasks where a {{SchedulerPostTaskOptions/priority}}
is specified, or where the {{SchedulerPostTaskOptions/signal}} is null or is an
{{AbortSignal}}.
<br/><br/>
Other tasks &mdash; those with a null {{SchedulerPostTaskOptions/priority}}
and an associated {{TaskSignal}} &mdash; have *dynamic priorities*, and we
create a [=scheduler task queue=] per-{{TaskSignal}}, stored in the
<a for=Scheduler>dynamic priority task queue map</a>. To change the priority of
all tasks associated with a particular {{TaskSignal}}, we simply change the
[=scheduler task queue/priority=] of the corresponding [=scheduler task queue=].
<br/><br/>
An alternative, and logicially equivalent implementation, would be to maintain a
single [=scheduler task queue=] per-{{TaskPriority}}, and move tasks between
[=scheduler task queues=] in response to a {{TaskSignal}}'s
<a for=TaskSignal>priority</a> changing, inserting based on
[=scheduler task/enqueue order=]. This approach would simplify
[=selecting the task queue of the next scheduler task=], but make priority
changes more complex.


A {{Scheduler}} object has a numeric <dfn for="Scheduler">next enqueue
order</dfn> which is initialized to 1.

Note: The [=Scheduler/next enqueue order=] is a strictly increasing number that
is used to determine task execution order across [=scheduler task queues=] of the
same {{TaskPriority}} within the same {{Scheduler}}. A logically equivalent
alternative would be to place the [=Scheduler/next enqueue order=] on the
[=event loop=], since the only requirements are that the number be strictly
increasing and not be repeated within a {{Scheduler}}.

The <dfn method for=Scheduler title="postTask(callback, options)">postTask(|callback|, |options|)</dfn>
method must return the result of [=scheduling a postTask task=] for [=this=] given |callback| and |options|.


Definitions {#sec-scheduling-tasks-definitions}
---------------------

### Scheduler Tasks ### {#sec-def-scheduler-tasks}

A <dfn>scheduler task</dfn> is a <a for="/">task</a> with an additional numeric
<dfn for="scheduler task">enqueue order</dfn> [=struct/item=], initially set to 0.

A [=scheduler task=] |t1| is <dfn for="scheduler task">older than</dfn>
[=scheduler task=] |t2| if |t1|'s [=scheduler task/enqueue order=] less than |t2|'s
[=scheduler task/enqueue order=].

### Scheduler Task Sources ### {#sec-def-scheduler-task-sources}

The following [=task sources=] are defined as <dfn>scheduler task sources</dfn>,
and must only be used for [=scheduler tasks=].

: <dfn>The posted task task source</dfn>
:: This [=task source=] is used for tasks scheduled through {{Scheduler/postTask()}}.


### Scheduler Task Queues ### {#sec-def-scheduler-task-queues}

A <dfn>scheduler task queue</dfn> is a [=struct=] with the following [=struct/items=]:

: <dfn for="scheduler task queue">priority</dfn>
:: A {{TaskPriority}}.
: <dfn for="scheduler task queue">tasks</dfn>
:: A [=set=] of [=scheduler tasks=].

<div algorithm>
  To <dfn lt="create a scheduler task queue|creating a scheduler task queue">create a scheduler task queue</dfn>
  with {{TaskPriority}} |priority|:

  1. Let |queue| be a new [=scheduler task queue=].
  1. Set |queue|'s [=scheduler task queue/priority=] to |priority|.
  1. Set |queue|'s [=scheduler task queue/tasks=] to a new empty [=set=].
  1. Return |queue|.
</div>

A [=scheduler task queue=] |queue|'s <dfn for="scheduler task queue">first runnable task</dfn>
is the first [=scheduler task=] in |queue|'s [=scheduler task queue/tasks=] that is
<a for="task">runnable</a>.

Processing Model {#sec-scheduling-tasks-processing-model}
---------------------


### Queueing and Removing Scheduler Tasks ### {#sec-queuing-scheduler-tasks}

<div algorithm="queue a scheduler task">
  To <dfn lt="queue a scheduler task|queuing a scheduler task">queue a scheduler task</dfn> on a [=scheduler task queue=] |queue|,
  which performs a series of steps |steps|, given a numeric |enqueue order|, a
  [=task source=] |source|, and a [=document=] |document|:

  1. Let |task| be a new [=scheduler task=].
  1. Set |task|'s [=scheduler task/enqueue order=] to |enqueue order|.
  1. Set |task|'s <a attribute for="task">steps</a> to |steps|.
  1. Set |task|'s <a attribute for="task">source</a> to |source|.
  1. Set |task|'s <a attribute for="task">document</a> to |document|.
  1. Set |task|'s <a attribute for="task">script evaluation environment settings object set</a> to a new empty [=set=].
  1. [=set/Append=] |task| to |queue|'s [=scheduler task queue/tasks=].
  1. Return |task|.

  Issue: We should submit a PR to the HTML spec that adds a constructor for <a for="/">task</a>.
</div>

<div algorithm>
  To <dfn for="scheduler task queue">remove</dfn> a [=scheduler task=] |task| from
  [=scheduler task queue=] |queue|, [=set/remove=] |task| from |queue|'s
  [=scheduler task queue/tasks=].
</div>

### Scheduling Tasks ### {#sec-scheduler-alg-scheduling-tasks}

<div algorithm="schedule a postTask task">
  To <dfn lt="schedule a postTask task|scheduling a postTask task">schedule a postTask task</dfn>
  for {{Scheduler}} |scheduler| given a {{SchedulerPostTaskCallback}} |callback| and
  {{SchedulerPostTaskOptions}} options, run the following steps:

  1. Let |result| be [=a new promise=].
  1. Let |signal| be |options|["{{SchedulerPostTaskOptions/signal}}"].
  1. If |signal| is not null and its [=AbortSignal/aborted flag=] is set, then [=reject=] |result| with an "{{AbortError!!exception}}" {{DOMException}} and return |result|.
  1. Let |priority| be |options|["{{SchedulerPostTaskOptions/priority}}"].
  1. Let |queue| be the result of [=selecting the scheduler task queue=] for |scheduler| given |signal| and |priority|.
  1. Let |delay| be |options|["{{SchedulerPostTaskOptions/delay}}"].
  1. If |delay| is less than 0 then set |delay| to 0.
  1. If |delay| is equal to 0 then
    1. [=Schedule a task to invoke a callback=] for |scheduler| given |queue|, |signal|, |callback|, and |result|.
    1. Return |result|.
  1. Otherwise, return |result| and continue running this algorithm [=in parallel=].
  1. **TODO**: Define waiting, potentially refactoring the timer spec.
  1. [=Schedule a task to invoke a callback=] for |scheduler| given |queue|, |signal|, |callback|, and |result|.
</div>

<div algorithm="select the scheduler task queue">
  To <dfn lt="select the scheduler task queue|selecting the scheduler task queue">select the scheduler task queue</dfn>
  for a {{Scheduler}} |scheduler| given ({{TaskSignal}} or {{AbortSignal}}) |signal|, and a {{TaskPriority}} |priority|:

  1. If |priority| is null and |signal| is not null and |signal| is a {{TaskSignal}}, then
    1. If |scheduler|'s [=Scheduler/dynamic priority task queue map=] does not [=map/contain=] |signal|, then
      1. Let |queue| be the result of [=creating a scheduler task queue=] given |signal|'s <a for=TaskSignal>priority</a>.
      1. Set [=Scheduler/dynamic priority task queue map=][|signal|] to |queue|.
      1. <a for=TaskSignal>Add a priority change algorithm</a> to |signal| that runs the following steps:
        1. Set |queue|'s [=scheduler task queue/priority=] to |signal|'s {{TaskSignal/priority}}.
    1. Return [=Scheduler/dynamic priority task queue map=][|signal|].
  1. Otherwise |priority| is used to determine the task queue:
    1. If |priority| is null, set |priority| to {{TaskPriority/user-visible}}.
    1. If |scheduler|'s [=Scheduler/static priority task queue map=] does not [=map/contain=] |priority|, then
      1. Let |queue| be the result of [=creating a scheduler task queue=] given |priority|.
      1. Set [=Scheduler/static priority task queue map=][|priority|] to |queue|.
    1. Return [=Scheduler/static priority task queue map=][|priority|].
</div>

<div algorithm>
  To <dfn>schedule a task to invoke a callback</dfn> for {{Scheduler}}
  |scheduler| given a [=scheduler task queue=] |queue|, an {{AbortSignal}} |signal|,
  SchedulerPostTaskCallback |callback|, and promise |result|:

  1. Let |global| be the [=relevant global object=] for |scheduler|.
  1. Let |document| be |global|'s <a attribute for="Window">associated <code>Document</code></a> if |global| is a {{Window}} object; otherwise null.
  1. Let |enqueue order| be |scheduler|'s [=Scheduler/next enqueue order=].
  1. Increment |scheduler|'s [=Scheduler/next enqueue order=] by 1.
  1. Let |task| be the result of [=queuing a scheduler task=] on |queue| given |enqueue order|, [=the posted task task source=], and |document|, and that performs the following steps:
    1. Let |callback result| be the result of [=invoking=] |callback|. If that threw an exception, then [=reject=] |result| with that, otherwise resolve |result| with |callback result|.
  1. If |signal| is not null, then <a for=AbortSignal lt=add>add the following</a> abort steps to it:
    1. [=scheduler task queue/Remove=] |task| from |queue|.
    1. [=Reject=] |result| with an "{{AbortError!!exception}}" {{DOMException}}.

  Issue: Because this algorithm can be called from [=in parallel=] steps, parts
  of this and other algorithms are racy. Specifically, the
  [=Scheduler/next enqueue order=] should be updated atomically, and accessing
  the [=scheduler task queues=] should occur atomically. The latter also affects
  the event loop task queues (see https://github.com/whatwg/html/issues/6475).

  Issue: We need to figure out what to do with cross-window scheduling. As-is,
  this differs from `setTimeout` in terms if the `thisArg` when invoking the
  callback. We leave it null and `this` will map to the global of where the
  callback is defined. `setTimeout` maps `this` to the global of the window
  associated with the `setTimeout` that got called, but if you pass an arrow
  function, then this will be bound based on the function's definition scope.
  IMO what we're doing for postTask makes sense, especially because otherwise
  switching between an arrow and non-arrow function will likely change `this`.
  Also, there is the question of which document should be associated with the
  task, and I suppose the question of if cross-window scheduling even makes
  sense.
</div>

### Selecting the Next Task to Run ### {#sec-scheduler-alg-select-next-task}

<div algorithm="has a runnable task">
  A {{Scheduler}} |scheduler| <dfn lt="has a runnable task|have a runnable task">has a runnable task</dfn>
  if the result of [=getting the runnable task queues=] for |scheduler| is non-[=list/empty=].
</div>

<div algorithm="get the runnable task queues">
  To <dfn lt="get the runnable task queues|getting the runnable task queues">get the runnable task queues</dfn> for a {{Scheduler}} |scheduler|, run the following steps:

  1. Let |queues| be the result of <a for="map" lt="get the values">getting the values</a> of |scheduler|'s [=Scheduler/static priority task queue map=].
  1. [=list/Extend=] |queues| with the result of <a for="map" lt="get the values">getting the values</a> of |scheduler|'s [=Scheduler/dynamic priority task queue map=].
  1. [=list/Remove=] from |queues| any |queue| such that |queue|'s [=scheduler task queue/tasks=] do not contain a <a for="task">runnable</a> [=scheduler task=].
  1. Return |queues|.
</div>

<div algorithm>
  The result of <dfn>selecting the task queue of the next scheduler task</dfn>
  for {{Scheduler}} |scheduler| is a [=set=] of [=scheduler tasks=] as defined
  by the following steps:

  1. Let |queues| be the result of [=getting the runnable task queues=] for |scheduler|.
  1. If |queues| is [=list/empty=] return null.
  1. [=set/Remove=] from |queues| any |queue| such that |queue|'s [=scheduler task queue/priority=]
     is <a for="TaskPriority">less than</a> any other [=set/item=] of |queues|.
  1. Let |queue| be the [=scheduler task queue=] in |queues| whose
     <a for="scheduler task queue">first runnable task</a> is the
     <a for="scheduler task" lt="older than">oldest</a>.
     <br/><span class=note>Two tasks cannot have the same age since [=scheduler task/enqueue order=] is unique.</span>
  1. Return |queue|'s [=scheduler task queue/tasks=].

  Note: The next task to run is the oldest, highest priority <a for="task">runnable</a> [=scheduler task=].
</div>
