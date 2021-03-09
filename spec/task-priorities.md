Task Priorities {#sec-task-priorities}
=====================

This spec formalizes three priorities to support scheduling tasks:

<pre class='idl'>
  enum TaskPriority {
      "user-blocking",
      "user-visible",
      "background"
  };
</pre>

{{TaskPriority/user-blocking}} is the highest priority, and is meant to be used
for tasks that are blocking the user's ability to interact with the page, such
as rendering the core experience or responding to user input.

{{TaskPriority/user-visible}} is the second highest priority, and is meant to
be used for tasks that visible to the user but not necessarily blocking user
actions, such as rendering secondary parts of the page. This is the default
priority.

{{TaskPriority/background}} is the lowest priority, and is meant to be used for
tasks that are not time-critical, such as background log processing or
initializing certain third party libraries.

Note: Tasks scheduled through a given {{Scheduler}} run in *strict priority
order*, meaning the scheduler will always run {{TaskPriority/user-blocking}}
tasks before {{TaskPriority/user-visible}} tasks, which in turn always run
before {{TaskPriority/background}} tasks.

<div algorithm>
  {{TaskPriority}} |priority1| is <dfn for="TaskPriority">greater than</dfn>
  {{TaskPriority}} |priority2| if the following steps return true:

  1. Let |priorities| be the [=map=] «[ {{TaskPriority/user-blocking}} → 2, {{TaskPriority/user-visible}} → 1, {{TaskPriority/background}} → 0 ]».
  1. Return true if |priorities|[|priority1|] is greater than |priorities|[|priority2|], otherwise false.
</div>
