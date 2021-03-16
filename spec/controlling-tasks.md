Controlling Tasks {#sec-controlling-tasks}
=====================

Tasks scheduled through the {{Scheduler}} interface can be controlled with a
{{TaskController}} by passing the associated {{TaskSignal}}
{{AbortController/signal}} as an {{SchedulerPostTaskOptions/signal|option}} to
{{Scheduler/postTask()}}. The {{TaskController}} interface supports aborting
and changing the priority of a task or group of tasks.

Note: {{TaskSignal}} inherits from {{AbortSignal}} and can be used in APIs that
accept an {{AbortSignal}}. Additionally, {{Scheduler/postTask()}} accepts an
{{AbortSignal}}, which can be useful if dynamic prioritization is not needed.

The `TaskPriorityChangeEvent` Interface {#sec-task-priority-change-event}
---------------------

<pre class='idl'>
  [Exposed=(Window, Worker)]
  interface TaskPriorityChangeEvent : Event {
    constructor(DOMString type, TaskPriorityChangeEventInit priorityChangeEventInitDict);

    readonly attribute TaskPriority previousPriority;
  };

  dictionary TaskPriorityChangeEventInit : EventInit {
    required TaskPriority previousPriority;
  };
</pre>

A {{TaskPriorityChangeEvent}} object has a <dfn for=TaskPriorityChangeEvent>previousPriority</dfn>
attribute. The {{TaskPriorityChangeEvent/previousPriority}} getter steps are to
return [=this=]'s [=TaskPriorityChangeEvent/previousPriority=].

The `TaskController` Interface {#sec-task-controller}
---------------------

<pre class='idl'>
  [Exposed=(Window,Worker)]
  interface TaskController : AbortController {
    constructor(optional TaskPriority priority = "user-visible");

    undefined setPriority(TaskPriority priority);
  };
</pre>

Note: {{TaskController}}'s {{AbortController/signal}} getter, which is
inherited from {{AbortController}}, returns a {{TaskSignal}} object.

<div algorithm>
  The <dfn constructor for="TaskController" lt="TaskController()"><code>new TaskController(|priority|)</code></dfn> constructor steps are:

  1. Let |signal| be a new {{TaskSignal}} object.
  1. Set |signal|'s <a for=TaskSignal>priority</a> to |priority|.
  1. Set [=this's=] <a for=AbortController>signal</a> to |signal|.
</div>

The <dfn method for=TaskController><code>setPriority(|priority|)</code></dfn>
method steps are to <a for=TaskSignal>signal priority change</a> on [=this=]'s
<a for=AbortController>signal</a> given |priority|.

The `TaskSignal` Interface {#sec-task-signal}
---------------------

<pre class='idl'>
  [Exposed=(Window, Worker)]
  interface TaskSignal : AbortSignal {
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

The <dfn attribute for=TaskSignal><code>onprioritychange</code></dfn> attribute
is an [=event handler IDL attribute=] for the {{TaskSignal/onprioritychange}}
[=event handler=], whose [=event handler event type=] is
<dfn event for=TaskSignal>prioritychange</dfn>.

To <dfn for="TaskSignal">add a priority change algorithm</dfn> |algorithm| to a
{{TaskSignal}} object |signal|, [=set/append=] |algorithm| to |signal|'s
{{TaskSignal/priority change algorithms}}.

<div algorithm>
  To <dfn for="TaskSignal">signal priority change</dfn> on a {{TaskSignal}}
  object |signal|, given a {{TaskPriority}} |priority|, run the following steps:

  1. If |signal|'s {{TaskSignal/priority changing}} flag is set, then [=exception/throw=] a {{NotAllowedError!!exception}}
     {{DOMException}}.
  1. If |signal|'s <a for=TaskSignal>priority</a> equals |priority| then return.
  1. Set |signal|'s {{TaskSignal/priority changing}} flag.
  1. Let |previousPriority| be |signal|'s <a for=TaskSignal>priority</a>.
  1. Set |signal|'s <a for=TaskSignal>priority</a> to |priority|.
  1. <a for="list" lt="iterate">For each</a> |algorithm| of |signal|'s {{TaskSignal/priority change algorithms}}, run |algorithm|.
  1. [=Fire an event=] named {{TaskSignal/prioritychange}} at |signal| using
     {{TaskPriorityChangeEvent}}, with its [=TaskPriorityChangeEvent/previousPriority=]
     attribute initialized to |previousPriority|.
  1. Unset |signal|'s {{TaskSignal/priority changing}} flag.
</div>

Examples {#sec-controlling-tasks-examples}
---------------------

**TODO**(shaseley): Add examples.
