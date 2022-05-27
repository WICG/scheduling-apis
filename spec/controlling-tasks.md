Controlling Tasks {#sec-controlling-tasks}
=====================

Tasks scheduled through the {{Scheduler}} interface can be controlled with a
{{TaskController}} by passing the {{TaskSignal}} provided by
{{AbortController/signal|controller.signal}} as the
{{SchedulerPostTaskOptions/signal|option}} when calling {{Scheduler/postTask()}}.
The {{TaskController}} interface supports aborting and changing the priority of
a task or group of tasks.

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

<dl class="domintro non-normative">
  <dt><code>event . {{TaskPriorityChangeEvent/previousPriority}}</code></dt>
  <dd>
    <p>Returns the {{TaskPriority}} of the corresponding {{TaskSignal}} prior to
    this `prioritychange` event.

    <p>The new {{TaskPriority}} can be read with `event.target.priority`.
  </dd>
</dl>

The <dfn attribute for=TaskPriorityChangeEvent>previousPriority</dfn> getter
steps are to return the value that the corresponding attribute was initialized
to.

The `TaskController` Interface {#sec-task-controller}
---------------------

<pre class='idl'>
  dictionary TaskControllerInit {
    TaskPriority priority = "user-visible";
  };

  [Exposed=(Window,Worker)]
  interface TaskController : AbortController {
    constructor(optional TaskControllerInit init = {});

    undefined setPriority(TaskPriority priority);
  };
</pre>

Note: {{TaskController}}'s {{AbortController/signal}} getter, which is
inherited from {{AbortController}}, returns a {{TaskSignal}} object.

<dl class="domintro non-normative">
  <dt><code>controller = new {{TaskController/TaskController()|TaskController}}( |init| )</code>
  <dd>
    <p> Returns a new {{TaskController}} whose {{AbortController/signal}} is
    set to a newly created {{TaskSignal}} with its {{TaskSignal/priority}}
    initialized to |init|'s {{TaskControllerInit/priority}}.
  </dd>

  <dt><code>controller . {{TaskController/setPriority()|setPriority}}( |priority| )</code>
  <dd>
    <p>Invoking this method will change the associated {{TaskSignal}}'s
    [=TaskSignal/priority=], signal the priority change to any observers, and
    cause `prioritychange` events to be dispatched.
  </dd>
</dl>

<div algorithm>
  The <dfn constructor for="TaskController" lt="TaskController()"><code>new TaskController(|init|)</code></dfn>
  constructor steps are:

  1. Let |signal| be a new {{TaskSignal}} object.
  1. Set |signal|'s [=TaskSignal/priority=] to |init|["{{TaskControllerInit/priority}}"].
  1. Set [=this's=] [=AbortController/signal=] to |signal|.
</div>

The <dfn method for=TaskController><code>setPriority(|priority|)</code></dfn>
method steps are to [=TaskSignal/signal priority change=] on [=this=]'s
[=AbortController/signal=] given |priority|.

The `TaskSignal` Interface {#sec-task-signal}
---------------------

<pre class='idl'>
  dictionary TaskSignalAnyInit {
    (TaskPriority or TaskSignal) priority = "user-visible";
  };

  [Exposed=(Window, Worker)]
  interface TaskSignal : AbortSignal {
    [NewObject] static TaskSignal _any(sequence&lt;AbortSignal> signals, optional TaskSignalAnyInit init = {});

    readonly attribute TaskPriority priority;

    attribute EventHandler onprioritychange;
  };
</pre>

Note: {{TaskSignal}} inherits from {{AbortSignal}} and can be used in APIs that
accept an {{AbortSignal}}. Additionally, {{Scheduler/postTask()}} accepts an
{{AbortSignal}}, which can be useful if dynamic prioritization is not needed.

<dl class="domintro non-normative">
  <dt><code>TaskSignal . <a method for=TaskSignal lt="any(signals, init)">any</a>(|signals|, |init|)</code>
  <dd>Returns a {{TaskSignal}} instance which will be aborted if any of |signals| is aborted. Its
  [=AbortSignal/abort reason=] will be set to whichever one of |signals| cause it to be aborted. The
  signal's [=TaskSignal/priority=] will be determined by |init|'s {{TaskSignalAnyInit/priority}},
  which can either be a fixed {{TaskPriority}} or a {{TaskSignal}}, in which case the new signal's
  [=TaskSignal/priority=] will change along with this signal.

  <dt><code>signal . {{TaskSignal/priority}}</code>
  <dd><p>Returns the {{TaskPriority}} of the signal.
</dl>

A {{TaskSignal}} object has an associated {{TaskPriority}}
<dfn for=TaskSignal>priority</dfn>.

A {{TaskSignal}} object has an associated <dfn for=TaskSignal>priority changing</dfn>
[=boolean=], intially set to false.

A {{TaskSignal}} object has associated <dfn for=TaskSignal>priority change algorithms</dfn>,
which is a [=set=] of algorithms, initialized to a new empty [=set=]. These
algorithms are to be executed when its [=TaskSignal/priority changing=] value
is true.

A {{TaskSignal}} object has an associated <dfn for=TaskSignal>parent signal</dfn> {{TaskSignal}},
intially set to null and stored as a weak reference. If an object's [=TaskSignal/parent signal=] is
not null, the object is dependent on its parent for its priority.

A {{TaskSignal}} object has associated <dfn for=TaskSignal>child signals</dfn>, which is a [=set=]
of {{TaskSignal}} objects, initialized to a new empty [=set=]. These signals are dependent on the
object for their priority.

A {{TaskSignal}} object has an associated <dfn for=TaskSignal>fixed priority</dfn>
[=boolean=], intially set to false.

A {{TaskSignal}} <dfn for=TaskSignal lt="has fixed priority|have fixed priority">has fixed priority</dfn>
if its [=TaskSignal/fixed priority=] is true or it is a [=AbortSignal/composite=] signal with a null
[=TaskSignal/parent signal=].

The <dfn attribute for="TaskSignal">priority</dfn> getter steps are to return
[=this=]'s [=TaskSignal/priority=].

The <dfn attribute for=TaskSignal><code>onprioritychange</code></dfn> attribute
is an [=event handler IDL attribute=] for the `onprioritychange`
[=event handler=], whose [=event handler event type=] is
<dfn event for=TaskSignal>prioritychange</dfn>.

To <dfn for="TaskSignal">add a priority change algorithm</dfn> |algorithm| to a
{{TaskSignal}} object |signal|, [=set/append=] |algorithm| to |signal|'s
[=TaskSignal/priority change algorithms=].

<div algorithm>
  The static <dfn method for=TaskSignal><code>any(|signals|, |init|)</code></dfn> method steps are:

  1. Let |resultSignal| be the result of <a for=AbortSignal>creating a composite signal</a> from
     <var>signals</var> with the {{TaskSignal}} interface.
  1. If |init|["{{TaskSignalAnyInit/priority}}"] is a {{TaskPriority}}, then:
    1. Set |resultSignal|'s [=TaskSignal/priority=] to |init|["{{TaskSignalAnyInit/priority}}"].
    1. Set |resultSignal|'s [=TaskSignal/fixed priority=] to true.
  1. Otherwise:
    1. Set |parentSignal| to |init|["{{TaskSignalAnyInit/priority}}"].
    1. Set |resultSignal|'s [=TaskSignal/priority=] to |parentSignal|'s [=TaskSignal/priority=].
    1. Set |resultSignal|'s [=TaskSignal/fixed priority=] to |parentSignal|'s
       [=TaskSignal/fixed priority=].
    1. If |parentSignal| does not [=TaskSignal/have fixed priority=], then:
      1. If |parentSignal|'s [=AbortSignal/composite=] is true, then set |parentSignal| to
         |parentSignal|'s [=TaskSignal/parent signal=].
      1. Assert: |parentSignal| is not [=AbortSignal/composite=].
      1. Set |resultSignal|'s [=TaskSignal/parent signal=] to |parentSignal|.
      1. [=set/Append=] |resultSignal| to |parentSignal|'s [=TaskSignal/child signals=].
  1. Return |resultSignal|.

  Note: [=TaskSignal/Child signals=] need to be held by strong reference as long as the parent can
  still [=TaskSignal/signal priority change=] and the child has any {{TaskSignal/prioritychange}}
  event listeners registered. A {{TaskSignal}} can no longer [=TaskSignal/signal priority change=]
  if it is the {{AbortController/signal}} of a {{TaskController}} that has been garbage collected.
</div>

<div algorithm>
  To <dfn for="TaskSignal">signal priority change</dfn> on a {{TaskSignal}}
  object |signal|, given a {{TaskPriority}} |priority|, run the following steps:

  1. If |signal|'s [=TaskSignal/priority changing=] is true, then [=exception/throw=]
     a "{{NotAllowedError!!exception}}" {{DOMException}}.
  1. If |signal|'s [=TaskSignal/priority=] equals |priority| then return.
  1. Set |signal|'s [=TaskSignal/priority changing=] to true.
  1. Let |previousPriority| be |signal|'s [=TaskSignal/priority=].
  1. Set |signal|'s [=TaskSignal/priority=] to |priority|.
  1. [=list/iterate|For each=] |algorithm| of |signal|'s
     [=TaskSignal/priority change algorithms=], run |algorithm|.
  1. [=Fire an event=] named {{TaskSignal/prioritychange}} at |signal| using
     {{TaskPriorityChangeEvent}}, with its {{TaskPriorityChangeEvent/previousPriority}}
     attribute initialized to |previousPriority|.
  1. [=list/iterate|For each=] |childSignal| of |signal|'s [=TaskSignal/child signals=],
     [=TaskSignal/signal priority change=] on |childSignal| with |priority|.
  1. Set |signal|'s [=TaskSignal/priority changing=] to false.
</div>

Examples {#sec-controlling-tasks-examples}
---------------------

**TODO**(shaseley): Add examples.
