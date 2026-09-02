# Klipio Text Engine

Document: Klipio Text Engine
Product: Klipio
Status: Active Specification
Document Version: 1
Last Updated: 2026-09-07
Implementation Authority: No

Status: Specified. Text owns layout/rendering; captions own timed language documents and analysis.

## Data and pipeline

Unicode text → segmentation → script-aware shaping → glyph layout → decoration → transform/animation → composition.
A TextInstance references a versioned style/font set plus content and overrides. Preserve Unicode; never treat bytes or code points as interchangeable with grapheme/glyph clusters.

Khmer shaping, mixed scripts and fallback must be tested with actual fonts. Font availability and license are explicit; missing fonts produce visible substitution warnings. UI font choices do not dictate project text fonts.

Layout defines composition-space font size, wrapping width, paragraph alignment, line/letter spacing and overflow policy. Decorations include fill/gradient, stroke, shadow and background with explicit units/order. Transform follows the shared render contract.

## Styles and animation

Text styles are data-driven configurations of supported primitives. Templates add slots/layout rules. Per-character animation means a documented cluster-level policy for complex scripts, not splitting Khmer vowels from their base. Per-word animation references language segmentation; motion presets and user keys have explicit combination rules.

## Persistence and acceptance

Pin fonts/styles for reproducibility. Serialize user content, layout and keys, not glyph cache or widgets. Test Khmer, mixed directions/scripts, emoji, long lines, missing fonts, stroke/shadow bounds, scaling, animation at exact time, undo and save/reopen. Compare preview/export shaping and layout at the same dimensions and timestamps.



## Measurement and cluster integrity

One Unicode code point is not necessarily one visible character. Distinguish code points, grapheme clusters and shaped glyph clusters. Khmer fonts and fallback require script-aware shaping; text measurement must use the same shaped layout and wrapping constraints as rendering. Test mixed Khmer/English and emoji at wrap boundaries. Per-character animation must preserve shaped clusters rather than animating a dependent vowel independently. Preview/export must agree on font versions, cluster layout and composition-space measurement.
