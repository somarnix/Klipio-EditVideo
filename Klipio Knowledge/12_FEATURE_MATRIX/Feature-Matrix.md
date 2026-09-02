# Complete planning feature matrix

Status: proposed inventory, not implemented or released features. P0 = correctness/data protection; P1 = core workflow; P2 = creative expansion; P3 = strategic advanced work. M/H describe relative complexity, not time estimates. All means intended shared semantics; native capability still needs testing. Stage is the first planned major delivery, not permission to postpone foundational safety.

| System | Feature | Sub-feature | Priority | Required engine | Dependencies | Difficulty | Platform | Stage |
|---|---|---|---|---|---|---|---|---|
| Foundation | Typed asset IDs | Typed asset IDs contract, UI/error state and regression verification | P0 | Editor Core | IDs, time model | M | All | 0 |
| Foundation | Typed clip IDs | Typed clip IDs contract, UI/error state and regression verification | P0 | Editor Core | IDs, time model | M | All | 0 |
| Foundation | Rational time | Rational time contract, UI/error state and regression verification | P0 | Editor Core | IDs, time model | M | All | 0 |
| Foundation | Half-open intervals | Half-open intervals contract, UI/error state and regression verification | P0 | Editor Core | IDs, time model | M | All | 0 |
| Foundation | Revision validation | Revision validation contract, UI/error state and regression verification | P0 | Editor Core | IDs, time model | M | All | 0 |
| Foundation | Atomic commands | Atomic commands contract, UI/error state and regression verification | P0 | Editor Core | IDs, time model | M | All | 0 |
| Foundation | Structured errors | Structured errors contract, UI/error state and regression verification | P0 | Editor Core | IDs, time model | M | All | 0 |
| Foundation | Dependency rules | Dependency rules contract, UI/error state and regression verification | P0 | Editor Core | IDs, time model | M | All | 0 |
| Projects | Versioned manifest | Versioned manifest contract, UI/error state and regression verification | P0 | Persistence | Schema, filesystem | H | All | 0 |
| Projects | Atomic save | Atomic save contract, UI/error state and regression verification | P0 | Persistence | Schema, filesystem | H | All | 0 |
| Projects | Autosave revision | Autosave revision contract, UI/error state and regression verification | P0 | Persistence | Schema, filesystem | H | All | 0 |
| Projects | Backup rotation | Backup rotation contract, UI/error state and regression verification | P0 | Persistence | Schema, filesystem | H | All | 0 |
| Projects | Journal recovery | Journal recovery contract, UI/error state and regression verification | P0 | Persistence | Schema, filesystem | H | All | 0 |
| Projects | Migration fixtures | Migration fixtures contract, UI/error state and regression verification | P0 | Persistence | Schema, filesystem | H | All | 0 |
| Projects | Read-only compatibility | Read-only compatibility contract, UI/error state and regression verification | P0 | Persistence | Schema, filesystem | H | All | 0 |
| Projects | Portable paths | Portable paths contract, UI/error state and regression verification | P0 | Persistence | Schema, filesystem | H | All | 0 |
| Projects | Corruption detection | Corruption detection contract, UI/error state and regression verification | P0 | Persistence | Schema, filesystem | H | All | 0 |
| Import | Video import | Video import contract, UI/error state and regression verification | P1 | Media | Probe adapter | M | All | 1 |
| Import | Image import | Image import contract, UI/error state and regression verification | P1 | Media | Probe adapter | M | All | 1 |
| Import | Audio import | Audio import contract, UI/error state and regression verification | P1 | Media | Probe adapter | M | All | 1 |
| Import | Folder import | Folder import contract, UI/error state and regression verification | P1 | Media | Probe adapter | M | All | 1 |
| Import | Drag and drop | Drag and drop contract, UI/error state and regression verification | P1 | Media | Probe adapter | M | All | 1 |
| Import | Stream selection | Stream selection contract, UI/error state and regression verification | P1 | Media | Probe adapter | M | All | 1 |
| Import | Rotation metadata | Rotation metadata contract, UI/error state and regression verification | P1 | Media | Probe adapter | M | All | 1 |
| Import | Variable FPS timestamps | Variable FPS timestamps contract, UI/error state and regression verification | P1 | Media | Probe adapter | M | All | 1 |
| Import | Duplicate detection | Duplicate detection contract, UI/error state and regression verification | P1 | Media | Probe adapter | M | All | 1 |
| Import | Unicode paths | Unicode paths contract, UI/error state and regression verification | P1 | Media | Probe adapter | M | All | 1 |
| Derived media | Per-asset poster | Per-asset poster contract, UI/error state and regression verification | P1 | Media jobs | Identity, scheduler | H | All | 1 |
| Derived media | Time-sampled strips | Time-sampled strips contract, UI/error state and regression verification | P1 | Media jobs | Identity, scheduler | H | All | 1 |
| Derived media | Waveform pyramid | Waveform pyramid contract, UI/error state and regression verification | P1 | Media jobs | Identity, scheduler | H | All | 1 |
| Derived media | Proxy creation | Proxy creation contract, UI/error state and regression verification | P1 | Media jobs | Identity, scheduler | H | All | 1 |
| Derived media | Cache invalidation | Cache invalidation contract, UI/error state and regression verification | P1 | Media jobs | Identity, scheduler | H | All | 1 |
| Derived media | Offline placeholders | Offline placeholders contract, UI/error state and regression verification | P1 | Media jobs | Identity, scheduler | H | All | 1 |
| Derived media | Relink validation | Relink validation contract, UI/error state and regression verification | P1 | Media jobs | Identity, scheduler | H | All | 1 |
| Derived media | Failed thumbnail retry | Failed thumbnail retry contract, UI/error state and regression verification | P1 | Media jobs | Identity, scheduler | H | All | 1 |
| Derived media | Request generation | Request generation contract, UI/error state and regression verification | P1 | Media jobs | Identity, scheduler | H | All | 1 |
| Playback | Play/pause | Play/pause contract, UI/error state and regression verification | P0 | Playback | Decode, time maps | H | All | 1 |
| Playback | Accurate seek | Accurate seek contract, UI/error state and regression verification | P0 | Playback | Decode, time maps | H | All | 1 |
| Playback | Scrub generations | Scrub generations contract, UI/error state and regression verification | P0 | Playback | Decode, time maps | H | All | 1 |
| Playback | Frame stepping | Frame stepping contract, UI/error state and regression verification | P0 | Playback | Decode, time maps | H | All | 1 |
| Playback | Loop ranges | Loop ranges contract, UI/error state and regression verification | P0 | Playback | Decode, time maps | H | All | 1 |
| Playback | Audio clock | Audio clock contract, UI/error state and regression verification | P0 | Playback | Decode, time maps | H | All | 1 |
| Playback | Buffer state | Buffer state contract, UI/error state and regression verification | P0 | Playback | Decode, time maps | H | All | 1 |
| Playback | Preloading | Preloading contract, UI/error state and regression verification | P0 | Playback | Decode, time maps | H | All | 1 |
| Playback | Dropped-frame metrics | Dropped-frame metrics contract, UI/error state and regression verification | P0 | Playback | Decode, time maps | H | All | 1 |
| Playback | Device-loss handling | Device-loss handling contract, UI/error state and regression verification | P0 | Playback | Decode, time maps | H | All | 1 |
| Timeline | Trim in | Trim in contract, UI/error state and regression verification | P0 | Timeline | Commands, exact time | H | All | 2 |
| Timeline | Trim out | Trim out contract, UI/error state and regression verification | P0 | Timeline | Commands, exact time | H | All | 2 |
| Timeline | Speed-aware split | Speed-aware split contract, UI/error state and regression verification | P0 | Timeline | Commands, exact time | H | All | 2 |
| Timeline | Move clip | Move clip contract, UI/error state and regression verification | P0 | Timeline | Commands, exact time | H | All | 2 |
| Timeline | Duplicate | Duplicate contract, UI/error state and regression verification | P0 | Timeline | Commands, exact time | H | All | 2 |
| Timeline | Copy/paste IDs | Copy/paste IDs contract, UI/error state and regression verification | P0 | Timeline | Commands, exact time | H | All | 2 |
| Timeline | Ripple delete | Ripple delete contract, UI/error state and regression verification | P0 | Timeline | Commands, exact time | H | All | 2 |
| Timeline | Ripple trim | Ripple trim contract, UI/error state and regression verification | P0 | Timeline | Commands, exact time | H | All | 2 |
| Timeline | Roll edit | Roll edit contract, UI/error state and regression verification | P0 | Timeline | Commands, exact time | H | All | 2 |
| Timeline | Slip edit | Slip edit contract, UI/error state and regression verification | P0 | Timeline | Commands, exact time | H | All | 2 |
| Timeline | Slide edit | Slide edit contract, UI/error state and regression verification | P0 | Timeline | Commands, exact time | H | All | 2 |
| Timeline | Track lock | Track lock contract, UI/error state and regression verification | P0 | Timeline | Commands, exact time | H | All | 2 |
| Timeline | Track mute | Track mute contract, UI/error state and regression verification | P0 | Timeline | Commands, exact time | H | All | 2 |
| Timeline | Track visibility | Track visibility contract, UI/error state and regression verification | P0 | Timeline | Commands, exact time | H | All | 2 |
| Timeline | Linked audio | Linked audio contract, UI/error state and regression verification | P0 | Timeline | Commands, exact time | H | All | 2 |
| Timeline | Group selection | Group selection contract, UI/error state and regression verification | P0 | Timeline | Commands, exact time | H | All | 2 |
| Timeline | Markers | Markers contract, UI/error state and regression verification | P0 | Timeline | Commands, exact time | H | All | 2 |
| Timeline | Snapping | Snapping contract, UI/error state and regression verification | P0 | Timeline | Commands, exact time | H | All | 2 |
| Timeline | Magnetic policy | Magnetic policy contract, UI/error state and regression verification | P0 | Timeline | Commands, exact time | H | All | 2 |
| Timeline | Zoom mapping | Zoom mapping contract, UI/error state and regression verification | P0 | Timeline | Commands, exact time | H | All | 2 |
| Timeline | Horizontal scroll | Horizontal scroll contract, UI/error state and regression verification | P0 | Timeline | Commands, exact time | H | All | 2 |
| Timeline | Vertical scroll | Vertical scroll contract, UI/error state and regression verification | P0 | Timeline | Commands, exact time | H | All | 2 |
| History | Undo | Undo contract, UI/error state and regression verification | P0 | Commands | Patches, revision | M | All | 2 |
| History | Redo | Redo contract, UI/error state and regression verification | P0 | Commands | Patches, revision | M | All | 2 |
| History | Drag transaction | Drag transaction contract, UI/error state and regression verification | P0 | Commands | Patches, revision | M | All | 2 |
| History | Command coalescing | Command coalescing contract, UI/error state and regression verification | P0 | Commands | Patches, revision | M | All | 2 |
| History | History budget | History budget contract, UI/error state and regression verification | P0 | Commands | Patches, revision | M | All | 2 |
| History | Failed-command atomicity | Failed-command atomicity contract, UI/error state and regression verification | P0 | Commands | Patches, revision | M | All | 2 |
| History | Link restoration | Link restoration contract, UI/error state and regression verification | P0 | Commands | Patches, revision | M | All | 2 |
| History | Redo branch policy | Redo branch policy contract, UI/error state and regression verification | P0 | Commands | Patches, revision | M | All | 2 |
| Transform | Position | Position contract, UI/error state and regression verification | P0 | Render | Coordinates, time map | H | All | 3 |
| Transform | Uniform scale | Uniform scale contract, UI/error state and regression verification | P0 | Render | Coordinates, time map | H | All | 3 |
| Transform | Nonuniform scale | Nonuniform scale contract, UI/error state and regression verification | P0 | Render | Coordinates, time map | H | All | 3 |
| Transform | Rotation | Rotation contract, UI/error state and regression verification | P0 | Render | Coordinates, time map | H | All | 3 |
| Transform | Anchor | Anchor contract, UI/error state and regression verification | P0 | Render | Coordinates, time map | H | All | 3 |
| Transform | Crop | Crop contract, UI/error state and regression verification | P0 | Render | Coordinates, time map | H | All | 3 |
| Transform | Flip horizontal | Flip horizontal contract, UI/error state and regression verification | P0 | Render | Coordinates, time map | H | All | 3 |
| Transform | Flip vertical | Flip vertical contract, UI/error state and regression verification | P0 | Render | Coordinates, time map | H | All | 3 |
| Transform | Opacity | Opacity contract, UI/error state and regression verification | P0 | Render | Coordinates, time map | H | All | 3 |
| Transform | Contain/cover | Contain/cover contract, UI/error state and regression verification | P0 | Render | Coordinates, time map | H | All | 3 |
| Transform | Canvas blur | Canvas blur contract, UI/error state and regression verification | P0 | Render | Coordinates, time map | H | All | 3 |
| Transform | Canvas color | Canvas color contract, UI/error state and regression verification | P0 | Render | Coordinates, time map | H | All | 3 |
| Transform | Canvas pattern | Canvas pattern contract, UI/error state and regression verification | P0 | Render | Coordinates, time map | H | All | 3 |
| Transform | Reset selected | Reset selected contract, UI/error state and regression verification | P0 | Render | Coordinates, time map | H | All | 3 |
| Transform | Apply selected groups | Apply selected groups contract, UI/error state and regression verification | P0 | Render | Coordinates, time map | H | All | 3 |
| Transform | Mixed inspector values | Mixed inspector values contract, UI/error state and regression verification | P0 | Render | Coordinates, time map | H | All | 3 |
| Transform | Direct gizmos | Direct gizmos contract, UI/error state and regression verification | P0 | Render | Coordinates, time map | H | All | 3 |
| Text | Plain text | Plain text contract, UI/error state and regression verification | P1 | Text shaping | Fonts, render | H | All | 3 |
| Text | Khmer shaping | Khmer shaping contract, UI/error state and regression verification | P1 | Text shaping | Fonts, render | H | All | 3 |
| Text | Font fallback | Font fallback contract, UI/error state and regression verification | P1 | Text shaping | Fonts, render | H | All | 3 |
| Text | Wrapping | Wrapping contract, UI/error state and regression verification | P1 | Text shaping | Fonts, render | H | All | 3 |
| Text | Alignment | Alignment contract, UI/error state and regression verification | P1 | Text shaping | Fonts, render | H | All | 3 |
| Text | Letter spacing | Letter spacing contract, UI/error state and regression verification | P1 | Text shaping | Fonts, render | H | All | 3 |
| Text | Line spacing | Line spacing contract, UI/error state and regression verification | P1 | Text shaping | Fonts, render | H | All | 3 |
| Text | Stroke | Stroke contract, UI/error state and regression verification | P1 | Text shaping | Fonts, render | H | All | 3 |
| Text | Shadow | Shadow contract, UI/error state and regression verification | P1 | Text shaping | Fonts, render | H | All | 3 |
| Text | Glow | Glow contract, UI/error state and regression verification | P1 | Text shaping | Fonts, render | H | All | 3 |
| Text | Background | Background contract, UI/error state and regression verification | P1 | Text shaping | Fonts, render | H | All | 3 |
| Text | Gradient | Gradient contract, UI/error state and regression verification | P1 | Text shaping | Fonts, render | H | All | 3 |
| Text | Composition font size | Composition font size contract, UI/error state and regression verification | P1 | Text shaping | Fonts, render | H | All | 3 |
| Text | Missing-font warning | Missing-font warning contract, UI/error state and regression verification | P1 | Text shaping | Fonts, render | H | All | 3 |
| Text | Editable style override | Editable style override contract, UI/error state and regression verification | P1 | Text shaping | Fonts, render | H | All | 3 |
| Captions | Manual captions | Manual captions contract, UI/error state and regression verification | P1 | Caption | Audio snapshot, text | H | All | 3 |
| Captions | SRT import | SRT import contract, UI/error state and regression verification | P1 | Caption | Audio snapshot, text | H | All | 3 |
| Captions | VTT import | VTT import contract, UI/error state and regression verification | P1 | Caption | Audio snapshot, text | H | All | 3 |
| Captions | Subtitle export | Subtitle export contract, UI/error state and regression verification | P1 | Caption | Audio snapshot, text | H | All | 3 |
| Captions | Word timing | Word timing contract, UI/error state and regression verification | P1 | Caption | Audio snapshot, text | H | All | 3 |
| Captions | Timing correction | Timing correction contract, UI/error state and regression verification | P1 | Caption | Audio snapshot, text | H | All | 3 |
| Captions | Caption tracks | Caption tracks contract, UI/error state and regression verification | P1 | Caption | Audio snapshot, text | H | All | 3 |
| Captions | Line grouping | Line grouping contract, UI/error state and regression verification | P1 | Caption | Audio snapshot, text | H | All | 3 |
| Captions | Safe area | Safe area contract, UI/error state and regression verification | P1 | Caption | Audio snapshot, text | H | All | 3 |
| Captions | Batch target parsing | Batch target parsing contract, UI/error state and regression verification | P1 | Caption | Audio snapshot, text | H | All | 3 |
| Captions | Per-item progress | Per-item progress contract, UI/error state and regression verification | P1 | Caption | Audio snapshot, text | H | All | 3 |
| Captions | Partial completion | Partial completion contract, UI/error state and regression verification | P1 | Caption | Audio snapshot, text | H | All | 3 |
| Captions | Stale analysis detection | Stale analysis detection contract, UI/error state and regression verification | P1 | Caption | Audio snapshot, text | H | All | 3 |
| Captions | Karaoke highlight | Karaoke highlight contract, UI/error state and regression verification | P1 | Caption | Audio snapshot, text | H | All | 3 |
| Captions | Speaker labels | Speaker labels contract, UI/error state and regression verification | P1 | Caption | Audio snapshot, text | H | All | 3 |
| Audio | Volume | Volume contract, UI/error state and regression verification | P1 | Audio graph | Samples, links | H | All | 3 |
| Audio | Pan | Pan contract, UI/error state and regression verification | P1 | Audio graph | Samples, links | H | All | 3 |
| Audio | Fade in | Fade in contract, UI/error state and regression verification | P1 | Audio graph | Samples, links | H | All | 3 |
| Audio | Fade out | Fade out contract, UI/error state and regression verification | P1 | Audio graph | Samples, links | H | All | 3 |
| Audio | Detach | Detach contract, UI/error state and regression verification | P1 | Audio graph | Samples, links | H | All | 3 |
| Audio | Voiceover | Voiceover contract, UI/error state and regression verification | P1 | Audio graph | Samples, links | H | All | 3 |
| Audio | EQ | EQ contract, UI/error state and regression verification | P1 | Audio graph | Samples, links | H | All | 3 |
| Audio | Compressor | Compressor contract, UI/error state and regression verification | P1 | Audio graph | Samples, links | H | All | 3 |
| Audio | Reverb | Reverb contract, UI/error state and regression verification | P1 | Audio graph | Samples, links | H | All | 3 |
| Audio | Peak meters | Peak meters contract, UI/error state and regression verification | P1 | Audio graph | Samples, links | H | All | 3 |
| Audio | Latency compensation | Latency compensation contract, UI/error state and regression verification | P1 | Audio graph | Samples, links | H | All | 3 |
| Audio | Sample-rate conversion | Sample-rate conversion contract, UI/error state and regression verification | P1 | Audio graph | Samples, links | H | All | 3 |
| Audio | Independent music preservation | Independent music preservation contract, UI/error state and regression verification | P1 | Audio graph | Samples, links | H | All | 3 |
| Color | Exposure | Exposure contract, UI/error state and regression verification | P1 | Color | Render policy | H | All | 3 |
| Color | Contrast | Contrast contract, UI/error state and regression verification | P1 | Color | Render policy | H | All | 3 |
| Color | Highlights | Highlights contract, UI/error state and regression verification | P1 | Color | Render policy | H | All | 3 |
| Color | Shadows | Shadows contract, UI/error state and regression verification | P1 | Color | Render policy | H | All | 3 |
| Color | Saturation | Saturation contract, UI/error state and regression verification | P1 | Color | Render policy | H | All | 3 |
| Color | Temperature | Temperature contract, UI/error state and regression verification | P1 | Color | Render policy | H | All | 3 |
| Color | Tint | Tint contract, UI/error state and regression verification | P1 | Color | Render policy | H | All | 3 |
| Color | Curves | Curves contract, UI/error state and regression verification | P1 | Color | Render policy | H | All | 3 |
| Color | HSL | HSL contract, UI/error state and regression verification | P1 | Color | Render policy | H | All | 3 |
| Color | Wheels | Wheels contract, UI/error state and regression verification | P1 | Color | Render policy | H | All | 3 |
| Color | SDR metadata | SDR metadata contract, UI/error state and regression verification | P1 | Color | Render policy | H | All | 3 |
| Color | Range handling | Range handling contract, UI/error state and regression verification | P1 | Color | Render policy | H | All | 3 |
| Effects | Definition registry | Definition registry contract, UI/error state and regression verification | P2 | Effect | Graph, parameter schema | H | All | 4 |
| Effects | Typed parameters | Typed parameters contract, UI/error state and regression verification | P2 | Effect | Graph, parameter schema | H | All | 4 |
| Effects | Instance stack | Instance stack contract, UI/error state and regression verification | P2 | Effect | Graph, parameter schema | H | All | 4 |
| Effects | Reorder effects | Reorder effects contract, UI/error state and regression verification | P2 | Effect | Graph, parameter schema | H | All | 4 |
| Effects | Bypass effect | Bypass effect contract, UI/error state and regression verification | P2 | Effect | Graph, parameter schema | H | All | 4 |
| Effects | Preset overrides | Preset overrides contract, UI/error state and regression verification | P2 | Effect | Graph, parameter schema | H | All | 4 |
| Effects | Seeded randomness | Seeded randomness contract, UI/error state and regression verification | P2 | Effect | Graph, parameter schema | H | All | 4 |
| Effects | CPU capability | CPU capability contract, UI/error state and regression verification | P2 | Effect | Graph, parameter schema | H | All | 4 |
| Effects | GPU capability | GPU capability contract, UI/error state and regression verification | P2 | Effect | Graph, parameter schema | H | All | 4 |
| Effects | Temporal dependencies | Temporal dependencies contract, UI/error state and regression verification | P2 | Effect | Graph, parameter schema | H | All | 4 |
| Effects | Effect thumbnails | Effect thumbnails contract, UI/error state and regression verification | P2 | Effect | Graph, parameter schema | H | All | 4 |
| Content | IDs and versions | IDs and versions contract, UI/error state and regression verification | P2 | Registry | Manifest, validation | H | All | 4 |
| Content | Localized metadata | Localized metadata contract, UI/error state and regression verification | P2 | Registry | Manifest, validation | H | All | 4 |
| Content | Categories | Categories contract, UI/error state and regression verification | P2 | Registry | Manifest, validation | H | All | 4 |
| Content | Tags | Tags contract, UI/error state and regression verification | P2 | Registry | Manifest, validation | H | All | 4 |
| Content | Search | Search contract, UI/error state and regression verification | P2 | Registry | Manifest, validation | H | All | 4 |
| Content | Favorites | Favorites contract, UI/error state and regression verification | P2 | Registry | Manifest, validation | H | All | 4 |
| Content | Downloads | Downloads contract, UI/error state and regression verification | P2 | Registry | Manifest, validation | H | All | 4 |
| Content | Offline installation | Offline installation contract, UI/error state and regression verification | P2 | Registry | Manifest, validation | H | All | 4 |
| Content | Dependency resolution | Dependency resolution contract, UI/error state and regression verification | P2 | Registry | Manifest, validation | H | All | 4 |
| Content | Digests | Digests contract, UI/error state and regression verification | P2 | Registry | Manifest, validation | H | All | 4 |
| Content | Signatures | Signatures contract, UI/error state and regression verification | P2 | Registry | Manifest, validation | H | All | 4 |
| Content | Compatibility | Compatibility contract, UI/error state and regression verification | P2 | Registry | Manifest, validation | H | All | 4 |
| Content | Project pins | Project pins contract, UI/error state and regression verification | P2 | Registry | Manifest, validation | H | All | 4 |
| Content | Preview videos | Preview videos contract, UI/error state and regression verification | P2 | Registry | Manifest, validation | H | All | 4 |
| Content | Safe eviction | Safe eviction contract, UI/error state and regression verification | P2 | Registry | Manifest, validation | H | All | 4 |
| Content | Explicit upgrade | Explicit upgrade contract, UI/error state and regression verification | P2 | Registry | Manifest, validation | H | All | 4 |
| Templates | Media slots | Media slots contract, UI/error state and regression verification | P2 | Template | Project fragments, registry | H | All | 4 |
| Templates | Text slots | Text slots contract, UI/error state and regression verification | P2 | Template | Project fragments, registry | H | All | 4 |
| Templates | Minimum duration | Minimum duration contract, UI/error state and regression verification | P2 | Template | Project fragments, registry | H | All | 4 |
| Templates | Fit policy | Fit policy contract, UI/error state and regression verification | P2 | Template | Project fragments, registry | H | All | 4 |
| Templates | Replacement validation | Replacement validation contract, UI/error state and regression verification | P2 | Template | Project fragments, registry | H | All | 4 |
| Templates | Fresh instance IDs | Fresh instance IDs contract, UI/error state and regression verification | P2 | Template | Project fragments, registry | H | All | 4 |
| Templates | Nested references | Nested references contract, UI/error state and regression verification | P2 | Template | Project fragments, registry | H | All | 4 |
| Templates | Expand to edit | Expand to edit contract, UI/error state and regression verification | P2 | Template | Project fragments, registry | H | All | 4 |
| Templates | Pinned dependencies | Pinned dependencies contract, UI/error state and regression verification | P2 | Template | Project fragments, registry | H | All | 4 |
| Transitions | Dissolve | Dissolve contract, UI/error state and regression verification | P2 | Transition | Time, handles, graph | H | All | 4 |
| Transitions | Directional wipe | Directional wipe contract, UI/error state and regression verification | P2 | Transition | Time, handles, graph | H | All | 4 |
| Transitions | Parameter presets | Parameter presets contract, UI/error state and regression verification | P2 | Transition | Time, handles, graph | H | All | 4 |
| Transitions | Duration edit | Duration edit contract, UI/error state and regression verification | P2 | Transition | Time, handles, graph | H | All | 4 |
| Transitions | Handle validation | Handle validation contract, UI/error state and regression verification | P2 | Transition | Time, handles, graph | H | All | 4 |
| Transitions | Audio crossfade | Audio crossfade contract, UI/error state and regression verification | P2 | Transition | Time, handles, graph | H | All | 4 |
| Transitions | Browser previews | Browser previews contract, UI/error state and regression verification | P2 | Transition | Time, handles, graph | H | All | 4 |
| Transitions | Missing-handle policy | Missing-handle policy contract, UI/error state and regression verification | P2 | Transition | Time, handles, graph | H | All | 4 |
| Stickers | Static sticker | Static sticker contract, UI/error state and regression verification | P2 | Overlay | Media, registry | M | All | 4 |
| Stickers | Animated GIF | Animated GIF contract, UI/error state and regression verification | P2 | Overlay | Media, registry | M | All | 4 |
| Stickers | Vector subset | Vector subset contract, UI/error state and regression verification | P2 | Overlay | Media, registry | M | All | 4 |
| Stickers | Shape | Shape contract, UI/error state and regression verification | P2 | Overlay | Media, registry | M | All | 4 |
| Stickers | Icon | Icon contract, UI/error state and regression verification | P2 | Overlay | Media, registry | M | All | 4 |
| Stickers | Frame overlay | Frame overlay contract, UI/error state and regression verification | P2 | Overlay | Media, registry | M | All | 4 |
| Stickers | Loop policy | Loop policy contract, UI/error state and regression verification | P2 | Overlay | Media, registry | M | All | 4 |
| Stickers | Alpha validation | Alpha validation contract, UI/error state and regression verification | P2 | Overlay | Media, registry | M | All | 4 |
| Performance | Queue limits | Queue limits contract, UI/error state and regression verification | P0 | Scheduler | Budgets, profiling | H | All | 5 |
| Performance | Thread budgets | Thread budgets contract, UI/error state and regression verification | P0 | Scheduler | Budgets, profiling | H | All | 5 |
| Performance | GPU memory budget | GPU memory budget contract, UI/error state and regression verification | P0 | Scheduler | Budgets, profiling | H | All | 5 |
| Performance | Disk budget | Disk budget contract, UI/error state and regression verification | P0 | Scheduler | Budgets, profiling | H | All | 5 |
| Performance | Job priority | Job priority contract, UI/error state and regression verification | P0 | Scheduler | Budgets, profiling | H | All | 5 |
| Performance | Deduplication | Deduplication contract, UI/error state and regression verification | P0 | Scheduler | Budgets, profiling | H | All | 5 |
| Performance | Cancel superseded work | Cancel superseded work contract, UI/error state and regression verification | P0 | Scheduler | Budgets, profiling | H | All | 5 |
| Performance | Virtual timeline | Virtual timeline contract, UI/error state and regression verification | P0 | Scheduler | Budgets, profiling | H | All | 5 |
| Performance | Frame cache | Frame cache contract, UI/error state and regression verification | P0 | Scheduler | Budgets, profiling | H | All | 5 |
| Performance | Render cache | Render cache contract, UI/error state and regression verification | P0 | Scheduler | Budgets, profiling | H | All | 5 |
| Performance | LRU eviction | LRU eviction contract, UI/error state and regression verification | P0 | Scheduler | Budgets, profiling | H | All | 5 |
| Performance | Low-resolution preview | Low-resolution preview contract, UI/error state and regression verification | P0 | Scheduler | Budgets, profiling | H | All | 5 |
| Performance | Proxy switch | Proxy switch contract, UI/error state and regression verification | P0 | Scheduler | Budgets, profiling | H | All | 5 |
| Performance | Long-media soak | Long-media soak contract, UI/error state and regression verification | P0 | Scheduler | Budgets, profiling | H | All | 5 |
| Animation | Keyframe add/remove | Keyframe add/remove contract, UI/error state and regression verification | P2 | Animation | Typed properties | H | All | 6 |
| Animation | Linear interpolation | Linear interpolation contract, UI/error state and regression verification | P2 | Animation | Typed properties | H | All | 6 |
| Animation | Step interpolation | Step interpolation contract, UI/error state and regression verification | P2 | Animation | Typed properties | H | All | 6 |
| Animation | Bezier easing | Bezier easing contract, UI/error state and regression verification | P2 | Animation | Typed properties | H | All | 6 |
| Animation | Rotation interpolation | Rotation interpolation contract, UI/error state and regression verification | P2 | Animation | Typed properties | H | All | 6 |
| Animation | Entrance | Entrance contract, UI/error state and regression verification | P2 | Animation | Typed properties | H | All | 6 |
| Animation | Exit | Exit contract, UI/error state and regression verification | P2 | Animation | Typed properties | H | All | 6 |
| Animation | Loop | Loop contract, UI/error state and regression verification | P2 | Animation | Typed properties | H | All | 6 |
| Animation | Additive policy | Additive policy contract, UI/error state and regression verification | P2 | Animation | Typed properties | H | All | 6 |
| Animation | Audio automation | Audio automation contract, UI/error state and regression verification | P2 | Animation | Typed properties | H | All | 6 |
| Animation | Mask keys | Mask keys contract, UI/error state and regression verification | P2 | Animation | Typed properties | H | All | 6 |
| Animation | Text path | Text path contract, UI/error state and regression verification | P2 | Animation | Typed properties | H | All | 6 |
| Animation | Curved text | Curved text contract, UI/error state and regression verification | P2 | Animation | Typed properties | H | All | 6 |
| Advanced time | Reverse | Reverse contract, UI/error state and regression verification | P2 | Time maps | Render/audio | H | Desktop first | 6 |
| Advanced time | Freeze frame | Freeze frame contract, UI/error state and regression verification | P2 | Time maps | Render/audio | H | Desktop first | 6 |
| Advanced time | Piecewise ramp | Piecewise ramp contract, UI/error state and regression verification | P2 | Time maps | Render/audio | H | Desktop first | 6 |
| Advanced time | Smooth ramp | Smooth ramp contract, UI/error state and regression verification | P2 | Time maps | Render/audio | H | Desktop first | 6 |
| Advanced time | Pitch preservation | Pitch preservation contract, UI/error state and regression verification | P2 | Time maps | Render/audio | H | Desktop first | 6 |
| Advanced time | Optical-flow prototype | Optical-flow prototype contract, UI/error state and regression verification | P2 | Time maps | Render/audio | H | Desktop first | 6 |
| Advanced time | Scene-cut handling | Scene-cut handling contract, UI/error state and regression verification | P2 | Time maps | Render/audio | H | Desktop first | 6 |
| Compositing | Rectangle mask | Rectangle mask contract, UI/error state and regression verification | P2 | Render graph | Alpha, transforms | H | Desktop first | 6 |
| Compositing | Ellipse mask | Ellipse mask contract, UI/error state and regression verification | P2 | Render graph | Alpha, transforms | H | Desktop first | 6 |
| Compositing | Custom path | Custom path contract, UI/error state and regression verification | P2 | Render graph | Alpha, transforms | H | Desktop first | 6 |
| Compositing | Feather | Feather contract, UI/error state and regression verification | P2 | Render graph | Alpha, transforms | H | Desktop first | 6 |
| Compositing | Invert | Invert contract, UI/error state and regression verification | P2 | Render graph | Alpha, transforms | H | Desktop first | 6 |
| Compositing | Blend modes | Blend modes contract, UI/error state and regression verification | P2 | Render graph | Alpha, transforms | H | Desktop first | 6 |
| Compositing | Chroma key | Chroma key contract, UI/error state and regression verification | P2 | Render graph | Alpha, transforms | H | Desktop first | 6 |
| Compositing | Spill suppression | Spill suppression contract, UI/error state and regression verification | P2 | Render graph | Alpha, transforms | H | Desktop first | 6 |
| Compositing | Nested sequences | Nested sequences contract, UI/error state and regression verification | P2 | Render graph | Alpha, transforms | H | Desktop first | 6 |
| Compositing | Compound clips | Compound clips contract, UI/error state and regression verification | P2 | Render graph | Alpha, transforms | H | Desktop first | 6 |
| Compositing | Perspective | Perspective contract, UI/error state and regression verification | P2 | Render graph | Alpha, transforms | H | Desktop first | 6 |
| Compositing | Isolated groups | Isolated groups contract, UI/error state and regression verification | P2 | Render graph | Alpha, transforms | H | Desktop first | 6 |
| Multicam | Manual offsets | Manual offsets contract, UI/error state and regression verification | P3 | Timeline sync | Nested source maps | H | Desktop first | 6 |
| Multicam | Timecode sync | Timecode sync contract, UI/error state and regression verification | P3 | Timeline sync | Nested source maps | H | Desktop first | 6 |
| Multicam | Waveform sync proposal | Waveform sync proposal contract, UI/error state and regression verification | P3 | Timeline sync | Nested source maps | H | Desktop first | 6 |
| Multicam | Angle viewer | Angle viewer contract, UI/error state and regression verification | P3 | Timeline sync | Nested source maps | H | Desktop first | 6 |
| Multicam | Angle cut | Angle cut contract, UI/error state and regression verification | P3 | Timeline sync | Nested source maps | H | Desktop first | 6 |
| Multicam | Missing angle fallback | Missing angle fallback contract, UI/error state and regression verification | P3 | Timeline sync | Nested source maps | H | Desktop first | 6 |
| Scopes | Histogram | Histogram contract, UI/error state and regression verification | P2 | Color analysis | Color pipeline | H | Desktop first | 6 |
| Scopes | Waveform scope | Waveform scope contract, UI/error state and regression verification | P2 | Color analysis | Color pipeline | H | Desktop first | 6 |
| Scopes | Vectorscope | Vectorscope contract, UI/error state and regression verification | P2 | Color analysis | Color pipeline | H | Desktop first | 6 |
| Scopes | Processing-point labels | Processing-point labels contract, UI/error state and regression verification | P2 | Color analysis | Color pipeline | H | Desktop first | 6 |
| Scopes | Async sampling | Async sampling contract, UI/error state and regression verification | P2 | Color analysis | Color pipeline | H | Desktop first | 6 |
| Scopes | HDR capability research | HDR capability research contract, UI/error state and regression verification | P2 | Color analysis | Color pipeline | H | Desktop first | 6 |
| AI | Transcription | Transcription contract, UI/error state and regression verification | P3 | AI adapters | Jobs, consent | H | Capability based | 7 |
| AI | Translation | Translation contract, UI/error state and regression verification | P3 | AI adapters | Jobs, consent | H | Capability based | 7 |
| AI | Speaker analysis | Speaker analysis contract, UI/error state and regression verification | P3 | AI adapters | Jobs, consent | H | Capability based | 7 |
| AI | Object tracking | Object tracking contract, UI/error state and regression verification | P3 | AI adapters | Jobs, consent | H | Capability based | 7 |
| AI | Background matte | Background matte contract, UI/error state and regression verification | P3 | AI adapters | Jobs, consent | H | Capability based | 7 |
| AI | Silence suggestions | Silence suggestions contract, UI/error state and regression verification | P3 | AI adapters | Jobs, consent | H | Capability based | 7 |
| AI | Smart cuts | Smart cuts contract, UI/error state and regression verification | P3 | AI adapters | Jobs, consent | H | Capability based | 7 |
| AI | Beat markers | Beat markers contract, UI/error state and regression verification | P3 | AI adapters | Jobs, consent | H | Capability based | 7 |
| AI | Auto reframe | Auto reframe contract, UI/error state and regression verification | P3 | AI adapters | Jobs, consent | H | Capability based | 7 |
| AI | Noise cleanup | Noise cleanup contract, UI/error state and regression verification | P3 | AI adapters | Jobs, consent | H | Capability based | 7 |
| AI | Speech enhancement | Speech enhancement contract, UI/error state and regression verification | P3 | AI adapters | Jobs, consent | H | Capability based | 7 |
| AI | Generative asset provenance | Generative asset provenance contract, UI/error state and regression verification | P3 | AI adapters | Jobs, consent | H | Capability based | 7 |
| AI | Model integrity | Model integrity contract, UI/error state and regression verification | P3 | AI adapters | Jobs, consent | H | Capability based | 7 |
| AI | Quality evaluation | Quality evaluation contract, UI/error state and regression verification | P3 | AI adapters | Jobs, consent | H | Capability based | 7 |
| Cloud | Accounts | Accounts contract, UI/error state and regression verification | P3 | Sync | Revision API, storage | H | Connected clients | 8 |
| Cloud | Cloud backup | Cloud backup contract, UI/error state and regression verification | P3 | Sync | Revision API, storage | H | Connected clients | 8 |
| Cloud | Resumable upload | Resumable upload contract, UI/error state and regression verification | P3 | Sync | Revision API, storage | H | Connected clients | 8 |
| Cloud | Blob identity | Blob identity contract, UI/error state and regression verification | P3 | Sync | Revision API, storage | H | Connected clients | 8 |
| Cloud | Cross-device mapping | Cross-device mapping contract, UI/error state and regression verification | P3 | Sync | Revision API, storage | H | Connected clients | 8 |
| Cloud | Conflict copies | Conflict copies contract, UI/error state and regression verification | P3 | Sync | Revision API, storage | H | Connected clients | 8 |
| Cloud | Revision preconditions | Revision preconditions contract, UI/error state and regression verification | P3 | Sync | Revision API, storage | H | Connected clients | 8 |
| Cloud | Comments | Comments contract, UI/error state and regression verification | P3 | Sync | Revision API, storage | H | Connected clients | 8 |
| Cloud | Presence | Presence contract, UI/error state and regression verification | P3 | Sync | Revision API, storage | H | Connected clients | 8 |
| Cloud | Operation reconciliation | Operation reconciliation contract, UI/error state and regression verification | P3 | Sync | Revision API, storage | H | Connected clients | 8 |
| Cloud | Remote version history | Remote version history contract, UI/error state and regression verification | P3 | Sync | Revision API, storage | H | Connected clients | 8 |
| Cloud | Account data export | Account data export contract, UI/error state and regression verification | P3 | Sync | Revision API, storage | H | Connected clients | 8 |
| Backend | Tenant isolation | Tenant isolation contract, UI/error state and regression verification | P0 | Service | Authorization, database | H | Server | 8 |
| Backend | Idempotency | Idempotency contract, UI/error state and regression verification | P0 | Service | Authorization, database | H | Server | 8 |
| Backend | Job persistence | Job persistence contract, UI/error state and regression verification | P0 | Service | Authorization, database | H | Server | 8 |
| Backend | Worker retries | Worker retries contract, UI/error state and regression verification | P0 | Service | Authorization, database | H | Server | 8 |
| Backend | API pagination | API pagination contract, UI/error state and regression verification | P0 | Service | Authorization, database | H | Server | 8 |
| Backend | Quota enforcement | Quota enforcement contract, UI/error state and regression verification | P0 | Service | Authorization, database | H | Server | 8 |
| Backend | Rate limits | Rate limits contract, UI/error state and regression verification | P0 | Service | Authorization, database | H | Server | 8 |
| Backend | Restore drills | Restore drills contract, UI/error state and regression verification | P0 | Service | Authorization, database | H | Server | 8 |
| Backend | Audit events | Audit events contract, UI/error state and regression verification | P0 | Service | Authorization, database | H | Server | 8 |
| Business | Free features | Free features contract, UI/error state and regression verification | P3 | Policy | Backend, review | H | Connected clients | 9 |
| Business | Pro entitlement | Pro entitlement contract, UI/error state and regression verification | P3 | Policy | Backend, review | H | Connected clients | 9 |
| Business | Cloud quota | Cloud quota contract, UI/error state and regression verification | P3 | Policy | Backend, review | H | Connected clients | 9 |
| Business | AI credits ledger | AI credits ledger contract, UI/error state and regression verification | P3 | Policy | Backend, review | H | Connected clients | 9 |
| Business | Premium asset access | Premium asset access contract, UI/error state and regression verification | P3 | Policy | Backend, review | H | Connected clients | 9 |
| Business | Purchase restoration | Purchase restoration contract, UI/error state and regression verification | P3 | Policy | Backend, review | H | Connected clients | 9 |
| Business | Offline access policy | Offline access policy contract, UI/error state and regression verification | P3 | Policy | Backend, review | H | Connected clients | 9 |
| Business | No duplicate settlement | No duplicate settlement contract, UI/error state and regression verification | P3 | Policy | Backend, review | H | Connected clients | 9 |
| Creators | Submission draft | Submission draft contract, UI/error state and regression verification | P3 | Catalog governance | Registry, services | H | Server and client | 9 |
| Creators | Automated validation | Automated validation contract, UI/error state and regression verification | P3 | Catalog governance | Registry, services | H | Server and client | 9 |
| Creators | Human review | Human review contract, UI/error state and regression verification | P3 | Catalog governance | Registry, services | H | Server and client | 9 |
| Creators | Provenance | Provenance contract, UI/error state and regression verification | P3 | Catalog governance | Registry, services | H | Server and client | 9 |
| Creators | Rights metadata | Rights metadata contract, UI/error state and regression verification | P3 | Catalog governance | Registry, services | H | Server and client | 9 |
| Creators | Moderation | Moderation contract, UI/error state and regression verification | P3 | Catalog governance | Registry, services | H | Server and client | 9 |
| Creators | Reports | Reports contract, UI/error state and regression verification | P3 | Catalog governance | Registry, services | H | Server and client | 9 |
| Creators | Appeals | Appeals contract, UI/error state and regression verification | P3 | Catalog governance | Registry, services | H | Server and client | 9 |
| Creators | Immutable publishing | Immutable publishing contract, UI/error state and regression verification | P3 | Catalog governance | Registry, services | H | Server and client | 9 |
| Creators | Takedown policy | Takedown policy contract, UI/error state and regression verification | P3 | Catalog governance | Registry, services | H | Server and client | 9 |
| Creators | Payout boundary | Payout boundary contract, UI/error state and regression verification | P3 | Catalog governance | Registry, services | H | Server and client | 9 |
| Plugins | Effect extension | Effect extension contract, UI/error state and regression verification | P3 | Plugin host | Security, APIs | H | Capability based | 10 |
| Plugins | Transition extension | Transition extension contract, UI/error state and regression verification | P3 | Plugin host | Security, APIs | H | Capability based | 10 |
| Plugins | Importer extension | Importer extension contract, UI/error state and regression verification | P3 | Plugin host | Security, APIs | H | Capability based | 10 |
| Plugins | Exporter extension | Exporter extension contract, UI/error state and regression verification | P3 | Plugin host | Security, APIs | H | Capability based | 10 |
| Plugins | AI extension | AI extension contract, UI/error state and regression verification | P3 | Plugin host | Security, APIs | H | Capability based | 10 |
| Plugins | Panel extension | Panel extension contract, UI/error state and regression verification | P3 | Plugin host | Security, APIs | H | Capability based | 10 |
| Plugins | Permission manifest | Permission manifest contract, UI/error state and regression verification | P3 | Plugin host | Security, APIs | H | Capability based | 10 |
| Plugins | IPC validation | IPC validation contract, UI/error state and regression verification | P3 | Plugin host | Security, APIs | H | Capability based | 10 |
| Plugins | Isolation | Isolation contract, UI/error state and regression verification | P3 | Plugin host | Security, APIs | H | Capability based | 10 |
| Plugins | Resource quotas | Resource quotas contract, UI/error state and regression verification | P3 | Plugin host | Security, APIs | H | Capability based | 10 |
| Plugins | API negotiation | API negotiation contract, UI/error state and regression verification | P3 | Plugin host | Security, APIs | H | Capability based | 10 |
| Plugins | Missing-plugin recovery | Missing-plugin recovery contract, UI/error state and regression verification | P3 | Plugin host | Security, APIs | H | Capability based | 10 |
| Platforms | Windows runtime | Windows runtime contract, UI/error state and regression verification | P3 | Adapters | Conformance suite | H | Platform specific | 10 |
| Platforms | macOS adapter | macOS adapter contract, UI/error state and regression verification | P3 | Adapters | Conformance suite | H | Platform specific | 10 |
| Platforms | Android lifecycle | Android lifecycle contract, UI/error state and regression verification | P3 | Adapters | Conformance suite | H | Platform specific | 10 |
| Platforms | iOS lifecycle | iOS lifecycle contract, UI/error state and regression verification | P3 | Adapters | Conformance suite | H | Platform specific | 10 |
| Platforms | Web capability profile | Web capability profile contract, UI/error state and regression verification | P3 | Adapters | Conformance suite | H | Platform specific | 10 |
| Platforms | Cross-platform font policy | Cross-platform font policy contract, UI/error state and regression verification | P3 | Adapters | Conformance suite | H | Platform specific | 10 |
| Platforms | Install-drive selection | Install-drive selection contract, UI/error state and regression verification | P3 | Adapters | Conformance suite | H | Platform specific | 10 |
| Platforms | Offline runtime verification | Offline runtime verification contract, UI/error state and regression verification | P3 | Adapters | Conformance suite | H | Platform specific | 10 |
| Quality | Domain tests | Domain tests contract, UI/error state and regression verification | P0 | Test infrastructure | Fixtures | H | All | 0 |
| Quality | Property tests | Property tests contract, UI/error state and regression verification | P0 | Test infrastructure | Fixtures | H | All | 0 |
| Quality | Render comparisons | Render comparisons contract, UI/error state and regression verification | P0 | Test infrastructure | Fixtures | H | All | 0 |
| Quality | Save failure injection | Save failure injection contract, UI/error state and regression verification | P0 | Test infrastructure | Fixtures | H | All | 0 |
| Quality | Export cancellation checks | Export cancellation checks contract, UI/error state and regression verification | P0 | Test infrastructure | Fixtures | H | All | 0 |
| Quality | UI interaction tests | UI interaction tests contract, UI/error state and regression verification | P0 | Test infrastructure | Fixtures | H | All | 0 |
| Quality | Backend isolation tests | Backend isolation tests contract, UI/error state and regression verification | P0 | Test infrastructure | Fixtures | H | All | 0 |
| Quality | Package validation tests | Package validation tests contract, UI/error state and regression verification | P0 | Test infrastructure | Fixtures | H | All | 0 |
| Quality | Performance benchmarks | Performance benchmarks contract, UI/error state and regression verification | P0 | Test infrastructure | Fixtures | H | All | 0 |
| Quality | Diagnostics redaction | Diagnostics redaction contract, UI/error state and regression verification | P0 | Test infrastructure | Fixtures | H | All | 0 |
| UX | Resizable panels | Resizable panels contract, UI/error state and regression verification | P1 | UI system | Commands, semantics | M | All | 1 |
| UX | Dock layout | Dock layout contract, UI/error state and regression verification | P1 | UI system | Commands, semantics | M | All | 1 |
| UX | Reset layout | Reset layout contract, UI/error state and regression verification | P1 | UI system | Commands, semantics | M | All | 1 |
| UX | Context menus | Context menus contract, UI/error state and regression verification | P1 | UI system | Commands, semantics | M | All | 1 |
| UX | Shortcut editor | Shortcut editor contract, UI/error state and regression verification | P1 | UI system | Commands, semantics | M | All | 1 |
| UX | Hover states | Hover states contract, UI/error state and regression verification | P1 | UI system | Commands, semantics | M | All | 1 |
| UX | Focus states | Focus states contract, UI/error state and regression verification | P1 | UI system | Commands, semantics | M | All | 1 |
| UX | Multiselect | Multiselect contract, UI/error state and regression verification | P1 | UI system | Commands, semantics | M | All | 1 |
| UX | Keyboard alternatives | Keyboard alternatives contract, UI/error state and regression verification | P1 | UI system | Commands, semantics | M | All | 1 |
| UX | Screen reader labels | Screen reader labels contract, UI/error state and regression verification | P1 | UI system | Commands, semantics | M | All | 1 |
| UX | Contrast review | Contrast review contract, UI/error state and regression verification | P1 | UI system | Commands, semantics | M | All | 1 |
| UX | Reduced motion | Reduced motion contract, UI/error state and regression verification | P1 | UI system | Commands, semantics | M | All | 1 |
| UX | Responsive layout | Responsive layout contract, UI/error state and regression verification | P1 | UI system | Commands, semantics | M | All | 1 |
| UX | RTL | RTL contract, UI/error state and regression verification | P1 | UI system | Commands, semantics | M | All | 1 |
| UX | Localized numbers | Localized numbers contract, UI/error state and regression verification | P1 | UI system | Commands, semantics | M | All | 1 |
| UX | Khmer UI fonts | Khmer UI fonts contract, UI/error state and regression verification | P1 | UI system | Commands, semantics | M | All | 1 |

Inventory: 358 feature entries. Each row must acquire a concrete feature specification and evidence before being marked verified. The repeated verification reminder is not a substitute for feature-specific tests in the relevant companion specification.

