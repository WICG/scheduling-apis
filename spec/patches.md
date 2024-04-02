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

Issue: The |taskQueue| in this step will either be a [=set=] of [=tasks=] or a [=set=] of
[=scheduler tasks=]. The steps that follow only [=set/remove=] an [=set/item=], so they are
*roughly* compatible. Ideally, there would be a common task queue interface that supports a `pop()`
method that would return a plain [=task=], but that would involve a fair amount of refactoring.
