# APIs to improve JS schedulers

The following (primitive) APIs are being pursued currently:

## 1. Is Input Pending
Knowledge of whether input is pending, and the type of input.
This is covered here:
https://github.com/tdresser/should-yield

## 2. Is Frame Pending

JS schedulers are estimating the time to next animation frame with book-keeping, but it's not possible to estimate this properly without knowing browser internals.
The IsFramePending API allows script to determine when there is a pending frame to help with yielding decisions.

Link:
https://github.com/szager-chromium/isFramePending/blob/master/explainer.md

## 3. "After-paint" callback
Schedulers need to execute "default priority" work immediately following the document lifecycle (style, layout, paint).
Currently they use workarounds to target this with:

* postmessage after each rAF (used by ReactScheduler):
* messagechannel workaround (google3 nexttick used by Maps etc): use a private message channel to postMessage empty messages; also tacked on after rAF. A bug currently prevents yielding.
* settimeout 0: doesn’t work well, in Chrome this is clamped to 1ms and to 4ms after N recursions.

Link:
https://github.com/szager-chromium/requestPostAnimationFrame/blob/master/explainer.md

## Potential APIs we are thinking about
We are also thinking about the following problems. 
Note that these are not currently being pursued as API proposals, they are noted here for completeness and as a seed for discussion.

### Clean read (phase) after layout
Interleaved reads and writes of dom result in layout thrashing.
Today this is tackled with scheduling patterns like [fast-dom](https://github.com/wilsonpage/fastdom) and enforcement that goes along with this such as [strict-dom](https://github.com/wilsonpage/strictdom).

Ideally, the read phase would occur immediately after style and layout have finished; and this would be followed by the write phase (default). A first class callback would allow developers to perform a clean read at the appropriate time.

### Propagating scheduling Context for async work
A mechanism to inherit and propagate scheduling priority across related async calls: fetches, promises etc.
Similar in spririt to zone.js. 

