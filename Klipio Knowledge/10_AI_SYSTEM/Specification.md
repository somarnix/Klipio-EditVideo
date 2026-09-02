# AI system specification

## Job contract

Input: operation, captured revision, media/audio digest, model/version, parameters, local/remote preference, user consent, resource budget.
Output: artifact references, provenance, confidence where meaningful, input identity, diagnostics, terminal status.

The editor reviews and applies output through ordinary commands. AI adapters do not import UI controllers.

## Operation mapping

| Operation | Output | User control |
|---|---|---|
| Transcription | Timed words/segments | Correct text and timing |
| Translation | Alternate caption document | Review before replacing |
| Tracking | Property keys and lost intervals | Correct keyframes |
| Background removal | Matte sequence | Refine or disable |
| Silence detection | Suggested source/sequence ranges | Accept selected cuts |
| Auto reframe | Transform track | Override framing |
| Beat sync | Markers/edit proposal | Adjust beat alignment |
| Speech cleanup | Derived audio + provenance | A/B and restore original |
| Generative asset | New media + provenance | Explicit insert |

## Safety and resource policy

Never upload without clear consent. Keep secrets out of diagnostics. Bound CPU threads, GPU memory, job concurrency and temporary disk. Model download has integrity checks and storage budget. Preserve original media.

Distinguish queued, preparing, inferencing, postprocessing, review-ready, cancelling, cancelled and failed. Heartbeats do not justify endless no-progress execution; use phase-specific watchdogs and explain timeouts.

## Batch behavior

Each item stores its own status and artifact. Completing 5 of 10 means five artifacts are available even if the sixth fails. Retry failed items with stable identities, avoiding duplicate application or charging. A revised project requires revalidation before applying old analysis.

## Evaluation

Create consented samples across languages, accents, noise levels and duration. Measure operation-specific quality alongside latency/resources. Test empty input, corrupt media, missing model, cancellation, stale results and retry. Do not present generative or recognition output as infallible.

