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
This  API cannot be used as a high-resolution timing source. Like
{{WindowOrWorkerGlobalScope/setTimeout()}}'s timeout value,
{{Scheduler/postTask()}}'s {{SchedulerPostTaskOptions/delay}} is expressed in
whole milliseconds (the minimum non-zero delay being 1 ms), so callers cannot
express any timing more precise than 1 ms. Further, since tasks are queued when
their delay expires and not run instantly, the precision available to callers
is further reduced.
</div>

Monitoring Another Origin's Tasks {#sec-security-monitoring-tasks}
---------------------

<div class="non-normative">
The second consideration is whether {{Scheduler/postTask()}} leaks any
information about other origins' tasks. We consider an attacker running on one
origin trying to obtain information about code executing in another origin (and
hence in a separate event loop) that is scheduled in the same thread in a
browser.

Because a thread within a UA can only run tasks from one event loop at a time,
an attacker might be able to gain information about tasks running in another
event loop by monitoring when their tasks run. For example, an attacker could
flood the system with tasks and expect them to run consecutively; if there are
large gaps in between, then the attacker could infer that another task ran,
potentially in a different event loop. The information exposed in such a case
would depend on implementation details, and implementations can reduce the
amount of information as described below.

**What Information Might Be Gained?** <br/>
Concretely, an attacker would be able to detect when other tasks are executed
by the browser by either flooding the system with tasks or by recursively
scheduling tasks. This is a [known attack](https://www.usenix.org/conference/usenixsecurity17/technical-sessions/presentation/vila)
that can be executed with existing APIs like {{Window/postMessage(message,
options)|postMessage()}}. The tasks that run instead of the attacker's can be
tasks in other event loops as well as other tasks in the attacker's event loop,
including internal UA tasks (e.g. garbage collection).

Assuming the attacker can determine with a high degree of probability that the
task executing is in another event loop, then the question becomes what
additional information can the attacker learn? Since inter-event-loop task
selection is not specified, this information will be implementation-dependent
and depends on how UAs order tasks between event loops. But UAs that use a
prioritization scheme that treats event loops sharing a thread as a single
event loop are vulnerable to exposing more information.

It is helpful to think about the *set of potential tasks* that a UA might
choose instead of the attacker's, which corresponds to the information gained.
When an attacker floods the system with tasks, the set of possible tasks would
be anything the UA deems to be higher priority at that moment. This could be
the result of a static prioritization scheme, e.g. input is always highest
priority, network is second highest, etc., or this could be more dynamic, e.g.
the UA occasionally chooses to run tasks from other task sources depending on
how long they've been starved. Using a dynamic scheme increases the set of potential
task which in turn decreases the fidelity of the information.

{{Scheduler/postTask()}} supports prioritization for tasks scheduled with it.
How these tasks are interleaved with other task sources is also
implementation-dependent, however it might be possible for an attacker to
further reduce the set of potential tasks that can run instead of its own by
leveraging this priority. For example, if a UA uses a simple static
prioritization scheme spanning all event loops in a thread, then using
{{TaskPriority/user-blocking}} {{Scheduler/postTask()}} tasks instead of
{{Window/postMessage(message, options)|postMessage()}} tasks might decrease
this set, depending on their relative prioritization and what is between.

**What Mitigations are Possible?** <br/>
There are mitigations that implementers can consider to minimize the risk:

 * Where possible, isolate cross-origin event loops by running them in different
   threads. This type of attack depends on the event loops sharing a thread.
 * Use an inter-event-loop scheduling policy that is not strictly based on
   priority. For example, an implementation might use round-robin or
   fair-scheduling between event loops to prevent leaking information about
   task priority. Another possibility is to ensure lower priority tasks are
   periodically cycled in to prevent inferring priority information.

</div>
