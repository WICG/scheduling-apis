# Controlling Tasks # {#sec-controlling-tasks}

Tasks scheduled through the {{Scheduler}} interface can be controlled with a {{TaskController}} by
passing the {{TaskSignal}} provided by {{AbortController/signal|controller.signal}} as the
{{SchedulerPostTaskOptions/signal|option}} when calling {{Scheduler/postTask()}}. The
{{TaskController}} interface supports aborting and changing the priority of a task or group of
tasks.

## The `TaskPriorityChangeEvent` Interface ## {#sec-task-priority-change-event}

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
    <p>Returns the {{TaskPriority}} of the corresponding {{TaskSignal}} prior to this
    `prioritychange` event.

    <p>The new {{TaskPriority}} can be read with `event.target.priority`.
  </dd>
</dl>

The <dfn attribute for=TaskPriorityChangeEvent>previousPriority</dfn> getter steps are to return the
value that the corresponding attribute was initialized to.

## The `TaskController` Interface ## {#sec-task-controller}

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

Note: {{TaskController}}'s {{AbortController/signal}} getter, which is inherited from
{{AbortController}}, returns a {{TaskSignal}} object.

<dl class="domintro non-normative">
  <dt><code>controller = new {{TaskController/TaskController()|TaskController}}( |init| )</code>
  <dd>
    <p> Returns a new {{TaskController}} whose {{AbortController/signal}} is set to a newly created
    {{TaskSignal}} with its {{TaskSignal/priority}} initialized to |init|'s
    {{TaskControllerInit/priority}}.
  </dd>

  <dt><code>controller . {{TaskController/setPriority()|setPriority}}( |priority| )</code>
  <dd>
    <p>Invoking this method will change the associated {{TaskSignal}}'s [=TaskSignal/priority=],
    signal the priority change to any observers, and cause `prioritychange` events to be dispatched.
  </dd>
</dl>

