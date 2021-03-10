Controlling Tasks {#sec-controlling-tasks}
=====================

The `TaskController` Interface {#sec-task-controller}
---------------------

<pre class='idl'>
  [Exposed=(Window,Worker)] interface TaskController : AbortController {
    constructor(optional TaskPriority priority = "user-visible");

    [SameObject] readonly attribute TaskSignal signal;

    undefined setPriority(TaskPriority priority);
  };
</pre>

Issue: Note that this is different from the current implemenation (signal
property), but I have a patch for this that works **if** this is what we want
to do here.

The <dfn attribute for="TaskController">signal</dfn> getter steps are to return [=this=]'s <a for=AbortController>signal</a>.

<div algorithm>
  The <dfn constructor for="TaskController" lt="TaskController()"><code>new TaskController(|priority|)</code></dfn> constructor steps are:

  1. Let |signal| be a new {{TaskSignal}} object.
  1. Set |signal|'s <a for=TaskSignal>priority</a> to |priority|.
  1. [=Construct an AbortController=] given |signal|.

  Issue: Do we need to indicate that priority is optional, or is the IDL sufficient?
</div>

The <dfn method for=TaskController><code>setPriority(|priority|)</code></dfn>
method steps are to <a for=TaskSignal>signal priority change</a> on [=this=]'s
<a for=AbortController>signal</a> given |priority|.


The `TaskSignal` Interface {#sec-task-signal}
---------------------

<pre class='idl'>
  [Exposed=(Window, Worker)] interface TaskSignal : AbortSignal {
    readonly attribute TaskPriority priority;
    attribute EventHandler onprioritychange;
  };
</pre>

A {{TaskSignal}} object has an associated {{TaskPriority}}
<dfn for=TaskSignal>priority</dfn>.

A {{TaskSignal}} object has an associated <dfn attribute for=TaskSignal>priority changing</dfn>
flag. It is unset unless otherwise specified.

A {{TaskSignal}} object has associated <dfn attribute for=TaskSignal>priority change algorithms</dfn>,
which is a [=set=] of algorithms which are to be executed when its
{{TaskSignal/priority changing}} flag is set. Unless specified otherwise, its value is
the empty set.

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
