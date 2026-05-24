# AGENT SELF-CHECK.md — Am I Actually Doing My Job?

The agent should run this self-audit periodically. If it scores below 7/10, it needs to course-correct before continuing.

---

## Session Self-Evaluation (Run at End of Every Session)

Score each item 1-10:

### 1. Did I Solve a Root Cause or Tweak Parameters?
- 10: Identified a structural problem and designed a first-principles solution
- 7: Understood the root cause but the solution is somewhat incremental
- 5: Mixed — some root cause thinking, some parameter adjustment
- 3: Mostly parameter tweaking with some justification
- 1: Just changed numbers and hoped for the best

### 2. Did I Research Before Implementing?
- 10: Found 3+ external sources, evaluated multiple approaches, chose the best with clear reasoning
- 7: Researched at least 1-2 approaches, made a reasonable choice
- 5: Looked at the problem from a few angles but mostly relied on own knowledge
- 3: Thought about it briefly then started coding
- 1: Jumped straight to implementation

### 3. Did I Follow One-Change-At-A-Time?
- 10: One logical change, isolated, clearly documented
- 7: One change with minor tangential fixes
- 5: One main change but also touched a few other things
- 3: Multiple changes bundled together
- 1: Rewrote large sections without clear isolation

### 4. Did I Backtest (or Prepare for Backtest)?
- 10: Backtest completed, results analyzed with forensic detail
- 7: Backtest prepared with exact instructions for Ryan
- 5: Code ready for backtest but instructions vague
- 3: Code exists but not verified to compile
- 1: Unverified code, no backtest plan

### 5. Did I Compare to V27.18 Baseline?
- 10: Full comparison on all metrics with per-strategy breakdown
- 7: Compared on core metrics (Profit, PF, DD)
- 5: Mentioned baseline but didn't do full comparison
- 3: Acknowledged baseline exists
- 1: Forgot baseline existed

### 6. Did I Update Project Files?
- 10: GOALS.md, memory/, PERFORMANCE_TRACKER.md all updated
- 7: Updated key files
- 5: Updated some files
- 3: Forgot to update
- 1: Left everything stale

### 7. Was I Honest About Uncertainty?
- 10: Clearly stated what I'm confident about vs. what needs testing
- 7: Mostly honest, some hedging
- 5: Mixed — some false confidence
- 3: Overconfident about untested ideas
- 1: Presented guesses as facts

### 8. Did I Advance a Goal?
- 10: Goal moved forward with concrete progress
- 7: Made meaningful progress
- 5: Some progress
- 3: Marginal progress
- 1: Busywork with no goal advancement

---

## Scoring

**Total: ___ / 80**

- **70-80:** Excellent session. Ship it.
- **60-69:** Good session. Minor improvements possible.
- **50-59:** Mediocre session. Review what slipped.
- **40-49:** Below standard. What did you skip?
- **Below 40:** Failed session. Re-read SOUL.md. Start over.

---

## Red Flags (Instant Fail)

If any of these are true, the session failed regardless of score:
- ❌ Created a version without backtesting the previous one
- ❌ Changed more than one logical thing in a single version
- ❌ Proposed a parameter tweak without root cause analysis
- ❌ Said "we can backtest later"
- ❌ Didn't reference the project history
- ❌ Re-enabled Silicon-X
- ❌ Loosened Nexus parameters
- ❌ Didn't compare to V27.18 baseline

---

## Agent Improvement Log

Track how the agent's self-evaluation scores change over time.

| Date | Session Score | What Went Well | What Needs Improvement |
|---|---|---|---|
| — | — | — | — |
