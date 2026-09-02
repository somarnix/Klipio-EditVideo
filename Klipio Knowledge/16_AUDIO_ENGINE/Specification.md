# Klipio Audio Engine

Document: Klipio Audio Engine
Product: Klipio
Status: Active Specification
Document Version: 1
Last Updated: 2026-09-07
Implementation Authority: No

Status: Specified target. The existing FFmpeg mixing helper is not proof of a full realtime audio engine.

## Graph and ownership

Source decoder → source-time map → clip processing → track processing → buses → master mixer → device/export.
The engine owns sample buffers, scheduling, routing, effect latency and synchronization. UI submits commands and observes meters; it does not calculate audio by widget timers.

Audio clips reference assets/streams with source and sequence ranges. Tracks route to buses with acyclic routing. Volume is a declared linear gain or converted dB; pan uses a documented law. Mute differs from deleting clips. Fades are typed envelopes.

## Sample time and sync

Use integer sample positions plus explicit sample rate at buffer boundaries. Resample inputs into a declared mix rate; do not repeatedly round video-frame positions into audio time. Playback must define a master clock, drift correction and device latency. Export uses deterministic sample counts/time maps.

Decode off the realtime callback. Preallocate bounded buffers; callbacks avoid blocking file/network calls. Underrun has diagnostic counters and a recovery policy.

## Processing

EQ defines filter bands; compressor defines threshold/ratio/attack/release; noise reduction and pitch/time stretch declare latency and quality limits. Speed change and pitch preservation are distinct. Effects report latency so parallel routes can align. Bypass must define whether latency compensation remains.

Waveform is multiresolution analysis, not the actual audio. Detach preserves source/link identity until unlink. Voiceover records to a recoverable temporary artifact, finalizes it, then inserts through a command. Keep original audio for reversible processing.

## Export and tests

Render audio from the same clip time maps as picture. Define channel layout, mix rate, gain staging, limiter policy and output format explicitly. Verify silence, mono/stereo, different rates, long A/V drift, linked edits, fade edges, effect latency, device loss, recording interruption, clipping and cancellation.

Do not label EQ/noise processing production-ready merely because an inspector control or data model exists.



## Distinct audio identities

Source media audio is the original stream. A timeline audio clip is one timed use of that stream. Waveform cache is disposable analysis and can never substitute for source samples. Playback mixer schedules device output; export mixer produces deterministic output samples from the same editing contract. Audio effects process samples with declared latency. Voiceover recordings are durable source artifacts once finalized. Independent music/SFX have separate clip identities even when their path matches another stream.

UI meters observe audio; they do not own gain, timing or synchronization. Verify playback/export mix agreement with labeled audio ticks and declared latency compensation.
