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
  {{TaskPriority}} |priority1| is <dfn for="TaskPriority">less than</dfn>
  {{TaskPriority}} |priority2| if the following steps return true:

  1. Let |priorities| be the [=map=] «[ {{TaskPriority/user-blocking}} → 2, {{TaskPriority/user-visible}} → 1, {{TaskPriority/background}} → 0 ]».
  1. Return true if |priorities|[|priority1|] is less than |priorities|[|priority2|], otherwise false.
</div>



The `Scheduler` Interface {#sec-scheduler}
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

Issue: Is that the right way to define signal? It's currently defined as an AbortSignal in our implementation.

Issue: Is it common to add line breaks for long IDL?

A {{Scheduler}} object has an associated <dfn for="Scheduler">static priority
task queue map</dfn>, which is a [=map=] of [=scheduler task queues=] indexed
by {{TaskPriority}}. This map is empty unless otherwise stated.

A {{Scheduler}} object has an associated <dfn for="Scheduler">dynamic priority
task queue map</dfn>, which is a [=map=] of [=scheduler task queues=] indexed
by {{TaskSignal}}. This map is empty unless otherwise stated.

A {{Scheduler}} object has a numeric <dfn for="Scheduler">next enqueue
order</dfn> which is initialized to 1.

Issue: Is this how we define numeric attributes?

Note: The [=Scheduler/next enqueue order=] is a strictly increasing number that
is used to determine task execution order across [=scheduler task queues=] of the
same {{TaskPriority}} within the same {{Scheduler}}. A logically equivalent
alternative would be to place the [=Scheduler/next enqueue order=] on the
[=event loop=], since the only requirements are that the number be strictly
increasing and not be repeated within a {{Scheduler}}.

The <dfn method for=Scheduler title=postTask(callback, options)>postTask(|callback|, |options|)</dfn>
method must return the result of [=scheduling a postTask task=] for [=this=] given |callback| and |options|.

Issue: Do we need to explicitly create |options|, or is the IDL that defaults it sufficient?


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

Issue: Scheduler task queues in this spec are only created with an algorithm
that initializes the fields, which was done because a priority is required when
instantiating a STQ. Is this okay, or should they be initialized here? An example
of this pattern is the Task struct in the event loop spec.

Issue: Is it okay to rely on a task queue being defined as a set, rather than
using a task queue in the data structure? I wanted a set of scheduler tasks,
not tasks, and it's spec inheritance semantics/rules are not clear to me.


Processing Model {#sec-scheduling-tasks-processing-model}
---------------------

### Creating Scheduler Task Queues ### {#sec-selecting-creating-scheduler-task-queues}

<div algorithm>
  To <dfn lt="create a scheduler task queue|creating a scheduler task queue">create a scheduler task queue</dfn>
  with {{TaskPriority}} |priority|:

  1. Let |queue| be a new [=scheduler task queue=].
  1. Set |queue|'s [=scheduler task queue/priority=] to |priority|.
  1. Set |queue|'s [=scheduler task queue/tasks=] to a new [=set=].
  1. Return |queue|.
</div>


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
  1. Set |task|'s <a attribute for="task">script evaluation environment settings object set</a> to a new [=set=].
  1. [=set/Append=] |task| to |queue|'s [=scheduler task queue/tasks=].
  1. Return |task|.

  Issue: Should we refactor the event loop task creation code and remove the duplicatation?
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

  1. Let |result| be a new promise.

  1. Let |signal| be null.
  1. If |options|["{{SchedulerPostTaskOptions/signal}}"] [=map/exists=], then set |signal| to |options|["{{SchedulerPostTaskOptions/signal}}"].
  1. If |signal| is not null and its [=AbortSignal/aborted flag=] is set, then [=reject=] |result| with an "{{AbortError!!exception}}" {{DOMException}} and return |result|.
 
  1. Let |priority| be null.
  1. If |options|["{{SchedulerPostTaskOptions/priority}}"] [=map/exists=], then set |priority| to |options|["{{SchedulerPostTaskOptions/priority}}"].

  1. Let |queue| be the result of [=selecting the scheduler task queue=] for |scheduler| given |signal| and |priority|.

  1. Let |delay| be 0.
  1. If |options|["{{SchedulerPostTaskOptions/delay}}"] [=map/exists=], then set |delay| to |options|["{{SchedulerPostTaskOptions/delay}}"].
  1. If |delay| is less than 0 then set |delay| to 0.
  1. If |delay| is equal to 0 then
    1. [=Schedule a task to invoke a callback=] for |scheduler| given |queue|, |signal|, |callback|, and |result|.
    1. Return |result|.
  1. Otherwise, return |result| and continue running this algorithm [=in parallel=].
  1. **TODO**: Define waiting, potentially refactoring the timer spec.
  1. [=schedule a task to invoke a callback=] for |scheduler| given |queue|, |signal|, |callback|, and |result|.
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
  1. Otherwise
    1. If |priority| is null, set |priority| to {{TaskPriority/user-visible}}.
    1. If |scheduler|'s [=Scheduler/static priority task queue map=] does not [=map/contain=] |priority|, then
      1. Let |queue| be the result of [=creating a scheduler task queue=] given |priority|.
      1. Set [=Scheduler/static priority task queue map=][|priority|] to |queue|.
    1. Return [=Scheduler/static priority task queue map=][|priority|].

  Note: When an explicit priority is passed to {{Scheduler/postTask()}}, the
  {{TaskSignal}} option is ignored for priority, and the task's priority is
  immutable. The signal is still relevant for {{AbortController/abort()}}, however.

  Issue: I'm not sure if ^^ that note belongs there, but it seems like it should
  go somewhere.

  Issue: Maybe change the name of this since it also creates the task queue if needed.
</div>

<div algorithm>
  To <dfn>schedule a task to invoke a callback</dfn> for {{Scheduler}}
  |scheduler| given a [=scheduler task queue=] |queue|, an {{AbortSignal}} |signal|,
  SchedulerPostTaskCallback |callback|, and promise |result|:

  1. Let |global| be the [=relevant global object=] for |scheduler|.
  1. Let |document| be |global|'s <a attribute for="Window">associated <code>Document</code></a> if |global| is a {{Window}} object; otherwise null.
  1. Let |enqueue order| be |scheduler|'s [=next enqueue order=].
  1. Increment |scheduler|'s [=next enqueue order=] by 1.
  1. Let |task| be the result of [=queuing a scheduler task=] on |queue| given |enqueue order|, [=the posted task task source=], and |document|, and that performs the following steps:
    1. Let |callback result| be the result of [=invoking=] |callback|. If that threw an exception, then [=reject=] |result| with that, otherwise resolve |result| with |callback result|.
  1. If |signal| is not null, then <a for=AbortSignal lt=add>add the following</a> abort steps to it:
    1. [=scheduler task queue/Remove=] |task| from |queue|.
    1. [=Reject=] |result| with an "{{AbortError!!exception}}" {{DOMException}}.

  Issue: Parts of this need to be atomic, but how do we do that?
</div>

### Selecting the Next Task to Run ### {#sec-scheduler-alg-select-next-task}

<div algorithm="has a runnable task">
  A {{Scheduler}} |scheduler| <dfn lt="has a runnable task|have a runnable task">has a runnable task</dfn> if the result of [=getting the runnable task queues=] for |scheduler| is non-[=list/empty=].
</div>

<div algorithm="get the runnable task queues">
  To <dfn lt="get the runnable task queues|getting the runnable task queues">get the runnable task queues</dfn> for a {{Scheduler}} |scheduler|, run the following steps:

  1. Let |queues| be the result of <a for="map" lt="get the values">getting the values</a> [=Scheduler/static priority task queue map=].
  1. [=list/Extend=] |queues| with the result of <a for="map" lt="get the values">getting the values</a> of |scheduler|'s [=Scheduler/dynamic priority task queue map=].
  1. [=list/Remove=] from |queues| any |queue| such that |queue|'s [=scheduler task queue/tasks=] do not contain a <a for="task">runnable</a> [=scheduler task=].
  1. Return |queues|.
</div>

<div algorithm="select the task queue of the next scheduler task">
  To <dfn lt="select the task queue of the next scheduler task|selecting the task queue of the next scheduler task v2">select the task queue of the next scheduler task</dfn> for a {{Scheduler}} |scheduler|:

  1. Let |queues| be the result of [=getting the runnable task queues=] for |scheduler|.
  1. If |queues| is [=list/empty=] return null.
  1. Set |queues| to the result of [=list/sorting in descending order=] |queues| with |a| being less than |b| if the following steps return true:
    1. If |a|'s [=scheduler task queue/priority=] is <a for="TaskPriority">less than</a> |b|'s [=scheduler task queue/priority=], then return true.
    1. If |a|'s [=scheduler task queue/priority=] equals |b|'s [=scheduler task queue/priority=] and
       the first <a for="task">runnable</a> [=scheduler task=] in |a| is [=scheduler task/older than=]
       the first <a for="task">runnable</a> [=scheduler task=] in |b|, then return true.
    1. Otherwise return false.
  1. Return |queues|[0]'s [=scheduler task queue/tasks=].

  Issue: Is it okay to rely on a task queue being defined as a set, rather than
  using a task queue in the data structure? I wanted a set of scheduler tasks,
  not tasks.
</div>
