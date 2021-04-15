# `scheduler.postTask()`: Security and Privacy Questionnaire Answers

The following are the answers to the W3C TAG's
[security and privacy self-review questionnaire](https://w3ctag.github.io/security-questionnaire/).

> 01. What information might this feature expose to Web sites or other parties,
>     and for what purposes is that exposure necessary?

Tasks scheduled with this API have an associated priority, which is provided by
consumers of the API. This priority could be obtained in JavaScript either by
having access to the associated `TaskSignal`, or by monkey-patching the
`scheduler` and intercepting calls to `postTask()`. The priority is used by the
UA for scheduling decisions, and is fundamental to a prioritized scheduling
API.

Tasks also have an optional delay value &mdash; analogous to `setTimeout()`'s
timeout value. This could similarly be obtained in JavaScript by
monkey-patching the API. The delay value is required to schedule delayed tasks.

In the context of [Third-Party Tracking](https://w3ctag.github.io/security-questionnaire/#third-party-tracking),
an attacker could monitor the number of scheduled tasks along with their
priorities, delays, and timing, for a particular site. It is unclear if this
information could be correlated in any useful way with other information about
the user, but we cannot think of anything. On its own, the task information
does not provide any information about what the user is doing.  And monitoring
the cause of the scheduled work (e.g. a `click` event) and DOM contents would
provide far more context. Our opinion is that this information is low-risk
since it is indicative of how a website schedules tasks, as opposed to being
associated with the user.

> 02. Do features in your specification expose the minimum amount of information
>     necessary to enable their intended uses?

Yes.

> 03. How do the features in your specification deal with personal information,
>     personally-identifiable information (PII), or information derived from
>     them?

They do not consume such information.

> 04. How do the features in your specification deal with sensitive information?

They do not consume such information.

> 05. Do the features in your specification introduce new state for an origin
>     that persists across browsing sessions?

No.

> 06. Do the features in your specification expose information about the
>     underlying platform to origins?

Not directly, and not any new information. In general, measuring code execution
time could potentially be used to determine something about the underlying
platform, e.g. slow vs. fast machine, when comparing across users.
`postTask()` adds another entrypoint for executing JavaScript, but there are
many others and there is nothing inherently different about `postTask()` in
that sense.

> 07. Does this specification allow an origin to send data to the underlying
>     platform?

No.

> 08. Do features in this specification allow an origin access to sensors on a user’s
>     device?

No.

> 09. What data do the features in this specification expose to an origin? Please
>     also document what data is identical to data exposed by other features, in the
>     same or different contexts.

The features do not expose any data directly to origins, but we consider
potential information leaks from timing-based side-channel attacks below.

**Consideration 1**: Can delayed tasks be used to implement a high-resolution timer?

This seems unlikely. `postTask()`'s delay, like `setTimeout()'s`, is expressed
in whole milliseconds (the minimum non-zero delay being 1 ms), and there is no
guarantee that tasks will run exactly when the delay expires since tasks are
queued when the delay expires.

**Consideration 2**:  Does `postTask()` leak information about other origins' tasks?

The threat model we consider is code from two different origins running in
separate event loops (the same event loop case is Q1). Attackers could attempt
to learn information about tasks running in another event loop by queuing
`postTask()` tasks that are expected to run consecutively, e.g. two
`'user-blocking'` tasks, and determining if they did. If not, then the UA may
<sup>1</sup> have chosen to run another task in between.

For such an attack to provide any information about tasks in another event
loop, the event loops would need to be running in the same thread, since
otherwise tasks would be running concurrently. But even then, there is no
guarantee that the attacker could definitivley determine that the delays are
attributable to another event loop, e.g. *if* a task ran, it could be an
internal browser task. And even if that could be determined, how tasks are
chosen between event loops sharing a thread is not specified, so any
information gained would be implementation-dependent.

Our opinion is that any information gained in such an attack is likely to be
benign. But if it is a concern, implementors can schedule between event loops
in such a way that minimizes the risk, e.g. round-robin between event loops
rather than use prioritization. Finally, we note that similar attacks could be
carried out without this API, e.g. by scheduling tasks with `postMessage()`,
although the implementation of `postTask()` priorities might change what
implementation-dependent information could be obtained.

<sup>1</sup>Another possibility is the UA chose to not run any tasks, e.g. it
may have throttled the site.

> 10. Do feautres in this specification enable new script execution/loading
>     mechanisms?

No. Note that this API requires a function, and does **not** support the
`setTimeout()`-style string-to-script mechanism.

> 11. Do features in this specification allow an origin to access other devices?

No.

> 12. Do features in this specification allow an origin some measure of control over
>     a user agent's native UI?

No.

> 13. What temporary identifiers do the feautures in this specification create or
>     expose to the web?

None.

> 14. How does this specification distinguish between behavior in first-party and
>     third-party contexts?

It does not make such a distinction. In the future, we may explore allowing
first-party to assert some control over a third-party scheduling (e.g. maximum
priority), but such a distinction is not currently made.

> 15. How do the features in this specification work in the context of a browser’s
>     Private Browsing or Incognito mode?

They work the same as in the non-private mode.

> 16. Does this specification have both "Security Considerations" and "Privacy
>     Considerations" sections?

Not yet.

> 17. Do features in your specification enable origins to downgrade default
>     security protections?

No.
