# Master dictionary

The bilingual columns are intentional here, as requested. The English and Khmer books remain separate. Definitions are explanatory and use the proposed Klipio contracts.

| English term | Simple English | Khmer explanation | Professional meaning | Klipio example |
|---|---|---|---|---|
| Asset | Reusable source material | ប្រភព media ដែលអាចប្រើឡើងវិញ | Stable media identity independent of instances | One file used by three clips |
| Clip | One timed use of media | ការប្រើ media មួយលើ timeline | Instance with source map and placement | Trim one use without changing others |
| Track | A lane for clips | ជួរសម្រាប់រៀប clips | Ordered/layered collection with policy | V1 picture, A1 music |
| Sequence | An editable composition | composition មានពេលនិងទំហំផ្ទាល់ | Timeline plus output and nesting context | A 3:4 project sequence |
| Frame | One picture sample | រូបភាពមួយ sample | Decoded or rendered temporal image sample | Numbered test frame |
| FPS | Frames per second | ចំនួន frames ក្នុងមួយវិនាទី | Rational frame frequency for constant-rate output | 30-frame stepping |
| Timebase | Timestamp units | ឯកតាដែលប្រើសម្រាប់ timestamp | Rate defining timestamp interpretation | Ticks at an explicit rate |
| Timestamp | A sample's time | ពេលរបស់ sample | Timed position in a declared domain | Source presentation time |
| PTS | When to present a sample | ពេលត្រូវបង្ហាញ sample | Presentation timestamp, distinct from decode ordering | Choose visible source frame |
| VFR | Uneven frame timing | ចន្លោះពេល frames មិនស្មើ | Variable-frame-rate media uses actual timestamps | Phone video import |
| Source time | Time inside original media | ពេលនៅក្នុង source ដើម | Time before sequence placement/remapping | Source 13 seconds |
| Sequence time | Time in the edit | ពេលនៅក្នុង composition | Composition clock position | Playhead 6.5 seconds |
| Time map | Output-to-source relation | ទំនាក់ទំនង output time ទៅ source time | Function used for retimed evaluation | 2x speed mapping |
| Half-open interval | Start included, end excluded | រួម start មិនរួម end | Boundary convention avoiding double ownership | [5,9) clip |
| Resolution | Pixel dimensions | ទំហំគិតជា pixels | Width and height of raster output | 810×1080 |
| Aspect ratio | Width compared with height | សមាមាត្រទទឹងនិងកម្ពស់ | Display/composition shape ratio | 3:4 |
| Codec | Compression method | វិធីបង្ហាប់ media | Encoding/decoding scheme | H.264 profile selection |
| Container | Stream package | ប្រអប់ផ្ទុក streams | File structure carrying streams and metadata | MP4 output |
| Bitrate | Bits per second | ទិន្នន័យ bits ក្នុងមួយវិនាទី | Rate target or measured encoded throughput | Export quality policy |
| Pixel format | How components are stored | របៀបផ្ទុក components រូបភាព | Packing, precision and subsampling representation | RGBA8 cache surface |
| Color space | Meaning of color values | ន័យពណ៌របស់តម្លៃ | Color interpretation and associated conventions | Declared working pipeline |
| Transfer function | Encoded-light relationship | ទំនាក់ទំនងតម្លៃ encoded និងពន្លឺ | Mapping used in color encoding/decoding | Source conversion policy |
| Alpha | Coverage/transparency | កម្រិតគ្របដណ្តប់ឬថ្លា | Opacity/coverage channel with representation rules | Sticker edge |
| Premultiplied alpha | Color already weighted by alpha | ពណ៌បានគុណនឹង alpha | Representation requiring matching blend equations | Source-over compositor |
| Decode | Uncompress samples | បម្លែង compressed data ទៅ samples | Media reconstruction process | Preview source decoder |
| Encode | Compress samples | បង្ហាប់ samples | Codec output generation | Final video encoder |
| Render | Compute final composition | គណនា composition ចុងក្រោយ | Evaluate layers and processing at output time | Canvas plus captions |
| Mux | Combine streams | រួម streams | Write encoded streams into container | Audio/video MP4 |
| Demux | Separate streams | បំបែក streams | Extract packets and stream metadata | Read source audio |
| Proxy | Lighter source version | media ស្រាលជំនួសសម្រាប់ edit | Derived media with preserved mapping | Low-resolution preview |
| Cache | Reusable temporary result | លទ្ធផលបណ្តោះអាសន្នអាច reuse | Derived data keyed by full computation identity | Thumbnail store |
| Fingerprint | Source identity evidence | សញ្ញាសម្គាល់ប្រភព | Digest/metadata identity used for validation | Detect changed source |
| Thumbnail | Small preview image | រូបតូចសម្រាប់ preview | Derived image at a known source time | Clip filmstrip |
| Waveform | Amplitude overview | រូបសង្ខេប amplitude សំឡេង | Multiresolution sample summary | Audio editing display |
| Sample rate | Audio samples per second | ចំនួន audio samples ក្នុងវិនាទី | Audio temporal sampling frequency | 48 kHz mix |
| Audio clock | Playback timing reference | នាឡិកាសម្រាប់ playback | Clock driving synchronized presentation | Avoid long A/V drift |
| Trim | Change an edge | កែចុង clip | Boundary/source-range operation | Shorten clip end |
| Split | Divide a clip | បំបែក clip | Partition placement/source interval | Cut at playhead |
| Ripple | Shift downstream content | រំកិល content ខាងក្រោយ | Edit policy closing/opening time across eligible items | Delete gap |
| Roll | Move a shared boundary | រំកិល boundary រួម | Two-clip edit preserving pair duration | Adjust cut point |
| Slip | Change source within same placement | កែ source ដោយរក្សា placement | Source-range shift with fixed duration | Choose another moment |
| Slide | Move clip while adjusting neighbors | ផ្លាស់ clip និងសម្រួល neighbors | Three-clip edit retaining selected source | Reposition insert |
| Snapping | Align near a target | ទាញឱ្យត្រូវគោលដៅជិត | Interaction tolerance policy | Snap to marker |
| Magnetic timeline | Automatic adjacency policy | ច្បាប់រក្សា clips ជាប់គ្នា | Command policy, not a separate time model | Primary-track ripple |
| Keyframe | A property value at time | តម្លៃ property នៅពេលមួយ | Typed timed control point | Scale at second 2 |
| Interpolation | Values between keys | គណនាតម្លៃចន្លោះ keys | Type-specific evaluation | Smooth position |
| Easing | Change motion progression | កែរបៀបចលនារីកចម្រើន | Time-to-progress mapping | Slow entrance |
| Anchor | Transform pivot | ចំណុចមូលដ្ឋាន transform | Reference point before rotation/scale | Rotate around center |
| Contain | Fit without cropping | បង្ហាញទាំងមូលក្នុង canvas | Minimum dimension fit scale | Letterboxed source |
| Cover | Fill while cropping | បំពេញ canvas ដោយ crop | Maximum dimension fit scale | Full portrait fill |
| Mask | Coverage shape | រូបរាងកំណត់ coverage | Spatial/temporal alpha modifier | Ellipse reveal |
| LUT | Color lookup table | តារាងផ្គូផ្គងពណ៌ | Domain-specific color mapping data | Pinned color look |
| Render graph | Processing dependency graph | បណ្តាញលំដាប់ processing | Directed computation graph | Decode→effect→composite |
| Snapshot | Fixed state copy | state ដែលចាប់ទុកថេរ | Immutable revision view | Export ignores later edits |
| Revision | State version | version នៃ state | Monotonic/project history identity | Reject stale command |
| Command | Named edit request | សំណើកែមានឈ្មោះ | Validated state transition input | MoveClip |
| Transaction | All-or-nothing group | ក្រុមការងារជោគជ័យទាំងមូលឬមិនកែ | Atomic coordinated state change | Apply selected to targets |
| Undo | Restore prior edit state | ស្តារ state មុនកែ | Inverse/history operation | Restore deleted clip |
| Idempotency | Retry without duplication | retry មិនបង្កើតស្ទួន | Same operation identity has one intended effect | AI job retry |
| Generation token | Newest-request marker | សញ្ញាសម្គាល់ request ថ្មីបំផុត | Stale-result rejection mechanism | Rapid seek handling |
| Backpressure | Limit incoming work | ទប់ការងារមិនឱ្យលើសសមត្ថភាព | Bounded admission/queue control | Thumbnail queue cap |
| Virtualization | Build visible items only | បង្កើត UI តែផ្នែកមើលឃើញ | Viewport-driven materialization | Large timeline |
| Manifest | Package description | ឯកសារពិពណ៌នា package | Versioned metadata and file/dependency contract | Content installation |
| Definition | Reusable behavior description | ការពិពណ៌នាអាច reuse | Versioned supported primitive/preset schema | Blur definition |
| Instance | One use of a definition | ការប្រើ definition មួយ | Project-owned values and overrides | Clip blur radius 8 |
| Version pin | Keep exact dependency version | ចាក់ version dependency ឱ្យថេរ | Reproducible content resolution | Old caption style unchanged |
| Migration | Upgrade stored structure | បម្លែង structure ដែល save | Ordered validated schema transformation | Open older project |
| Atomic save | Replace without partial state | save មិនទុក state ពាក់កណ្តាល | Platform-safe commit after complete write | Recovery-safe project |
| Shaping | Turn text into positioned glyphs | បម្លែង text ទៅ glyphs ត្រឹមត្រូវ | Script-aware glyph selection/positioning | Khmer captions |
| Glyph cluster | Related text shaping unit | ក្រុមអក្សរដែល shaping ជាមួយគ្នា | Mapping unit between text and glyphs | Karaoke without broken vowels |
| Entitlement | Permission to use an offering | សិទ្ធិប្រើ feature ឬ content | Business access decision outside rendering | Pro asset download |
| Sandbox | Restricted execution environment | បរិស្ថានកំណត់សិទ្ធិរត់ | Enforced resource/access boundary | Untrusted plugin host |
| CDN | Distributed delivery cache | បណ្តាញចែកចាយ content | Content delivery infrastructure | Asset package download |
| Conformance | Agreement with a contract | ភាពត្រូវតាម contract | Verified behavioral compatibility | Preview/export test |
| Observability | Understand internal behavior | យល់អ្វីកើតនៅក្នុងប្រព័ន្ធ | Logs/metrics/traces supporting diagnosis | Stalled export phase |

