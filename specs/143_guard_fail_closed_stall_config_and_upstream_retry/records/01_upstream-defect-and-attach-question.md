# oliver-ben guard: fail-closed with no retry, two surfaces (and one open question)

For Oliver, about the guard he maintains. Both findings below are the same root cause expressed
twice; the question at the end is the one genuinely open thing in the current setup.

## Finding 1: admission suspends on the first network error, with no retry or grace window

`hub_fetch()` (`guard/guard.py`, hosted-route branch, starting at the `if
src.startswith('hub-route:')` line) raises `Suspend` on the very first timeout, connection
error, or non-2xx/non-304 response from the rules route — see `hub_fetch` and `admit`, roughly
lines 537-607. `admit()` catches that, writes `stopped.json`, and every later controlled action
blocks immediately without even attempting the network, until a human runs `guard.py unstop`.

Measured on one attached checkout over its full admission history to date: 3 **initiating**
admission failures (2 `TimeoutError`, 1 `URLError`) over roughly 1720 network round trips — about
0.17%. Because the suspend marker is sticky and nothing clears it automatically, those 3 events
produced 38 total blocked actions (every controlled action attempted while a marker sat unclear
counts as another blocked log entry, even though only 3 distinct network failures ever occurred),
and killed two full agent dispatches mid-flight on the same day, each needing a hand-run
`unstop`. In both of that day's cases the rules route was reachable again within seconds of the
failure — these are transient blips, not outages — so a bare retry, or even just tolerating the
last-good cache for a short grace window, would have prevented both stalls.

Proposal (either would have avoided both incidents):

- **(a)** One bounded retry inside `hub_fetch`, after a short backoff, within the existing
  `net_timeout_s`/`deadline_s` budget, before raising `Suspend`.
- **(b)** A grace window: keep enforcing from the last good cache for N seconds (comparable to
  `MIN_PULL_GAP_S`, i.e. roughly 10-30s) before writing `stopped.json`, so a transient blip
  degrades to "enforce from stale cache briefly" rather than "block everything until a human
  intervenes."

Separately, worth flagging: `MIN_PULL_GAP_S` (and the module docstring's "network pulls are at
least 10s apart" claim) is enforced only in the legacy, pre-attached code path. `admit()`'s own
pacing in attached mode is `coalesce_s` alone — it never references `MIN_PULL_GAP_S`. Not a bug
exactly, but the docstring reads as if it covers attached mode too, and it does not.

## Finding 2: the sender has the identical no-retry shape, and it is currently open on both ends

`send()` guards outbound commit-event delivery with its own sticky marker, `breaker.json`: the
first error from the sink write raises an exception that `send()` catches, writes `breaker.json`
with the error and the offending event id, prints "sender stopped: ... (breaker open, no
retry)", and refuses every later send until a human runs `guard.py send --reset`. This is the
same root cause as Finding 1 — one network error, sticky refusal, no retry — on the opposite
direction of traffic.

At the time of writing, the sender breaker is **open on both of my attached checkouts**, each
since a single `TimeoutError` several days ago, with dozens of commit events queued undelivered
in each checkout's outbox since then. I have not run `send --reset` yet — doing so delivers the
full backlog in one burst, which I want to do deliberately rather than as a side effect of an
unrelated change. The same two fixes proposed for Finding 1 (bounded retry, or a grace window)
would need to cover the sender symmetrically, since it is the same defect on the other surface.

## The one open question

Both of my attached checkouts currently cache the rules doc at revision 1 with an empty `kos`
list — the guard has been enforcing nothing, on either checkout, the entire time it has been
attached. That is working as designed (unaccepted rules are proposals, not enforcement), but it
means staying attached currently costs nothing in false positives, which is the main reason I am
not detaching either repo over the stalls above.

The thing I don't know, and that only you can answer: do you intend to Accept real `RULE`/
`decision` knowledge objects into this room soon, or is the empty rule set expected to persist for
a while? If real rules are coming, I'd like to retune how aggressively I coalesce rule-doc
fetches before they land, since there's a real freshness-vs-reliability trade there and I'd
rather tune it once knowing which way it's going. If the room stays empty for a while, nothing
here needs to change.

One thing worth flagging either way: detaching a repo's guard also stops the commit-event
reporting I separately consented to (the same two categories: commit events and
unpushed-branch sharing) — and per Finding 2 above, that reporting has in fact already been
silently stalled on both checkouts for several days, independent of whether I stay attached or
not.
