# `scheduler.postTask` Security Considerations

The main security concern is whether or not the API adds new surfaces to
perform side-channel attacks, specifically for same-process cross-origin
iframes. This might be a concern because `postTask`

1. exposes priorities, which influence the order in which tasks run
2. allows tasks to be posted with a delay

The two main attacks we consider here are whether `postTask` leaks any new
information through priorities, and  whether prioritized delayed tasks can be
used as a new high-resolution timing source.

## Inferring Information from Task Timing

Script can attempt to learn something about other tasks in the system by
measuring timing of the tasks it controls, specifically the delay [1]. In
other words, an attacker can queue tasks and try to infer something about the
system based on the time the tasks started to run. The relevant question here
is, can a frame learn anything (interesting) about other frames running in the
same process by exploiting the ordering guarantees of prioritized tasks?

[1] Task duration might provide some information about the underlying system,
specifically the OS, but is beyond the scope of this API since that is
fundamental to all tasks, not the ones introduced here.

### Recap of Prioritization

The browser has freedom to choose between tasks in different task queues (step
1 in the [Event Loop Processing
Model](https://html.spec.whatwg.org/multipage/webappapis.html#event-loop-processing-model)),
which correspond to different [task
sources](https://html.spec.whatwg.org/multipage/webappapis.html#task-source)
(e.g. network vs. user input). The `postTask` API does not change that, but
adds a new prioritized task source with the following properties:

1. **Ordering between `postTask` tasks**: `user-blocking` tasks run before
   `user-visible` tasks, which run before `background` tasks.
2. **Ordering between `postTask` and non-`postTask` tasks**: No guarantees are made
   between ordering of `postTask` and non-`postTask` tasks.

### Attack Setup

An attacker tries to exploit `postTask` priorities to learn something about
other tasks in the system, for example if another frame is running high
priority tasks. To do this, the attacker attempts to gain information through
task timing by measuring the time a task starts running and comparing it to
the _expected start time_:

 * For delayed tasks, _expected start time_ is the current time + delay,
   assuming delay exceeds the current task's duration.

 * For non-delayed tasks, if A queues B, B's _expected start time_ is when A
   ends, assuming A and B are expected to be consecutive.

(**Note**: both of these approaches are possible today, e.g. using
`setTimeout` for the delayed approach and `postMessage` for the _consecutive
task_ approach (e.g. queuing multiple self-directed messages).)

In either case, the difference between expected and actual start time
tells an attacker _something_:

1. The difference is approximately zero. This indicates that either there was
   little thread contention or there were no higher priority runnable tasks.

2. The difference is _substantial_. This indicates the scheduler chose to run
   one or more _higher priority_ tasks, which as discussed is currently left
   up to UAs to decide.

This, however, does not seem to be very useful since the attacker still doesn't
know _what_ ran. The question we want to answer next is whether or not adding
prioritized task sources leaks any additional information, and if that
information is useful. Specifically, since prioritized tasks are the novel
addition, does it leak the priorities of tasks running in other frames?

### Evaluation: What Information Can Be Gained?

**Case 1: prioritized delayed tasks.**

If the system is busy at the time a delayed task's delay expires, the result is
some amount of queuing time for the task. This, however, does not leak any
information about the type or priority of the task or tasks that ran while the
callback was queued, as the scheduler is free to run any task.

**Case 2: prioritized tasks without delay.**

Here we have tighter guarantees about ordering, namely that `postTask` tasks
are run in order from highest to lowest priority. There are a couple ways that
an attacker might post tasks such that they are expected to run consecutively:

 * Post consecutive tasks of priority N, e.g. `'user-blocking'`. This is similar
   to invoking a self-directed `postMessage` consecutively, but with the
   additional ordering guarantees.

 * Post consecutive tasks of priority N and N-1, e.g. `'user-blocking'` followed
   by `'user-visible'`. Note there is less expectation that these will actually
   run consecutively, which implies different information might be gleaned.


There are 4 cases to consider here:

1. **Tasks A and B of priority N were posted consecutively and run consecutively.**
   In this case, the attacker knows that no tasks of priority N (or higher) ran
   between A and B. This is similar to the current situation, and does not
   appear to provide any meaningful information:

  + All queued higher priority `postTask` tasks must have run before A started.
  + B must follow A within priority N, given that the tasks were queued
    consecutively.

2. **Tasks A (priority N) and B (priority N-1) were posted consecutively and run
   consecutively**, e.g. A is 'user-blocking' and B is 'user-visible'. In this
   case we learn that there were no other tasks of 'user-visible' priority
   queued when B ran, since there would have been a delay otherwise. This does
   not appear to leak anything meaningful, but is worth noting.

3. **Tasks A and B of priority N were posted consecutively and do not run
   consecutively**. In this case the system chose something else to run instead.
   Since the UA is free to run any non-postTask tasks between A and B, the
   attacker still doesn't learn _what_ runs, just that something higher
   priority ran, as determined by the UA. The UA could process an input event, run
   async network callbacks, garbage collection, etc. The only concrete thing the
   attacker learns about the task or tasks that run is that they aren't
   priority N `postTask` tasks &mdash; which is meaningless since the tasks were
   posted consecutively.

   We do note, however, that an attacker might be able to gain information about
   the types of tasks that ran by exploiting UA-specific implementation
   details. For example, if an attacker knows the UA will only run _certain_
   task types ahead of `user-blocking` tasks, they could then infer something
   about the task(s) that ran. Also note that this concern is not something
   introduced by this API, but applies today if an attacker queues a multiple
   tasks and expects them to run sequentially. It's not clear how much of a
   concern this is in practice, or how useful the information would be, but
   it's worth noting for implementers to consider.

   Finally, note that this type of attack requires the attacker to utilize the
   CPU during the attack, without knowledge of when other tasks are queued. So
   to have a reasonable degree of accuracy, the attacker would need long
   and/or frequent windows, meaning this attack is not exactly subtle. It's not
   clear how practical this actually is.

4. **Tasks A (priority N) and B (priority N-1) were posted consecutively and do
   not run consecutively**, e.g. A is `'user-blocking'` and B is
   `'user-visible'`. Here, like (3), any non-`postTask` task(s) can run between
   A and B, meaning the attacker can't determine exactly what ran. Even if the
   attacker knew that B was at the front of the queue [1], they wouldn't be able
   to determine if the task that ran in between A and B was a `'user-blocking'`
   `postTask` task or a different type of task.

   [1] An attacker could get something to the front of the a queue by queuing
   tasks at lower priorities. For example, to get something to the front of the
   `'user-visible`' queue, they could post a `'user-visible'` task from a
   `'background'` task.

### Conclusion

Based on this evaluation, it doesn't appear that an attacker can determine the
priority of other frames' tasks with a task-timing-based attack. However,
such an approach could provide an attacker with the following information:

1. That if tasks of priorities N and N-1 were posted consecutively and
   run consecutively, there were no tasks of priority N queued when the
   the second task ran.

2. That if a task T runs between two consecutively posted `postTask` tasks of
   priority N, T is not a postTask task of priority N.

Both of these follow from the strict ordering of `postTask` tasks and do not
provide any positive information, and do not appear to provide any useful
information.

## Can `postTask` be Used to Implement a High-Resolution Timer

Since `postTask` has a delay parameter, it's worth exploring whether or not
the delay, possibly in concert with priority, can be used as a source of high
resolution timing. This seems highly unlikely for the following reasons:

1. Like `setTimeout`, the delay value is in milliseconds, so the minimum delay
   is 1 ms.
2. Delayed tasks are not guaranteed to run at the exact time they expire. The
   task is queued when the timer expires, and the UA can add jitter if desired.
