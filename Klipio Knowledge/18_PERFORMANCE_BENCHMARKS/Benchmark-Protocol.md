# Klipio performance benchmark protocol

Document: Klipio performance benchmark protocol
Product: Klipio
Status: Active Specification
Document Version: 1
Last Updated: 2026-09-07
Implementation Authority: No

Status: Specified methodology. No measurements were collected by this documentation task. Fast, smooth and optimized are goals unless accompanied by results.

## Reference workloads

| ID | Composition | Timeline | Creative load |
|---|---|---|---|
| Small | 1080p, fixed declared FPS | 10 clips, 2 video and 2 audio tracks | Basic text |
| Medium | Separate 1080p and 4K runs | 100 clips, multiple tracks | Fixed effect stack, captions and audio |
| Large | 4K, fixed declared FPS | 1,000 clips, multiple tracks and large media library | Pinned effects, text, captions |

Fixture manifest must define exact sources/digests, codecs, durations, frame/sample rates, track count, effect values, fonts and project revision. A label such as Large alone is not reproducible. Include two-video boundary and seven-import scenarios from the improvement plan.

## Measurement definitions

Startup: process start to usable home. Open: request to editable timeline, separately first playable frame. Import: request to registered asset, separately metadata. Thumbnail/waveform: request to first and all required visible results. Interaction: input timestamp to presented feedback. Seek: request to correct presented frame, not merely acknowledgement.

Measure dropped/expected preview frames, CPU, GPU, RAM/VRAM peak and trend, disk I/O, proxy seconds/source second, export output duration/wall duration, and cancel request to owned worker exit. Report unsupported counters as unavailable, not zero.

## Procedure

Record Klipio version/commit, OS, CPU/GPU/drivers, RAM, storage, power mode, build mode, backend and date. Separate cold/warm caches. Use one warm-up plus at least five timed repeats for startup/open/interaction scenarios; record raw samples, median and tail percentile with sample count. Long soak tests report duration and trend. Avoid claiming stable p95 from a tiny sample.

Fix worker limits and background load. Do not deliberately force a whole-PC freeze; define stop criteria for resource pressure. Compare the same fixture/settings/device across revisions. Store errors and cancellations as outcomes, not discard them.

## Results layout

Use results/<version>/<hardware-id>/<OS>/<fixture-id>/<date-run-id>.md when a real run exists. Keep raw trace links, methodology, metrics, failures and conclusion. No empty result folders or invented results are required. Use [result template](Result-Template.md).

Targets require baseline and product approval; proposed budgets must be labeled separately from achieved values.



## Required comparison context

Every result records Klipio version, Git commit, OS, CPU, GPU, RAM, storage, input media, timeline complexity, proxy state, preview resolution, metric and measured result. Record native backend/driver details and missing counters as well. Proxy-enabled and original-media runs are different workloads; preview resolution changes must not be hidden.

Example proposed target, not an approved or achieved guarantee: seek P95 < 100 ms. Measured result: Not measured yet. Targets and results remain separate columns; failed/missing measurements cannot be replaced by target values.
