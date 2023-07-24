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

### <a href="https://html.spec.whatwg.org/multipage/webappapis.html#event-loop-processing-model">Event loop: processing model</a> ### {#sec-patches-html-event-loop-processing}

Add the following steps to the event loop processing steps, before step 1:

  1. Let |queues| be the [=set=] of the [=event loop=]'s [=task queues=] that contain at least one
     <a for="task">runnable</a> <a for="/">task</a>.
  1. Let |schedulers| be the [=set=] of all {{Scheduler}} objects whose [=relevant agent's=]
     [=agent/event loop=] is this event loop and that [=have a runnable task=].
  1. If |schedulers| and |queues| are both [=list/empty=], skip to the <code>microtasks</code> step
     below.

Modify step 1 to read:

  1. Let |taskQueue| be one of the following, chosen in an [=implementation-defined=] manner:
    * If |queues| is not [=list/empty=], one of the [=task queues=] in |queues|, chosen in an
      [=implementation-defined=] manner.
    * If |schedulers| is not [=list/empty=], the result of [=selecting the task queue of the next
      scheduler task=] from one of the {{Scheduler}}s in |schedulers|, chosen in an
      [=implementation-defined=] manner.

Issue: The |taskQueue| in this step will either be a [=set=] of [=tasks=] or a [=set=] of
[=scheduler tasks=]. The steps that follow only [=set/remove=] an [=set/item=], so they are
*roughly* compatible. Ideally, there would be a common task queue interface that supports a `pop()`
method that would return a plain [=task=], but that would invlove a fair amount of refactoring.
