Processing Model {#sec-processing-model}
=====================

**TODO**(shaseley): Add an intro sentence here.

Scheduler Task Sources {#sec-scheduler-task-sources}
---------------------

The following [=task sources=] are defined as <dfn>scheduler task sources</dfn>,
and must only be used for [=scheduler tasks=].

: <dfn>The posted task task source</dfn>
:: This [=task source=] is used for tasks scheduled through {{Scheduler/postTask()}}.

Scheduler Task Algorithms {#sec-scheduler-task-algorithms}
---------------------

<div algorithm>
  A [=scheduler task=] |t1| is <dfn for="scheduler task">older than</dfn>
  [=scheduler task=] |t2| if |t1|'s [=scheduler task/enqueue order=] less than |t2|'s
  [=scheduler task/enqueue order=].
</div>


Scheduler Task Queue Algorithms {#sec-scheduler-task-queue-algorithms}
---------------------

<div algorithm>
  To <dfn lt="create a scheduler task queue|creating a scheduler task queue">create a scheduler task queue</dfn>
  with {{TaskPriority}} |priority|:

  1. Let |queue| be a new [=scheduler task queue=].
  1. Set |queue|'s [=scheduler task queue/priority=] to |priority|.
  1. Set |queue|'s [=scheduler task queue/tasks=] to a new [=set=].
  1. Return |queue|.
</div>

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
</div>

Issue: Should we refactor the event loop task creation code and remove the duplicatation?

<div algorithm>
  To <dfn for="scheduler task queue">remove</dfn> [=scheduler task=] |task| from
  [=scheduler task queue=] |queue|, [=set/remove=] |task| from |queue|'s
  [=scheduler task queue/tasks=].
</div>


Scheduler Algorithms {#sec-scheduler-algorithms}
---------------------

### Selecting the Task Queue ### {#sec-scheduler-alg-selecting-tq}

<div algorithm="select the scheduler task queue">
  To <dfn lt="select the scheduler task queue|selecting the scheduler task queue">select the scheduler task queue</dfn>
  for a {{Scheduler}} |scheduler| given ({{TaskSignal}} or {{AbortSignal}}) |signal|, and a {{TaskPriority}} |priority|:

  1. If |priority| is null and |signal| is not null and |signal| is a {{TaskSignal}}, then
    1. If |scheduler|'s [=Scheduler/dynamic priority task queue map=] does not [=map/contain=] |signal|, then
      1. Let |queue| be the result of [=creating a scheduler task queue=] given |signal|'s {{TaskSignal/priority}}.
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
</div>

Issue: Link the priority change algorithm. Also, maybe change the name of this since it also
creates the task queue if needed.

### Scheduling Tasks ### {#sec-scheduler-alg-scheduling-tasks}

<div algorithm>
  The <dfn method for=Scheduler title=postTask(callback, options)>postTask(|callback|, |options|)</dfn> method steps are:

  1. Let |p| be a new promise.

  1. Let |signal| be null.
  1. If |options|["{{SchedulerPostTaskOptions/signal}}"] [=map/exists=], then set |signal| to |options|["{{SchedulerPostTaskOptions/signal}}"].
  1. If |signal| is not null and its [=AbortSignal/aborted flag=] is set, then return [=a promise rejected with=] an "{{AbortError!!exception}}" {{DOMException}}.
 
  1. Let |priority| be null.
  1. If |options|["{{SchedulerPostTaskOptions/priority}}"] [=map/exists=], then set |priority| to |options|["{{SchedulerPostTaskOptions/priority}}"].

  1. Let |queue| be the result of [=selecting the scheduler task queue=] for [=this=] given |signal| and |priority|.

  1. Let |delay| be 0.
  1. If |options|["{{SchedulerPostTaskOptions/delay}}"] [=map/exists=], then set |delay| to |options|["{{SchedulerPostTaskOptions/delay}}"].
  1. If |delay| is less than 0 then set |delay| to 0.
  1. If |delay| is equal to 0 then
    1. [=schedule a task to invoke a callback=] for [=this=] given |queue|, |signal|, |callback|, and |p|.
    1. Return p.
  1. Otherwise, return |p| and continue running this algorithm [=in parallel=].
  1. **TODO**(shaseley): Define waiting, potentially refactoring the timer spec.
  1. [=schedule a task to invoke a callback=] for [=this=] given |queue|, |signal|, |callback|, and |p|.
</div>

<div algorithm>
  To <dfn>schedule a task to invoke a callback</dfn> for {{Scheduler}}
  |scheduler| given a [=scheduler task queue=] |queue|, an {{AbortSignal}} |signal|,
  SchedulerPostTaskCallback |callback|, and promise |task result promise|:

  1. Let |global| be the [=relevant global object=] for |scheduler|.
  1. Let |document| be |global|'s <a attribute for="Window">associated <code>Document</code></a> if |global| is a {{Window}} object; otherwise null.
  1. Let |enqueue order| be |scheduler|'s [=next enqueue order=].
  1. Increment |scheduler|'s [=next enqueue order=] by 1.
  1. Let |task| be the result of [=queuing a scheduler task=] on |queue| given |enqueue order|, [=the posted task task source=], and |document|, and that performs the following steps:
    1. Let |result| be the result of [=invoking=] |callback|. If that threw an exception, then reject |task result promise| with that, otherwise resolve |task result promise| with |result|.
  1. If |signal| is not null, then <a for=AbortSignal lt=add>add the following</a> abort steps to it:
    1. [=scheduler task queue/remove=] |task| from |queue|.
    1. Reject |task result promise| with an "{{AbortError!!exception}}" {{DOMException}}.

  Issue: Parts of this need to be atomic, but how do we do that?
</div>

### Selecting the Next Task To Run ### {#sec-scheduler-alg-select-next-task}

<div algorithm="get the runnable task queues">
  To <dfn lt="get the runnable task queues|getting the runnable task queues">get the runnable task queues</dfn> for a {{Scheduler}} |scheduler|, run the following steps:

  1. Let |queues| be the result of <a for="map" lt="get the values">getting the values</a> [=Scheduler/static priority task queue map=].
  1. [=list/extend=] |queues| with the result of <a for="map" lt="get the values">getting the values</a> of |scheduler|'s [=Scheduler/dynamic priority task queue map=].
  1. [=list/remove=] from |queues| any |queue| such that |queue|'s [=scheduler task queue/tasks=] do not contain a <a for="task">runnable</a> [=scheduler task=].
  1. Return |queues|.
</div>

<div algorithm="has a runnable task">
  A {{Scheduler}} |scheduler| <dfn lt="has a runnable task|have a runnable task">has a runnable task</dfn> if the result of [=getting the runnable task queues=] for |scheduler| is non-[=list/empty=].
</div>

<div algorithm="select the task queue of the next scheduler task">
  To <dfn lt="select the task queue of the next scheduler task |selecting the task queue of the next scheduler task">select the task queue of the next scheduler task</dfn> for a {{Scheduler}} |scheduler|:

  1. Let |queues| be the result of [=getting the runnable task queues=] for |scheduler|.
  1. Let |candidate task| be null.
  1. Let |candidate queue| be null.
  1. <a for="list" lt="iterate">For each</a> |queue| of |queues|:
    1. Let |task| be the first <a for="task">runnable</a> [=scheduler task=] in |queue|'s [=scheduler task queue/tasks=].
    1. If |candidate task| is null, or  if |queue|'s [=scheduler task queue/priority=] is
       <a for="TaskPriority">greater than</a> |candidate queue|'s [=scheduler task queue/priority=], or if (|queue|'s [=scheduler task queue/priority=] equals |candidate queue|'s [=scheduler task queue/priority=] and |task| is [=scheduler task/older than=] |candidate task|) then
      1. Set |candidate task| to |task|.
      1. Set |candidate queue| to |queue|.
  1. Return |candidate queue|.
</div>


`TaskController` {#sec-pm-task-controller}
---------------------

<div algorithm>
  The <dfn constructor for="TaskController" lt="TaskController()"><code>new TaskController(|priority|)</code></dfn> constructor steps are:

  1. Let |signal| be a new {{TaskSignal}} object.
  1. Set |signal|'s <a for=TaskSignal>priority</a> to |priority|.
  1. [=Construct an AbortController=] given |signal|.

  Issue: Do we need to indicate that priority is optional, or is the IDL sufficient?
</div>

The <dfn attribute for="TaskController">signal</dfn> getter steps are to return [=this=]'s <a for=AbortController>signal</a>.

The <dfn method for=TaskController><code>setPriority(|priority|)</code></dfn>
method steps are to <a for=TaskSignal>signal priority change</a> on [=this=]'s
<a for=AbortController>signal</a> given |priority|.

`TaskSignal` {#sec-pm-task-signal}
---------------------

The <dfn attribute for="TaskSignal">priority</dfn> getter steps are to return [=this=]'s <a for=TaskSignal>priority</a>.

<div algorithm="onprioritychange">
  The <dfn attribute for=TaskSignal><code>onprioritychange</code></dfn>
  attribute is an [=event handler IDL attribute=] for the
  {{TaskSignal/onprioritychange}} [=event handler=], whose
  [=event handler event type=] is <dfn event for=TaskSignal>prioritychange</dfn>
</div>

<div algorithm>
  To <dfn for="TaskSignal">add a priority change algorithm</dfn> |algorithm| to a
  {{TaskSignal}} object |signal|, [=set/append=] |algorithm| to |signal|'s
  {{TaskSignal/priority change algorithms}}.
</div>

<div algorithm>
  To <dfn for="TaskSignal">signal priority change</dfn> on a {{TaskSignal}}
  object |signal|, given a {{TaskPriority}} |priority|, run these steps:

  1. If |signal|'s {{TaskSignal/priority changing}} flag is set, then [=exception/throw=] a {{NotAllowedError!!exception}}
     {{DOMException}} with {{DOMException/message}} set to "Cannot change priority while a priority change is in progress."
  1. If |signal|'s <a for=TaskSignal>priority</a> equals |priority| then return.
  1. Set |signal|'s {{TaskSignal/priority changing}} flag.
  1. Set |signal|'s <a for=TaskSignal>priority</a> to |priority|.
  1. <a for="list" lt="iterate">For each</a> |algorithm| of |signal|'s {{TaskSignal/priority change algorithms}}, run |algorithm|.
  1. [=Fire an event=] named {{TaskSignal/prioritychange}} at |signal|.
  1. Unset |signal|'s {{TaskSignal/priority changing}} flag.

  Issue: We should consider subclassing Event so we can include a previousPriority attribute (<a href=https://github.com/WICG/scheduling-apis/issues/21>(GH Issue)</a>).
</div>

Modifications to the HTML Standard {#sec-patches-html}
---------------------

### `WindowOrWorkerGlobalScope` ### {#sec-patches-html-windoworworkerglobalscope}

Each object implementing the {{WindowOrWorkerGlobalScope}} mixin has a corresponding <dfn for="WindowOrWorkerGlobalScope">task scheduler</dfn>, which is initialized as a new {{Scheduler}}.

<pre class='idl'>
  partial interface mixin WindowOrWorkerGlobalScope {
    readonly attribute Scheduler scheduler;
  };
</pre>

The <dfn attribute for="WindowOrWorkerGlobalScope">scheduler</dfn> attribute's getter steps are to return [=this=]'s [=WindowOrWorkerGlobalScope/task scheduler=].


### <a href="https://html.spec.whatwg.org/multipage/webappapis.html#definitions-3">Event loop: definitions</a> ### {#html-html-event-loop-definitions}

Replace: For each [=event loop=], every [=task source=] must be associated with a specific [=task queue=].

With: For each [=event loop=], every [=task source=] that is not a [=scheduler task source=] must be associated with a specific [=task queue=].

### <a href="https://html.spec.whatwg.org/multipage/webappapis.html#event-loop-processing-model">Event loop: processing model</a> ### {#html-event-loop}

Add the following steps to the event loop processing steps, before step 1:

  1. Let |queues| be the [=set=] of the [=event loop=]'s [=task queues=] that
     contain at least one <a for="task">runnable</a> <a for="/">task</a>.
  1. Let |schedulers| be the [=set=] of all {{Scheduler}} objects whose
     [=relevant agent's=] [=event loop=] is this event loop and that [=have a runnable task=].
  1. If |schedulers| and |queues| are both [=list/empty=], skip to the <code>microtasks</code> step below.

Modify step 1 to read:

  1. Let <code>taskQueue</code> be one of the following:
    1. If |queues| is not [=list/empty=], one of [=task queues=] in |queues|,
       chosen in an [=implementation-defined=] manner.
    1. If |schedulers| is not [=list/empty=], the result of running the
       [=select the task queue of the next scheduler task=] from one of the {{Scheduler}}s
       in |schedulers|, chosen in an [=implementation-defined=] manner.

Modifications to the DOM Standard {#sec-patches-dom}
---------------------

### `Abortcontroller` ### {#sec-patches-dom-abort-controller}

{{TaskController}} extends {{AbortController}} and needs a way to change set the
associated {{AbortController/signal}}, which is created in {{AbortController}}'s
{{AbortController/constructor()}}. We achieve this by adding an internal
construction algorithm that takes an {{AbortSignal}} argument.

Add the following algorithm to the [Interface AbortController section](https://dom.spec.whatwg.org/#interface-abortcontroller):

<div algorithm>
  To <dfn>construct an AbortController</dfn>, given an {{AbortSignal}} |signal|:

  1. Set [=this's=] <a for=AbortController>signal</a> to |signal|.
</div>

Modify {{AbortController}}'s {{AbortController()}} algorithm to be:

<div algorithm="new AbortController">
  1. [=Construct an AbortController=] given a new {{AbortSignal}} object.
</div>
