Introduction {#intro}
=====================

<div class="non-normative">

*This section is non-normative.*

Scheduling can be an important developer tool for improving website
performance. Broadly speaking, there are two areas where scheduling can be
impactful: user-percieved latency and responsiveness. Scheduling can improve
user-perceived latency to the degree that lower priority work can be pushed off
in favor of higher priority work that directly impacts quality of experience.
For example, pushing off execution of certain 3P library scripts during page
load can benefit the user by getting pixels to the screen faster. The same
applies to prioritizing work associated with content within the viewport. For
script running on the main thread, long tasks can negatively affect both input
and visual responsiveness by blocking input and UI updates from running.
Breaking up these tasks into smaller pieces and scheduling the *chunks* or task
*continuations* is a proven approach that applications and framework developers
use to improve responsiveness.

Userspace schedulers typically work by providing methods to schedule tasks and
controlling when those tasks execute. Tasks usually have an associated
priority, which in large part determines when the task will run, in relation to
other tasks the scheduler controls. The scheduler typically operates by
executing tasks for some amount of time (a scheduler quantum) before yielding
control back to the browser. The scheduler resumes by scheduling a continuation
task, e.g. a call to {{WindowOrWorkerGlobalScope/setTimeout()}} or
{{Window/postMessage(message, options)|postMessage()}}.

While userspace schedulers have been successful, the situation could be
improved with a centralized browser scheduler and better scheduling primitives.
The priority system of a scheduler extends only as far as the scheduler's
reach.  A consequence of this for userspace schedulers is that the UA generally
has no knowledge of userspace task priorities. The one exception is if the
scheduler uses {{Window/requestIdleCallback()}} for some of its work, but this
is limited to the lowest priority work. The same holds if there are *multiple*
schedulers on the page, which is increasingly common. For example, an app might
be built with a framework that has a schedueler (e.g. React), do some
scheduling on its own, and even embed a feature that has a scheduler (e.g. an
embedded map). The browser is the ideal coordination point since the browser
has global information, and the event loop is responsible for running tasks.

Prioritization aside, the current primitives that userspace schedulers rely on
are not ideal for modern use cases.
{{WindowOrWorkerGlobalScope/setTimeout()|setTimeout(0)}} is the canonical way to
schedule a non-delayed task, but there are often minimum delay values (e.g. for
nested tasks) which can lead to poor performance due to increased latency. A
[well-known workaround](https://dbaron.org/log/20100309-faster-timeouts) is to
use {{Window/postMessage(message, options)|postMessage()}} or a
{{MessageChannel}}, but these APIs were not designed for scheduling, e.g. you
cannot queue callbacks. {{Window/requestIdleCallback()}} can be effective for
some use cases, but this only applies to idle tasks and does not account for
tasks whose priority can change, e.g. re-prioritizing off-screen content in
response to user input, like scrolling.

This document introduces a new interface for developers to schedule and control
prioritized tasks.  The {{Scheduler}} interface exposes a
{{Scheduler/postTask()}} method to schedule tasks, and the specification
defines a number of {{TaskPriority|TaskPriorities}} that control execution
order.  Additionally, a {{TaskController}} and its associated {{TaskSignal}}
can be used to abort scheduled tasks and control their priorities.

</div>
