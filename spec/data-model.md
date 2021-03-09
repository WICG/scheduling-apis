Data Model {#sec-data-model}
=====================

Scheduler Tasks {#sec-dm-scheduler-tasks}
---------------------

A <dfn>scheduler task</dfn> is a <a for="/">task</a> with an additional numeric
<dfn for="scheduler task">enqueue order</dfn> [=struct/item=], initially set to 0.

Scheduler Task Queues {#sec-dm-scheduler-task-queues}
---------------------

A <dfn>scheduler task queue</dfn> is formally a [=struct=] with the following [=struct/items=]:

: <dfn for="scheduler task queue">priority</dfn>
:: A {{TaskPriority}}.
: <dfn for="scheduler task queue">tasks</dfn>
:: A [=set=] of [=scheduler tasks=].

Scheduler {#sec-dm-scheduler}
---------------------

A {{Scheduler}} object has an associated <dfn for="Scheduler">static priority
task queue map</dfn>, which is a [=map=] of [=scheduler task queues=] indexed
by {{TaskPriority}}. This map is empty unless otherwise stated.

A {{Scheduler}} object has an associated <dfn for="Scheduler">dynamic priority
task queue map</dfn>, which is a [=map=] of [=scheduler task queues=] indexed
by {{TaskSignal}}. This map is empty unless otherwise stated.

A {{Scheduler}} object has a numeric <dfn for="Scheduler">next enqueue
order</dfn> which is initialized to 1.

Note: The [=Scheduler/next enqueue order=] is a strictly increasing number that
is used to determine task execution order across [=scheduler task queues=] of the
same {{TaskPriority}} within the same {{Scheduler}}. A logically equivalent
alternative would be to place the [=Scheduler/next enqueue order=] on the
[=event loop=], since the only requirements are that the number be strictly
increasing and never used more than once within a {{Scheduler}}.
