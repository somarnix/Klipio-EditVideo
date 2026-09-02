# Timeline engine specification

Document: Timeline engine specification
Product: Klipio
Status: Active Specification
Document Version: 1
Last Updated: 2026-09-07
Implementation Authority: No

## Time representation

Use half-open intervals. Carry time rate explicitly. Convert rational values without repeated rounding; snap to sequence frames only at frame-based edit boundaries. Audio edits may require sample precision.

A constant-speed clip:
source(t) = sourceIn + (t - start) * speed
duration = sourceSpan / speed

Example: source [10,18), speed 2, sequence [5,9). Split at 6.5 gives source 13. Left duration 1.5, right 2.5. Both reference the same asset but receive distinct clip IDs and correctly remapped links.

## Operations

| Operation | Placement | Source range | Neighbors |
|---|---|---|---|
| Move | Changes | Same | Collision policy |
| Trim start | Boundary changes | In-point changes | Optional ripple |
| Trim end | End changes | Out-point changes | Optional ripple |
| Split | Two placements | Partitioned | No shift |
| Slip | Same | Both endpoints shift | Same |
| Roll | Shared boundary moves | Adjacent endpoints change | Total pair duration same |
| Slide | Selected clip moves | Selected source unchanged | Neighbor durations change |
| Ripple delete | Removed interval closes | Surviving content retained | Eligible downstream shifts |
| Duplicate | New instance | Same initial range | New IDs |
| Compound | Parent references child sequence | Child timing retained | Cycle rejection |

## Ripple example

A occupies [0,4), B [4,7), C [7,10). Delete B in ripple mode: C becomes [4,7). An attached title at [8,9) follows to [5,6) if attachment policy includes it. An independent music bed stays fixed unless explicitly included. If a required linked track is locked, reject the transaction rather than silently desynchronizing it.

## Snapping and interaction

Convert pointer pixels to sequence time with one shared transform. Candidates include clip edges, playhead, markers, and optional beat markers. Choose nearest candidate inside a screen-pixel tolerance; deterministic tie-break by distance then type/ID. Magnetic mode and snapping are different policies.

## Required tests

Boundary split produces no zero-duration clip. Source endpoints stay within available media. Undo restores order, links and IDs. Roll preserves pair duration. Slip preserves placement. Ripple preserves attached offsets. Compound cycles fail. Mixed FPS and fractional rates avoid cumulative drift. Randomized edits preserve invariants.

## Multicam extension

A multicam group references synchronized sources and offsets. Angle cuts select a source at sequence time without losing group identity. Add synchronization by timecode/manual offsets before waveform correlation. Test missing angles and angle-switch export; this belongs after strong timeline/time mapping.
