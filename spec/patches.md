# Modifications to Other Standards # {#sec-patches}

## The HTML Standard ## {#sec-patches-html}

### `WindowOrWorkerGlobalScope` ### {#sec-patches-html-windoworworkerglobalscope}

Each object implementing the {{WindowOrWorkerGlobalScope}} mixin has a corresponding
<dfn for="WindowOrWorkerGlobalScope">scheduler</dfn>, which is initialized as a new {{Scheduler}}.

<pre class='idl'>
  partial interface mixin WindowOrWorkerGlobalScope {
    [Replaceable] readonly attribute Scheduler scheduler;
  };
</pre>

The <dfn attribute for="WindowOrWorkerGlobalScope">scheduler</dfn> attribute's getter steps are to
return [=this=]'s [=WindowOrWorkerGlobalScope/scheduler=].

### <a href="https://html.spec.whatwg.org/multipage/webappapis.html#definitions-3">Event loop: definitions</a> ### {#sec-patches-html-event-loop-definitions}

Replace: For each [=event loop=], every [=task source=] must be associated with a specific [=task
queue=].

With: For each [=event loop=], every [=task source=] that is not a [=scheduler task source=] must be
associated with a specific [=task queue=].

Add: An [=event loop=] has a numeric <dfn for="event loop">next enqueue order</dfn> which is
initialized to 1.

Note: The [=event loop/next enqueue order=] is a strictly increasing number that is used to
determine task execution order across [=scheduler task queues=] of the same {{TaskPriority}} across
all {{Scheduler}}s associated with the same [=event loop=]. A timestamp would also suffice as long
as it is guaranteed to be strictly increasing and unique.

Add: An [=event loop=] has a <dfn for="event loop">current scheduling state</dfn> (a [=scheduling
state=] or null), which is initialized to null.

### <a href="https://html.spec.whatwg.org/multipage/webappapis.html#event-loop-processing-model">Event loop: processing model</a> ### {#sec-patches-html-event-loop-processing}

Add the following steps to the event loop processing steps, before step 2:

  1. Let |queues| be the [=set=] of the [=event loop=]'s [=task queues=] that contain at least one
     [=task/runnable=] [=task=].
  1. Let |schedulerQueue| be the result of [=selecting the next scheduler task queue from all
     schedulers=].

Modify step 2 to read:

  1. If |schedulerQueue| is not null or |queues| is not [=list/empty=]:

Modify step 2.1 to read:

  1. Let |taskQueue| be one of the following, chosen in an [=implementation-defined=] manner:
    * If |queues| is not [=list/empty=], one of the [=task queues=] in |queues|, chosen in an
      [=implementation-defined=] manner.
    * |schedulerQueue|'s [=scheduler task queue/tasks=], if |schedulerQueue| is not null.

Note: the HTML specification enables per-[=task source=] prioritization by making the selection of
the next [=task=]'s [=task queue=] in the event loop processing steps [=implementation-defined=].
Similarly, this specification makes selecting between the next {{Scheduler}} task and the next task
from an [=event loop=]'s [=task queues=] [=implementation-defined=], which provides UAs with the
most scheduling flexibility.
<br/><br/>
But the intent of this specification is that the {{TaskPriority}} of {{Scheduler}} tasks would
influence the event loop priority. Specifically, "{{TaskPriority/background}}" tasks and
continuations are typically considered less important than most other event loop tasks, and
"{{TaskPriority/user-blocking}}" tasks and "{{TaskPriority/user-visible}}" and
"{{TaskPriority/user-blocking}}" continuations are typically considered to be more important.
<br/><br/>
One strategy is to run {{Scheduler}} tasks with an [=scheduler task queue/effective priority=] of 3
or higher with an elevated priority, e.g. lower than input, rendering, and other <em>urgent</em>
work, but higher than most other [=task sources=]. {{Scheduler}} tasks with an [=scheduler task
queue/effective priority=] of 0 or 1 ("{{TaskPriority/background}}") could be run only when no other
tasks in an [=event loop=]'s [=task queues=] are [=task/runnable=], and {{Scheduler}} tasks with an
[=scheduler task queue/effective priority=] of 2 ("{{TaskPriority/user-visible}}" tasks) could be
scheduled like other scheduling-related [=task sources=], e.g. the [=timer task source=].

Issue: The |taskQueue| in this step will either be a [=set=] of [=tasks=] or a [=set=] of
[=scheduler tasks=]. The steps that follow only [=set/remove=] an [=set/item=], so they are
*roughly* compatible. Ideally, there would be a common task queue interface that supports a `pop()`
method that would return a plain [=task=], but that would involve a fair amount of refactoring.

### <a href="https://html.spec.whatwg.org/multipage/webappapis.html#hostmakejobcallback">HostMakeJobCallback(callable)</a> ### {#sec-patches-html-hostmakejobcallback}

Add the following before step 5:

  1. Let |event loop| be <var ignore=''>incumbent settings<var>'s
     [=environment settings object/realm=]'s [=realm/agent=]'s [=agent/event loop=].
  1. Let |state| be |event loop|'s [=event loop/current scheduling state=].

Modify step 5 to read:

 1. Return the <span>JobCallback Record</span> { \[[Callback]]: <var ignore=''>callable</var>,
    \[[HostDefined]]: { \[[IncumbentSettings]]: <var ignore=''>incumbent settings</var>,
    \[[ActiveScriptContext]]: <var ignore=''>script execution context</var>,
    \[[SchedulingState]]: |state| } }.

### <a href="https://html.spec.whatwg.org/multipage/webappapis.html#hostcalljobcallback">HostCallJobCallback(callback, V, argumentsList)</a> ### {#sec-patches-html-hostcalljobcallback}

Add the following steps before step 5:

  1. Let |event loop| be <var ignore=''>incumbent settings<var>'s
     [=environment settings object/realm=]'s [=realm/agent=]'s [=agent/event loop=].
  1. Set |event loop|'s [=event loop/current scheduling state=] to
     <var ignore=''>callback</var>.\[[HostDefined]].\[[SchedulingState]].

Add the following after step 7:

  1. Set |event loop|'s [=event loop/current scheduling state=] to null.

## <a href="https://w3c.github.io/requestidlecallback/">`requestIdleCallback()`</a> ## {#sec-patches-requestidlecallback}

### <a href="https://w3c.github.io/requestidlecallback/#invoke-idle-callbacks-algorithm">Invoke idle callbacks algorithm</a> ### {#sec-patches-invoke-idle-callbacks}

Add the following step before step 3.3:

  1. Let |realm| be the [=relevant realm=] for <var ignore=''>window</var>.
  1. Let |state| be a new [=scheduling state=].
  1. Set |state|'s [=scheduling state/priority source=] to the result of [=creating a fixed priority
     unabortable task signal=] given "{{TaskPriority/background}}" and |realm|.
  1. Let |event loop| be |realm|'s [=realm/agent=]'s [=agent/event loop=].
  1. Set |event loop|'s [=event loop/current scheduling state=] to |state|.

Add the following after step 3.3:

  1. Set |event loop|'s [=event loop/current scheduling state=] to null.
