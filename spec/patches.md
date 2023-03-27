Modifications to Other Standards {#sec-patches}
=====================

The HTML Standard {#sec-patches-html}
---------------------

### `WindowOrWorkerGlobalScope` ### {#sec-patches-html-windoworworkerglobalscope}

Each object implementing the {{WindowOrWorkerGlobalScope}} mixin has a
corresponding <dfn for="WindowOrWorkerGlobalScope">scheduler</dfn>, which
is initialized as a new {{Scheduler}}.

<pre class='idl'>
  partial interface mixin WindowOrWorkerGlobalScope {
    [Replaceable] readonly attribute Scheduler scheduler;
  };
</pre>

The <dfn attribute for="WindowOrWorkerGlobalScope">scheduler</dfn> attribute's
getter steps are to return [=this=]'s [=WindowOrWorkerGlobalScope/scheduler=].


### <a href="https://html.spec.whatwg.org/multipage/webappapis.html#definitions-3">Event loop: definitions</a> ### {#sec-patches-html-event-loop-definitions}

Replace: For each [=event loop=], every [=task source=] must be associated with
a specific [=task queue=].

With: For each [=event loop=], every [=task source=] that is not a
[=scheduler task source=] must be associated with a specific [=task queue=].

An [=event loop=] object has a numeric <dfn for="event loop">next enqueue order</dfn>, which is
is initialized to 1.

Note: The [=event loop/next enqueue order=] is a strictly increasing number that is used to
determine task execution order across [=scheduler task queues=] of the same {{TaskPriority}} across
all {{Scheduler}}s associated with the same [=event loop=]. A timestamp would also suffice as long
as it is guaranteed to be strictly increasing and unique.

### <a href="https://html.spec.whatwg.org/multipage/webappapis.html#event-loop-processing-model">Event loop: processing model</a> ### {#sec-patches-html-event-loop-processing}

Add the following steps to the event loop processing steps, before step 1:

  1. Let |queues| be the [=set=] of the [=event loop=]'s [=task queues=] that
     contain at least one <a for="task">runnable</a> <a for="/">task</a>.
  1. Let |scheduler queue| be the result of
     [=selecting the next scheduler queue from all schedulers=] given the [=event loop=].
  1. If |scheduler queue| is null and |queues| is [=list/empty=], skip to the
     <code>microtasks</code> step below.

Modify step 1 to be the following steps:
  1. If |scheduler queue| is not null:
    1. If |scheduler queue|'s [=scheduler task queue/priority=] is {{TaskPriority/user-blocking}}
       and |queues| is not [=list/empty=], then [=set/remove=] from |queues| any [=task queue=]
       whose [=task source=] is in «[=timer task source=], [=posted message task source=]».
    1. If |scheduler queue|'s [=scheduler task queue/priority=] is {{TaskPriority/background}}, set
       |scheduler queue| to null.
  1. Let |taskQueue| be one of the following, chosen in an [=implementation-defined=] manner:
    * If |queues| is not [=list/empty=], one of the [=task queues=] in |queues|, chosen in an
      [=implementation-defined=] manner.
    * |scheduler queue|'s [=scheduler task queue/tasks=], if |scheduler queue| is not null.


Note: This section defines the integration of {{Scheduler}} tasks and the [=event loop=].
<br/><br/>
{{TaskPriority/background}} tasks will only run if no other tasks are <a for="task">runnable</a>.
<br/><br/>
{{TaskPriority/user-visible}} tasks are meant to be scheduled in a similar way to existing
scheduling mechanisms, specifically {{WindowOrWorkerGlobalScope/setTimeout()|setTimeout(0)}} and
same-window {{Window/postMessage(message, options)|postMessage()}}. While the relative priority of
these is unspecified, {{TaskPriority/user-blocking}} tasks are specified to have a higher priority
in the event loop than these scheduling methods.
<br/><br/>
The intention is for {{TaskPriority/user-blocking}} tasks to be given an increased priority in the
[=event loop=], reflecting the developer's indication of the task importance. UAs have flexibility
to prioritize between {{TaskPriority/user-blocking}} tasks other task sources and, but are
encouraged to give some increased priority to the former. One possible strategy is to give
{{TaskPriority/user-blocking}} tasks priority over everything except user input and rendering (to
ensure the UI remains responsive).

Issue: The |taskQueue| in this step will either be a [=set=] of [=tasks=] or a
[=set=] of [=scheduler tasks=]. The steps that follow only [=set/remove=] an
[=set/item=], so they are *roughly* compatible. Ideally, there would be a
common task queue interface that supports a `pop()` method that would return a
plain [=task=], but that would invlove a fair amount of refactoring.