<div algorithm>
  The <dfn constructor for="TaskController" lt="TaskController()"><code>new TaskController(|init|)</code></dfn>
  constructor steps are:

  1. Let |signal| be a new {{TaskSignal}} object.
  1. Set |signal|'s [=TaskSignal/priority=] to |init|["{{TaskControllerInit/priority}}"].
  1. Set [=this's=] [=AbortController/signal=] to |signal|.
</div>

The <dfn method for=TaskController><code>setPriority(|priority|)</code></dfn> method steps are to
[=TaskSignal/signal priority change=] on [=this=]'s [=AbortController/signal=] given |priority|.

## The `TaskSignal` Interface ## {#sec-task-signal}

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

Note: {{TaskSignal}} inherits from {{AbortSignal}} and can be used in APIs that accept an
{{AbortSignal}}. Additionally, {{Scheduler/postTask()}} accepts an {{AbortSignal}}, which can be
useful if dynamic prioritization is not needed.

<dl class="domintro non-normative">
  <dt><code>TaskSignal . <a method for=TaskSignal lt="any(signals, init)">any</a>(|signals|, |init|)</code>
  <dd>Returns a {{TaskSignal}} instance which will be aborted if any of |signals| is aborted. Its
  [=AbortSignal/abort reason=] will be set to whichever one of |signals| caused it to be aborted.
  The signal's [=TaskSignal/priority=] will be determined by |init|'s {{TaskSignalAnyInit/priority}},
  which can either be a fixed {{TaskPriority}} or a {{TaskSignal}}, in which case the new signal's
  [=TaskSignal/priority=] will change along with this signal.

  <dt><code>signal . {{TaskSignal/priority}}</code>
  <dd><p>Returns the {{TaskPriority}} of the signal.
</dl>

A {{TaskSignal}} object has an associated <dfn for=TaskSignal>priority</dfn> (a {{TaskPriority}}).

A {{TaskSignal}} object has an associated <dfn for=TaskSignal>priority changing</dfn> (a
[=boolean=]), which is intially set to false.

A {{TaskSignal}} object has associated <dfn for=TaskSignal>priority change algorithms</dfn>,
(a [=set=] of algorithms that are to be executed when its [=TaskSignal/priority changing=] value
is true), which is initially empty.

A {{TaskSignal}} object has an associated <dfn for=TaskSignal>source signal</dfn> (a weak refernece
to a {{TaskSignal}} that the object is dependent on for its [=TaskSignal/priority=]), which is
initially null.

A {{TaskSignal}} object has associated <dfn for=TaskSignal>dependent signals</dfn> (a weak [=set=]
of {{TaskSignal}} objects that are dependent on the object for their [=TaskSignal/priority=]), which
is initially empty.

A {{TaskSignal}} object has an associated <dfn for=TaskSignal>dependent</dfn> (a boolean), which is
initially false.

<hr>

The <dfn attribute for="TaskSignal">priority</dfn> getter steps are to return [=this=]'s
[=TaskSignal/priority=].

The <dfn attribute for=TaskSignal><code>onprioritychange</code></dfn> attribute is an [=event
handler IDL attribute=] for the `onprioritychange` [=event handler=], whose [=event handler event
type=] is <dfn event for=TaskSignal>prioritychange</dfn>.

The static <dfn method for=TaskSignal><code>any(|signals|, |init|)</code></dfn> method steps are to
return the result of [=creating a dependent task signal=] from |signals|, |init|, and the
[=current realm=].

<hr>

A {{TaskSignal}} <dfn for=TaskSignal lt="has fixed priority|have fixed priority">has fixed priority</dfn>
if it is a [=TaskSignal/dependent=] signal with a null [=TaskSignal/source signal=].

To <dfn for="TaskSignal">add a priority change algorithm</dfn> |algorithm| to a {{TaskSignal}}
object |signal|, [=set/append=] |algorithm| to |signal|'s [=TaskSignal/priority change algorithms=].

<div algorithm>
  To <dfn>create a dependent task signal</dfn> from a [=list=] of {{AbortSignal}} objects |signals|,
  a {{TaskSignalAnyInit}} |init|, and a |realm|:

  1. Let |resultSignal| be the result of <a for=AbortSignal>creating a dependent signal</a> from
     |signals| using the {{TaskSignal}} interface and |realm|.
  1. Set |resultSignal|'s [=TaskSignal/dependent=] to true.
  1. If |init|["{{TaskSignalAnyInit/priority}}"] is a {{TaskPriority}}, then:
    1. Set |resultSignal|'s [=TaskSignal/priority=] to |init|["{{TaskSignalAnyInit/priority}}"].
  1. Otherwise:
    1. Let |sourceSignal| be |init|["{{TaskSignalAnyInit/priority}}"].
    1. Set |resultSignal|'s [=TaskSignal/priority=] to |sourceSignal|'s [=TaskSignal/priority=].
    1. If |sourceSignal| does not [=TaskSignal/have fixed priority=], then:
      1. If |sourceSignal|'s [=TaskSignal/dependent=] is true, then set |sourceSignal| to
         |sourceSignal|'s [=TaskSignal/source signal=].
      1. Assert: |sourceSignal| is not [=TaskSignal/dependent=].
      1. Set |resultSignal|'s [=TaskSignal/source signal=] to a weak reference to |sourceSignal|.
      1. [=set/Append=] |resultSignal| to |sourceSignal|'s [=TaskSignal/dependent signals=].
  1. Return |resultSignal|.
</div>

<div algorithm>
  To <dfn for="TaskSignal">signal priority change</dfn> on a {{TaskSignal}} object |signal|, given a
  {{TaskPriority}} |priority|:

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
  1. [=list/iterate|For each=] |dependentSignal| of |signal|'s [=TaskSignal/dependent signals=],
     [=TaskSignal/signal priority change=] on |dependentSignal| with |priority|.
  1. Set |signal|'s [=TaskSignal/priority changing=] to false.
</div>

<div algorithm>
  To <dfn>create a fixed priority unabortable task signal</dfn> given {{TaskPriority}} |priority|
  and a |realm|.

  1. Let |init| be a new {{TaskSignalAnyInit}}.
  1. Set |init|["{{TaskSignalAnyInit/priority}}"] to |priority|.
  1. Return the result of [=creating a dependent task signal=] from « », |init|, and |realm|.
</div>

### Garbage Collection ### {#sec-task-signal-garbage-collection}

A [=TaskSignal/dependent=] {{TaskSignal}} object must not be garbage collected while its
[=TaskSignal/source signal=] is non-null and it has registered event listeners for its
{{TaskSignal/prioritychange}} event or its [=TaskSignal/priority change algorithms=] is non-empty.

## Examples ## {#sec-controlling-tasks-examples}

**TODO**(shaseley): Add examples.
