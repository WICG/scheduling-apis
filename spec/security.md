Security Considerations {#sec-security}
=====================

<div class="non-normative">
*This section is non-normative.*

The main security consideration for the APIs defined in this specification is
whether or not any information is potentially leaked between origins by
timing-based side-channel attacks.
</div>

`postTask` as a High-Resolution Timing Source {#sec-security-high-res-timer}
---------------------

<div class="non-normative">
The first consideration is whether the {{Scheduler/postTask()}} API can be used
as a high-resolution timing source. {{Scheduler/postTask()}}'s
{{SchedulerPostTaskOptions/delay}}, like
{{WindowOrWorkerGlobalScope/setTimeout()}}'s timeout value, is expressed in
whole milliseconds (the minimum non-zero delay being 1 ms), and there is no
guarantee that tasks will run exactly when the delay expires since tasks are
queued when the delay expires. Given this, we do not believe the API can be
used as a high-resolution timing source, but we mention it here because of the
general interest in the topic.
</div>

Monitoring Another Origin's Tasks {#sec-security-monitoring-tasks}
---------------------

<div class="non-normative">
The second consideration is whether {{Scheduler/postTask()}} leaks any
information about other origins' tasks. The threat model we consider is code
from two different origins running in separate event loops in the same thread.

Because the UA can only run tasks from one event loop at a time, an attacker
might be able to gain information about tasks running in another event loop by
monitoring when their tasks run. For example, an attacker could flood the
system with {{TaskPriority/user-blocking}} tasks and expect them to run
consecutively; if there are large gaps in between, then the attacker might
infer something about tasks running in another event loop, e.g. they have
higher priority.

The first thing we note is that the attacker would not be able to definitively
tell that a task ran in another event loop, e.g. an internal browser task might
have run, or perhaps the UA throttled the attacker's script.  Second, any
information gained would be implementation-dependent since inter-event-loop
task selection is not specified. Our opinion is that information gained in such
an attack is likely to be benign, but there are mitigations that implementers
can consider to minimize the risk:

 * Where possible, isolate cross-origin event loops by running them in different
   threads. This type of potential attack depends on the event loops sharing a
   thread.
 * Use an inter-event-loop scheduling policy that is not strictly based on
   priority. For example, an implementation might use round-robin or
   fair-scheduling between event loops to prevent leaking information about
   task priority. Another possibility is to ensure lower priority tasks are
   periodically cycled in to prevent inferring priority information.

Finally, we note that similar attacks could be carried out without this API,
e.g. by scheduling tasks with {{Window/postMessage(message, options)|postMessage()}},
although the addition of {{Scheduler/postTask()}} priorities could change what
implementation-dependent information is obtainable.
</div>
