# KLIPIO MASTER BLUEPRINT
## ពីចំណុចសូន្យទៅកាន់ Professional Video Editing Platform — សៀវភៅភាសាខ្មែរ

កំណែទី 1 • 2026-09-07 • នេះជា Architecture proposal សម្រាប់អនាគត មិនមែនជារបាយការណ៍ថា features ទាំងអស់បាន build រួចទេ។

សៀវភៅនេះរៀបចំទិសដៅ Klipio ថ្មី។ CapCut និង Filmora ជាឧទាហរណ៍នៃវិសាលភាព product ប៉ុណ្ណោះ។ យើងមិនអះអាងថាដឹង architecture ខាងក្នុងរបស់ពួកគេ ហើយមិនចម្លង code ឬ assets របស់ពួកគេទេ។ Test ដែលសរសេរនៅទីនេះគឺលក្ខខណ្ឌត្រូវសាកល្បង មិនមែនជាលទ្ធផលដែលបានរត់រួច។

ចាប់ផ្តើមពី Part 0–10។ បន្ទាប់មក build workflow តូចមួយឱ្យចប់៖ import → timeline → preview → save → export។ កុំ build cloud, marketplace និង plugins ទាំងអស់ក្នុងពេលតែមួយ។ ឯកសារបន្ថែមនៅក្នុង knowledge library មាន contracts, roadmap, feature matrix និងលំហាត់។

## ការកែសម្រួល Knowledge System — 2026-09-07

Product គឺ Klipio។ Editor ផ្សេងជាឯកសារយោងខាងក្រៅប៉ុណ្ណោះ មិនមែនឈ្មោះ module ឬ component របស់ Klipio។

សៀវភៅនេះជា Blueprint។ [Current implementation status](../CURRENT_IMPLEMENTATION_STATUS.md) ប្រាប់អ្វីដែលបានពិនិត្យក្នុង source/tests និងអ្វីដែលនៅមិនច្បាស់។ មាន code ឬ test file មិនមានន័យថា Verified ឬ Released ទេ។

អានបន្ត [UI System](../03_UI_UX_DESIGN_SYSTEM/Design-System.md), [Persistence](../15_PROJECT_PERSISTENCE/Specification.md), [Audio](../16_AUDIO_ENGINE/Specification.md), [Text](../17_TEXT_CAPTION_ENGINE/Text-Engine.md), [Captions](../17_TEXT_CAPTION_ENGINE/Caption-Engine.md) និង [Benchmark](../18_PERFORMANCE_BENCHMARKS/Benchmark-Protocol.md)។ វាជា specifications មិនមែនការអះអាងថាបាន implement រួច។ Benchmark មិនទាន់មានលទ្ធផលវាស់ថ្មីទេ។


## Part 0 — ទស្សនវិស័យទាំងមូល

Video editor គឺជាប្រព័ន្ធបម្លែងបំណងរបស់អ្នកកាត់តទៅជា composition ដែលអាចរក្សាទុក និង render ឡើងវិញបាន។ គោលសន្យាសំខាន់គឺ project ដែល save, preview ដែលមើល និង video ដែល export ត្រូវតំណាងឱ្យការកែដូចគ្នា។ ចំនួន buttons ឬ effects មិនអាចជំនួសភាពត្រឹមត្រូវនេះបានទេ។

Klipio គួរជា local-first។ Import, edit, save និង export មូលដ្ឋានត្រូវធ្វើបានដោយគ្មាន account។ Cloud ជាជម្រើសបន្ថែមសម្រាប់ backup, sync, AI និង content delivery។ បើ source drive មិនភ្ជាប់ app ត្រូវប្រាប់ថា media offline មិនមែនថា project ខូចទេ។

ផែនទី platform៖

```text
Desktop / Mobile / Web
          |
Commands + Project State
          |
Timeline / Media / Render / Audio
       /                    \
    Preview                Export
          |
Content Registry / Templates / Fonts / Effects / Music
          |
Optional Cloud / Accounts / AI / Creator Platform
          |
Database / Object Storage / CDN / Workers
```

លំហាត់៖ សរសេររឿងអ្នកប្រើម្នាក់ import video, កាត់, ដាក់ caption ហើយ export។ សម្គាល់ system នីមួយៗដែលចូលរួម។ Feature ណាដែលមិនអាចប្រាប់ថាដោះស្រាយបញ្ហាអ្វី គួររង់ចាំ។

## Part 1 — មូលដ្ឋាន video editing

Asset ជាប្រភព media។ Clip ជាការប្រើ asset មួយនៅពេលជាក់លាក់លើ timeline។ Asset ដូចគ្នាអាចមាន clips ច្រើនដែល crop, speed និង source range ខុសគ្នា។ Track រៀប clips តាមពេល ឬជាស្រទាប់។ Sequence ជា composition មានទំហំ, timebase និង tracks របស់ខ្លួន។

Frame ជារូបភាពមួយ sample។ FPS ជាចំនួន frame ក្នុងមួយវិនាទី។ ប៉ុន្តែ variable-frame-rate media ត្រូវអាន presentation timestamps មិនមែនគិត frameNumber/FPS ជានិច្ចទេ។ Timebase កំណត់ឯកតានៃ timestamp។ រក្សាពេលជាចំនួន ticks ដែលមាន rate ឬ rational time ដើម្បីជៀសវាងកំហុសបូក floating point យូរៗ។

Resolution ជាចំនួន pixels; aspect ratio ជារាងទទឹងធៀបកម្ពស់។ Codec ជាវិធីបង្ហាប់; container ជាប្រអប់ផ្ទុក streams។ Bitrate មិនស្មើនឹងគុណភាពដោយផ្ទាល់ទេ។ Pixel format ប្រាប់របៀបផ្ទុក components; color space ប្រាប់ន័យពណ៌របស់តម្លៃ។

Decode បម្លែង compressed data ទៅ samples; encode ធ្វើការបង្ហាប់។ Demux បំបែក streams; mux រួម streams។ Render គណនារូបភាព និងសំឡេងចុងក្រោយ។ Proxy ជា media ស្រាលសម្រាប់ធ្វើការ; cache ជាទិន្នន័យអាចបង្កើតឡើងវិញ។ ទាំងពីរមិនមែន source of truth នៃ edit ទេ។

Audio 48,000 samples/second មិនមែន video 48,000 FPS ទេ។ Waveform គ្រាន់តែសង្ខេប amplitude។ GPU ជួយការងារ pixels ដែលធ្វើស្របគ្នាបាន ប៉ុន្តែមាន memory និង transfer cost។

ឧទាហរណ៍៖ source 1920×1080 ក្នុង canvas 810×1080 គឺ 3:4។ Export label “1080p” មិនប្រាប់ width គ្រប់គ្រាន់ទេ។ Sequence 10 វិនាទីនៅ 30 FPS មាន 300 frame intervals។ សិក្សាបន្ថែមពី [OpenTimelineIO time ranges](https://opentimelineio.readthedocs.io/en/v0.18.1/tutorials/time-ranges.html)។

## Part 2 — Architecture របស់ product

Presentation ទទួល interaction ហើយបញ្ជូន intent។ Application រៀបចំ use case។ Domain ឬ Editor Core ពិនិត្យច្បាប់ និងកែ project state។ Infrastructure ធ្វើ file I/O, process, decode និង network តាម interfaces។

Dependency ត្រូវទៅខាងក្នុង៖ UI → Application → Domain។ Domain មិនគួរ import Flutter widgets, HTTP client ឬ payment screen ទេ។ Startup ជាកន្លែងភ្ជាប់ concrete adapters។

```text
Gesture → Command → Validate → New revision
                                  |
                            Immutable snapshot
                                  |
                           Timeline resolver
                                  |
                             Render graph
                           /            \
                       Preview         Export
```

UI មើល state តាម selectors។ Worker result ត្រូវមាន asset ID និង request generation។ Result ចាស់មិនអាចមកសរសេរលើ video ដែលអ្នកទើបជ្រើសថ្មីបានទេ។

ចាប់ផ្តើមជា modular monolith។ មិនចាំបាច់ធ្វើ microservices រាប់សិបទេ។ បំបែក package ពេលមាន ownership ឬ reuse ពិតប្រាកដ។ បំបែក file ធំទៅ extension files ដែលនៅប្រើ state ដូចគ្នា គឺបំបែករូបរាង ប៉ុន្តែមិនទាន់បំបែក responsibility ពេញលេញទេ។

Test៖ SplitClip ត្រូវរត់ក្នុង memory ដោយមិនបើក window ឬ internet។

## Part 3 — UI របស់ professional editor

Home មាន recent projects, recovery និង job summaries។ Workspace មាន top bar, media browser, source monitor, program monitor, timeline និង inspector។ Source monitor បង្ហាញ source; program monitor បង្ហាញ composition ក្រោយកែ។

មាន browsers សម្រាប់ effects, transitions, text និង panels សម្រាប់ captions, audio, color, animation។ Export dialog ត្រូវបង្ហាញ profile, destination, validation និង job details។ Settings និង shortcut editor មិនគួរចូលក្នុង project render state ទេ។

Panels អាច resize និង dock មាន minimum size និង reset layout។ Window តូចគួរប្តូរទៅ tabs/drawers មិនមែនលាក់ controls ក្រៅអេក្រង់។ Layout ជា user preference មិនមែនការកែ video។

Selected asset, selected clip និង clip ក្រោម playhead មិនដូចគ្នាទេ។ Inspector ត្រូវប្រាប់ច្បាស់ថាកំពុងកែអ្វី។ Multiselect បង្ហាញ mixed values; កែ scale មិនគួរប្តូរ volume ដោយស្ងៀមស្ងាត់។

Drag បង្ហាញ preview បណ្តោះអាសន្ន ហើយ commit ម្តងពេលលែង mouse។ Escape បោះបង់។ Toolbar, context menu និង shortcut ត្រូវហៅ command ដូចគ្នា។

Test workflow ដោយ keyboard, window តូច, text ធំ និង screen reader។ Cancel ត្រូវអាចប្រើបានពេល worker រវល់។

## Part 4 — Design System

ប្រើ semantic tokens ដូចជា surface/base, text/primary, border/default, action/primary, state/error, selection និង focus។ Widget មិនគួរបង្កើតពណ៌ថ្មីដោយខ្លួនឯងគ្រប់កន្លែងទេ។

អាចចាប់ផ្តើម spacing 4/8/12/16/24/32 logical pixels និង density ពីរប្រភេទ។ Typography មាន body, label, heading និង timecode។ តម្លៃទាំងនេះជាសំណើដែលត្រូវសាកល្បង មិនមែនច្បាប់សកល។

បង្កើត Button, NumericField, SliderField, Dropdown, Tabs, Menu, Dialog, Tooltip, Panel, InspectorRow, AssetCard និង TimelineHandle។ គ្រប់ component មាន default, hover, focus, pressed, disabled, loading និង error states។

Numeric field ត្រូវមាន units, precise input, reset និង validation។ Slider ផ្តល់ transient updates ប៉ុន្តែបង្កើត undo step តែមួយសម្រាប់ drag មួយ។ Asset card ត្រូវបំបែក loading ពី failed និង not installed។

រក្សា component gallery និង screenshot tests សម្រាប់ themes និងភាសា។ យោង [WCAG 2.2](https://www.w3.org/TR/WCAG22/) ពេលពិនិត្យ accessibility ប៉ុន្តែត្រូវ test native desktop ផងដែរ។

## Part 5 — Timeline Engine

ប្រើ interval [start,end) មានន័យថារួម start ប៉ុន្តែមិនរួម end។ វាជួយកុំឱ្យ frames នៅ boundary ជាន់គ្នា។

បើ clip ដាក់នៅ sequence T, source in-point S និង speed r > 0 នោះ sourceTime = S + (sequenceTime − T)r។ Source span D មាន output duration D/r។

ឧទាហរណ៍៖ source [10,18), speed 2, ដាក់នៅ sequence 5។ Output គឺ [5,9)។ Split នៅ sequence 6.5 ត្រូវ source 13។ ផ្នែកឆ្វេង [10,13), ស្តាំ [13,18)។ មិនត្រូវ reset source របស់ផ្នែកស្តាំទៅ 0 ទេ។

Trim កែ boundary និង source endpoint។ Move កែ placement ប៉ុណ្ណោះ។ Slip កែ source range ដោយទុក placement/duration។ Roll កែ boundary រួមរបស់ clips ពីរ ដោយរក្សា total duration។ Slide ផ្លាស់ clip ហើយសម្រួល neighbors។ Ripple delete លុប interval និងរំកិល downstream clips តាម policy។

Linked audio/video ប្រើ edit intent រួម តែមាន clip IDs ផ្សេងគ្នា។ Groups ជួយ selection; compound clips យោង nested sequences។ ត្រូវហាម sequence cycles។

Magnetic mode ជា command policy មិនមែន engine ទីពីរ។ កំណត់ tracks ណាចូលរួម និងបើមាន locked track ត្រូវ reject transaction ឬដោះស្រាយយ៉ាងណាឱ្យច្បាស់។

រូបមន្ត screen៖ x = originX + (t − scrollTime) × pixelsPerSecond។ Snap tolerance ពេលវេលា = snapPixels / pixelsPerSecond។ Ruler, playhead និង drag ត្រូវប្រើ mapping ដូចគ្នា។

Test split boundary, undo IDs, ripple links, speed trim និង locked tracks។ Random command sequences អាចរកកំហុសដែល manual test មិនឃើញ។

## Part 6 — Command និង History

Command ជាសំណើមានឈ្មោះ និង inputs ច្បាស់ ដូចជា MoveClip(clipId,newStart,expectedRevision)។ Handler ពិនិត្យ lock, identity, overlap និង revision មុន commit។

Undo ត្រូវមានទិន្នន័យគ្រប់គ្រាន់ដើម្បីស្តារ state។ Split រក្សា original និង replacement clips; Delete រក្សា effects និង links; AddEffect រក្សា stack position។ កុំបង្កើត IDs ថ្មីចៃដន្យពេល redo។

Transaction ប្រមូល edits ដែលទាក់ទងគ្នា។ Drag 200 pointer events គួរមាន undo step មួយ។ Command បរាជ័យមិនបង្កើត partial state ឬ history entry ទេ។

External actions ដូចជាទិញ asset ឬបង់ថ្លៃ AI មិនអាច undo ដូច trim ទេ។ Undo អាចលុប caption layer ប៉ុន្តែមិនសង AI credits ដោយស្វ័យប្រវត្តិ។

Test execute→undo→redo ឱ្យ state ស្មើគ្នា រួមទាំង order, links និង metadata។ កំណត់ history memory limit។

## Part 7 — Media Engine

Import pipeline៖ validate → asset ID → probe → metadata → background poster/waveform/proxy។ កុំរង់ចាំ thumbnails ទាំងអស់ទើបអនុញ្ញាត edit។

Asset មាន locator, managed relative path, fingerprint, stream IDs, duration, rotation, dimensions និង color metadata។ Filename គ្រាន់តែ label មិនមែន identity។

Thumbnail key ត្រូវមាន asset fingerprint, source timestamp, stream, decoder version, rotation និង size។ Timeline strip sample តាម source range របស់ clip។ Video 2 មិនត្រូវប្រើ cache key របស់ Video 1 ទេ។

Waveform មាន resolution levels។ Proxy ត្រូវរក្សា timestamp mapping ទៅ original។ Relink ត្រូវពិនិត្យ duration/streams ហើយព្រមានបើមិនត្រូវ។ Offline media មិនគួរធ្វើឱ្យ timeline បាត់។

Video, image, GIF, audio, SVG, subtitle, font និង template មាន validation ខុសគ្នា។ Untrusted SVG ឬ archive មិនត្រូវអាច execute code។

Test import 7 videos, switch លឿន, cache eviction, retry, Unicode paths, duplicate names និង disconnected drive។ Cache rebuild មិនត្រូវកែ project។

## Part 8 — Playback Engine

Playback ជា state machine៖ idle, preparing, ready, playing, seeking, buffering, failed, disposed។ Player object មានមិនមាន មិនគ្រប់គ្រាន់សម្រាប់សម្រេចថារួចរាល់ទេ។

ប្រើ audio clock ពេលសំឡេងលេង និង monotonic clock ពេលគ្មាន audio។ Sequence time ត្រូវ resolve ទៅ source time មុន decode។

Seek មាន generation។ Result ចាស់ត្រូវចោលបើមាន seek ថ្មី។ Scrub អាចប្រើ low quality បណ្តោះអាសន្ន; ពេលលែង pointer ស្នើ accurate frame។ Frame stepping ជា sequence frame interval មិនមែន source frame ចៃដន្យ។

Preload ជុំវិញ playhead តាម bounded queue។ Preview អាច drop frame ដើម្បីតាម clock ប៉ុន្តែ export មិនអាចរំលង required output frames។

Proxy និង preview resolution មិនគួរប្តូរ geometry ឬ captions។ Test seek bursts, speed boundaries, A/V drift, device loss និង loops។

## Part 9 — Rendering Engine

Scene ជាការពិពណ៌នាអ្វីត្រូវបង្ហាញនៅពេល t។ Render graph ជាបណ្តាញ nodes ដូចជា decode, transform, color, mask, effect, text និង composite។

បង្កើត RenderPlan ពី immutable project revision, content versions និង output profile។ Preview និង export ប្រើ semantics ដូចគ្នា។ ប្រើ JSON ដូចគ្នាមិនធានា pixels ដូចគ្នាទេ បើ backends បកស្រាយខុស។

Dirty subgraph invalidation ជួយកុំ render គ្រប់យ៉ាងឡើងវិញ។ កែ text color មិនគួរបង្កើត source decoders ថ្មីទាំងអស់។ Cache key រួម parameters, time, inputs, engine version និង color policy។

GPU មានប្រយោជន៍សម្រាប់ pixel parallelism ប៉ុន្តែ transfer និង texture memory មានថ្លៃ។ CPU fallback ត្រូវមាន contract ច្បាស់។ កំណត់ alpha, blend order, coordinate convention និង sampling។

Test រូបភាពនៅ timestamp ដូចគ្នា ក្នុង 3:4, 9:16, 1:1 និង 16:9 មាន blur, crop, scale, rotation និង captions។

## Part 10 — Transform System

បំបែក source pixels, normalized source, composition pixels, normalized composition និង screen logical pixels។ Mouse position ជា screen space; export ជា composition space។ កុំ save ទំហំ widget ជាទំហំ caption។

សំណើ matrix៖ M = Translation(position) × Rotation × Scale × Translation(−anchor)។ Crop ប្រើ declared source space មុន fit។ Flip អាចប្រើ signed scale ក្នុង math ប៉ុន្តែ UI បង្ហាញជាផ្នែកដាច់ដោយឡែក។

Contain = min(canvasW/sourceW,canvasH/sourceH); cover = max។ Source 1920×1080 ទៅ 810×1080 មាន contain 0.421875 និង cover 1។ User scale គុណលើ fit នេះ។

Canvas background ជា layer ដាច់ពី foreground។ ប្តូរ foreground position មិនត្រូវប្តូរ blur background ដោយចៃដន្យ។

Gizmo បម្លែង pointer តាម inverse matrix។ Reset ស្តារតម្លៃដែលបានកំណត់សម្រាប់ selected clip មិនមែន snapshot ចាស់របស់ Apply all។ Test anchors, flip, rotation និង export parity។

## Part 11 — Text Engine

Text pipeline មាន Unicode segmentation, shaping, glyph layout, rasterization, stroke/shadow/background និង animation។ Khmer ត្រូវការ shaping ត្រឹមត្រូវ មិនមែនជ្រើស font ហើយចប់ទេ។

រក្សា font asset/version, font size ក្នុង composition units, wrapping, alignment, line/letter spacing និង decoration។ Missing font ត្រូវមាន fallback policy និង warning ព្រោះ layout អាចផ្លាស់។

TextStyleDefinition ជា content អាច reuse; TextInstance មាន user text និង overrides។ Styles រាប់រយប្រើ primitives ដូចគ្នា។ JSON មិនអាចបង្កើត rendering primitive ដែល engine មិនទាន់គាំទ្រ។

Curved text និង path ត្រូវរក្សា glyph clusters។ Animation មិនត្រូវបំបែកស្រៈខ្មែរចេញពី cluster។

ចាប់ផ្តើម plain text និង wrapping មុន presets និង per-word animation។ Test Khmer, emoji, multiline, mixed scripts, missing fonts និង preview/export metrics។

## Part 12 — Effect Engine

Effect definition មាន implementation ID/version, parameter schema, capabilities និង preview assets។ Effect instance មាន values, enabled state និង animation tracks។ Stack order មានន័យ។

Parameter មាន type, units, limits, default និង interpolation។ UI អាចបង្កើត controls ពី schema មិនចាំបាច់ hard-code effect នីមួយៗ។

Blur, distortion, glitch, glow, retro, lens, motion, light, noise, stylize, color, VHS, camera, party, dream និង comic ជា categories/presets ដែលអាច reuse primitives។ Primitive ថ្មីនៅតែត្រូវសរសេរ engine code។

Shader ត្រូវប្រកាស input/output និង alpha/color rules។ Temporal effect ត្រូវប្រាប់ថាត្រូវការ frames មុន/ក្រោយ។ Random effect ត្រូវមាន seed ដើម្បី render ដូចគ្នាពេល seek ឡើងវិញ។

Test invalid parameters, reorder, disabled effect, CPU/GPU comparison និង unsupported package។ កុំអនុញ្ញាត downloaded preset រត់ native code ដោយសេរី។

## Part 13 — Filter System

Filter ជា look ដែលអាចមកពី color parameters ឬ LUT។ UI អាចបង្ហាញជា library ប៉ុន្តែ engine reuse color nodes។

LUT ផ្គូផ្គង input color ទៅ output color។ Input transfer, domain និង interpolation សំខាន់។ LUT មិនសមនឹង color space អាចធ្វើឱ្យរូបខុស។

រក្សា LUT digest, version និង intensity។ កំណត់ blending space ច្បាស់។ Categories, favorites និង downloads ប្រើ stable IDs មិនមែន index។

ចាប់ផ្តើម looks តិចដែលបាន validate។ Test identity LUT, intensity 0, clipping, unsupported file និង offline cache។

## Part 14 — Transition Engine

Transition ទទួល scenes ពី outgoing និង incoming clip ក្នុង interval មួយ។ រក្សា clip IDs, duration, alignment និង definition/version។

Transition ត្រូវការ source handles នៅក្រៅ visible boundaries។ បើគ្មាន ត្រូវ shorten, reject ឬ repeat boundary frame ដោយប្រាប់អ្នកប្រើ។ កុំអាន source time ខុសដោយស្ងៀមស្ងាត់។

Progress u = (t−start)/duration។ Dissolve ប្រើ weights 1−u និង u ក្នុង working space ដែលកំណត់។ Audio envelope ជា contract ផ្សេង។

Presets ផ្លាស់ direction, softness និង motion ដោយ reuse implementation។ Test endpoints, speed changes, trim undo, nested sequences និង missing handles។

## Part 15 — Stickers និង Overlays

Stickers អាចជា image, GIF, vector animation, shape, icon, frame ឬ decoration។ Package មាន size, duration, loop policy, alpha, dependencies និង license reference។

Sticker instance គឺ timeline clip មាន timing/transform មិនមែន list ពិសេសនៅក្រៅ project serialization។ Lottie-like support ត្រូវប្រាប់ subset ដែលគាំទ្រ។

Cache rasterization តាម size ត្រូវការ។ កំណត់ maximum frames និង decoded memory ដើម្បីជៀសវាង file តូចប៉ុន្តែ decode ធំខ្លាំង។

ចាប់ផ្តើម static shapes/images មុន animation។ Test transparent edges, loop trim, missing files និង save/reopen។

## Part 16 — Caption System

Caption document មាន language, segments, words, timestamps, speaker labels និង provenance។ Transcript និង style ដាច់ពីគ្នា។ SRT/VTT អាចមិនរក្សា animation/style ទាំងអស់បាន ដូច្នេះត្រូវព្រមាន។

កំណត់ time domain ច្បាស់។ សំណើ៖ transcribe program audio ពី captured revision ហើយរក្សា timestamps ជា sequence-relative។ បើកែ timeline ក្រោយមក ត្រូវ remap តាម command ឬសម្គាល់ analysis stale។

Worker result មាន revision និង input fingerprint។ បើ project ផ្លាស់ហើយ មិនត្រូវ overwrite captions ថ្មីទេ។ ផ្តល់ review។

Caption template មាន font, wrapping, safe area, line count, active-word color និង animation។ Karaoke ត្រូវភ្ជាប់ word timing ទៅ shaped clusters។

Batch ត្រូវរក្សា item ដាច់គ្នា។ បង្ហាញ video 2 of 7 និង progress របស់ video នោះ 0–100%។ បើ video 3 failed captions របស់ 1 និង 2 នៅរក្សា។ Target syntax អាចជា 1,2,4 to 7។

Test speed, cut boundary, partial batch, cancellation, Khmer និង export caption size/position។

## Part 17 — Animation Engine

Property track មាន typed keyframes និង time domain។ Numeric, color, rotation, boolean និង enums មិនអាច interpolate ដូចគ្នាទាំងអស់។

Linear interpolation = a+(b−a)u។ Bezier easing ត្រូវដោះស្រាយ x progression មុនយក y មិនមែនគិត curve parameter ស្មើ time ទេ។

Position, scale, opacity, effects, audio, masks និង text ប្រើ evaluator រួម។ Entrance/exit/loop មាន policy ថា override, add ឬ multiply ជាមួយ user keys។

Animation ត្រូវគណនាពី time ដោយផ្ទាល់ មិន accumulate delta ដែលធ្វើឱ្យ seek ថយក្រោយខុស។ Test exact keys, zero interval, 360° crossing និង trimmed loops។

## Part 18 — Speed Engine

Speed ជា time map មិនមែន player property ប៉ុណ្ណោះ។ Constant speed ប្រើរូបមន្ត Part 5។ Variable speed ប្រើ source progression ជា integral នៃ v(t)។

Reverse មាន source map ថយក្រោយ ហើយត្រូវ bounded buffering ឬ intermediate។ Freeze frame រក្សា source time មួយក្នុង output duration វិជ្ជមាន។

Speed ramp ត្រូវកំណត់ integration និង audio policy។ Pitch-preserving stretch មិនដូចការប្តូរ sample playback rate។ Optical flow ប៉ាន់ស្មាន motion ហើយអាចខុសនៅ occlusion ឬ scene cut។

Build constant speed មុន freeze/reverse/ramp។ Test endpoints, captions, A/V duration និង export snapshot មិនអាចផ្លាស់ដោយ inspector កំពុង edit។

## Part 19 — Mask និង Compositing

Mask ជា coverage 0–1។ Rectangle, circle, path, feather និង invert ជា parameters។ Tracking បង្កើត transform/path តាមពេល។

Alpha និង blend mode មិនមែនតែមួយ។ សម្រាប់ premultiplied source-over៖ color = Cs + Cd(1−As), alpha = As + Ad(1−As)។

Chroma key ប៉ាន់ស្មាន transparency ពីពណ៌; spill suppression ដោះពណ៌ជ្រៀត។ AI background removal បង្កើត matte ដែលអ្នកប្រើត្រូវអាចកែបាន។

កំណត់ feather units និង nested group isolation។ Test transparent edges លើ background ខ្មៅ/ស, invert, scale និង lost tracking។ Build masks សាមញ្ញមុន advanced blend modes។

## Part 20 — Color Engine

Color management ផ្តល់ន័យដល់ values ពី decode រហូត export។ រក្សា primaries, transfer, matrix និង range។ Metadata មិនស្គាល់ត្រូវមាន assumption policy មិនមែនទាយដោយលាក់។

Exposure, contrast, highlights, shadows, saturation, temperature, tint, curves, HSL, wheels និង LUT មាន processing order និង working representation ច្បាស់។

Histogram, waveform និង vectorscope ត្រូវប្រាប់ថាវាស់ source ឬ output។ អាច sample async ដើម្បីរក្សា UI responsive។

ចាប់ផ្តើម SDR pipeline ដែលបាន test មុន HDR។ Decode HDR file បានមិនមានន័យថា editor គាំទ្រ HDR ត្រឹមត្រូវ។ Test charts, range, neutral settings និង backend agreement។

## Part 21 — Audio Engine

Audio graph៖ decode → time map → gain/pan/effects → mix bus → output។ ប្រើ sample time។ Audio callback មិនត្រូវធ្វើ blocking I/O ឬ allocate ធ្ងន់ៗ។

Volume, pan, fade, detach និង voiceover ជាមូលដ្ឋាន។ EQ កែ frequency; compressor កែ dynamics; reverb បន្ថែម persistence។ Noise reduction និង pitch processing អាចមាន latency ដែលត្រូវ compensate។

Waveform មិនជំនួស loudness meter ទេ។ Beat detection ផ្តល់ markers ដែលកែបាន។ Music library ត្រូវមាន rights metadata។

Linked source audio និង independent music instance ត្រូវខុស identity ទោះ file path ដូចគ្នា។ Apply volume មិនត្រូវប៉ះ music មិនបានជ្រើស។

Test sample rates, mono/stereo, silence, clipping, sync, latency និង recording interrupted។ Save recording ឱ្យសុវត្ថិភាពមុនបន្ថែម clip។

## Part 22 — Content Platform

Library ធំកើតពី reusable engines និង versioned definitions មិនមែន widgets រាប់ពាន់។ Catalog ប្រាប់អ្វីមាន; package មាន files; instance ប្រាប់ project ប្រើ version ណា។

Manifest មាន contentId, version, type, localized names, tags, category, engine requirements, digests, dependencies, preview, license reference និង entitlement category។

Pipeline៖ download → verify → validate → stage → atomic install → index។ Download failed មិនត្រូវជំនួស version ល្អចាស់។ Hash ពិនិត្យ bytes; signature និង trust policy ប្រាប់ publisher។

Project ត្រូវ pin versions។ Preset update មិនត្រូវប្តូរ old export ដោយស្ងៀមស្ងាត់។ Upgrade ជាសកម្មភាព explicit ដែល preview និង undo បាន។

Favorites, search, recents, downloads និង offline cache ប្រើ registry នេះ។ ចាប់ផ្តើម packages 10 ដែលត្រឹមត្រូវ មុន content រាប់ពាន់។ Test corrupt archive, missing font, cycles និង interrupted download។

## Part 23 — Template Engine

Template ជា project fragment មាន placeholders មិនមែន video flattened។ វាពិពណ៌នា tracks, media/text slots, effects, transitions, music និង animation។

Placeholder មាន accepted type, minimum duration និង fit/replacement policy។ Media ខ្លីអាច trim, loop, stretch ឬ reject តាមច្បាប់ដែលបង្ហាញច្បាស់។

Instantiation បង្កើត instance IDs ថ្មី និង remap references ខាងក្នុង។ Definition IDs នៅ stable។ Advanced user អាច expand ទៅ editable composition។

Template update មិនត្រូវ mutate instance ចាស់។ Test short replacement, multiline text, missing dependency, nested template និង reopen។

## Part 24 — Project File Format

Project ជា durable intent មិនមែន dump នៃ controllers។ Manifest មាន schemaVersion, project ID, sequences, assets, tracks, clips, effects, keyframes, text, captions, audio និង content pins។

Managed media ប្រើ relative paths។ មិនអាចសន្មតថា G: មានលើ PC ផ្សេង។ Schema version ខុសពី app version។

Time មាន rate; IDs មិនស្ទួន; references resolve; intervals valid; nested sequences មិនមាន cycle។ Unsupported essential feature គួរបើក read-only ឬព្រមាន។

Migration ធ្វើលើ copy តាមលំដាប់ version ហើយ validate មុន/ក្រោយ។ រក្សា original រហូត save ថ្មីជោគជ័យ។

Test historical fixtures, malformed JSON, missing assets, huge counts និង round-trip equality។

## Part 25 — Save, Autosave និង Recovery

Save ចាប់ revision មួយ → serialize ទៅ temporary sibling → flush តាម platform → validate → replace ដោយ safe atomic operation ពេលអាចធ្វើបាន។ Cross-volume move មិនធានា atomic។

Autosave មាន debounce និង maximum delay។ បង្ហាញ saved revision/time។ ពាក្យ “Autosave active” មិនបញ្ជាក់ថា edit ចុងក្រោយបានសរសេររួច។

Serialize save jobs ដើម្បីកុំឱ្យ old save overwrite new save។ Journal មាន sequence និង checksum; recovery replay តែ records ពេញលេញ។

Disk full ឬ drive offline ត្រូវរក្សា state ក្នុង memory និងផ្តល់ Save As។ Test kill នៅ save phases ផ្សេងៗ, truncated journal និង concurrent requests។

## Part 26 — Export Engine

Export ប្រើ captured revision៖ Project → Timeline → RenderPlan → frames/audio → encoder → muxer → temporary output → verify → final file។

Profile ត្រូវមាន width/height ពិត, rational FPS, codec, pixel/color format, bitrate policy, audio និង container។ “1080p” មិនគ្រប់គ្រាន់សម្រាប់ portrait។

Queue item ចាប់ composition ID និង output name ពេលចាប់ផ្តើម។ Number 6 ក្នុង filename មិនដូច item 1 of 5។ កុំយក current selection មកផ្លាស់ export កំពុងរត់។

Per-item progress និង overall progress ដាច់គ្នា។ មិនបង្ហាញ 100% មុន finalize និង verify ជោគជ័យ។ Video បន្ទាប់ចាប់ progress ថ្មី។

Cancel ត្រូវ stop owned workers, await exit និងលុបតែ temporary files របស់ job នោះ។ Test partial failure, disk full, path collision, cancellation និង edit ពេល export។

## Part 27 — FFmpeg និង Media Processing

FFprobe ពិនិត្យ media។ FFmpeg ជា processing tool មិនមែនជាម្ចាស់ selection ឬ undo។ ប្រើ adapter មាន structured arguments, diagnostics និង cancellation។

លំហាត់សម្រាប់ trusted sample និង compatible build៖

```text
ffprobe -v error -show_format -show_streams -of json input.mp4
ffmpeg -i input.mp4 -vf scale=640:-2 -an preview.mp4
```

នេះមិនមែន full export renderer ទេ។ អាន [FFmpeg commands](https://ffmpeg.org/ffmpeg.html) និង [filters](https://ffmpeg.org/ffmpeg-filters.html) សម្រាប់ options និង filter semantics។ ត្រូវពិនិត្យ version ដែល bundle មិនសន្មតថាឧទាហរណ៍ online ទាំងអស់អាចប្រើ។

កុំ concatenate shell command ពី user text។ Filter graph ធំត្រូវប្រើ supported file-based mechanism ឬ staged plan។ Stream copy មិនអាច render effects ដែលបានកែ។ Hardware encode មិនមានន័យថា graph ទាំងមូលប្រើ GPU។

Test file path មាន spaces/Khmer និងរក្សា source ដើម។

## Part 28 — Performance

កំណត់ reference hardware និង workload មុននិយាយថា “fast”។ វាស់ input latency, memory, frame deadlines, CPU/GPU, queue wait និង disk។

Bounded scheduler ត្រូវកំណត់ទាំង process count និង native thread count។ Interactive seek គួរអាទិភាពលើ speculative thumbnails។ AI និង export ចែក resource budget។

Surface 3840×2160 RGBA8 មួយប្រហែល 31.6 MiB។ បើមានជាច្រើន memory កើនលឿន។ កុំ decode reverse video ទាំងមូលចូល RAM។

Virtualize timeline និង catalog។ Cache មាន key/eviction តាមប្រភេទ។ Cancel stale work ដោយ generation tokens។ Debounce background work មិនមែនបាត់ command commits។

Test long videos, 7 imports, thousands of clips, low disk និង open/close loops។ Resource limits មិនមែនជាភស្តុតាងថាដោះស្រាយ whole-PC freeze គ្រប់មូលហេតុទេ។

## Part 29 — AI Video Editing

AIJob មាន input snapshot/hash, operation, model/version, parameters, consent និង budget។ Result ជា artifact ដែល review បាន មិន mutate project ដោយលាក់។

Captions, translation, segmentation, tracking, silence removal, smart cut, beat sync, reframing និង speech enhancement មាន quality tests ខុសគ្នា។ Generative assets ត្រូវមាន provenance និង moderation។

Local/remote adapters ប្រើ contract ដូចគ្នា ប៉ុន្តែ privacy, cost និង hardware ខុស។ ប្រាប់អ្នកប្រើមុន upload media។

Silence removal ផ្តល់ suggested ranges ហើយ acceptance ក្លាយជា timeline commands ធម្មតា។ Tracking ផ្តល់ keys និង confidence។

Test cancellation, stale revision, duplicate retries, no speech, low memory និង multilingual quality។ AI result ត្រូវអាចកែបាន។

## Part 30 — Cloud Platform

Cloud ជាជម្រើសសម្រាប់ backup, sync, comments និង collaboration។ Metadata និង media blobs sync ផ្សេងគ្នា។

ប្រើ immutable blob IDs និង resumable upload។ Device map asset identity ទៅ local path។ Conflict ត្រូវរក្សា edits ទាំងពីរ មិន overwrite project ទាំងមូលតាម last writer ដោយស្ងៀមស្ងាត់។

ចាប់ផ្តើម snapshot backup និង explicit restore។ បន្ទាប់មក revision checks និង conflict copies។ Real-time collaboration ត្រូវការ operation ordering, permissions និង offline reconciliation។

Local save និង cloud synced ជា statuses ផ្សេង។ Cloud outage មិនត្រូវបិទ local export។ Test disconnected edits, partial upload និង account switching។

## Part 31 — Backend

ចាប់ផ្តើម modular backend មួយ។ Domains មាន auth, users, projects, assets, templates, catalog, subscriptions, licenses, payments, analytics និង AI jobs។

Database រក្សា metadata/authorization; object storage រក្សា media; queue បញ្ជូនការងារ ប៉ុន្តែ durable job state នៅ database។ CDN មិនមែន authorization ដោយខ្លួនឯង។

API មាន IDs, revision checks, pagination, idempotency និង structured errors។ Worker retry មិនត្រូវបង្កើត result ឬ charge ពីរដង។

Timeline, undo និង local export នៅ local។ Test tenant isolation, expired credentials, retries និង worker restart។ Business integration មិនចូល clip math។

## Part 32 — Desktop, Mobile និង Web

Share schema, commands, time math, validation និង fixtures។ Platform adapter ទទួល file picker, decode, GPU, audio device, background lifecycle និង installation។

Windows/macOS ប្រើ desktop workflow។ Android/iOS ត្រូវ touch, suspend/resume និង thermal budget។ Web មាន storage, permission, codec និង memory constraints។

Shared toolkit មិនធានា codec/text rendering ដូចគ្នា។ មាន capability matrix ហើយមិនលុប unsupported project features ដោយលាក់។

ធ្វើ desktop មួយឱ្យរឹងមុន platform ទីពីរ។ Test transfer project, missing fonts, rotation និង interrupted export។

## Part 33 — Plugin Architecture

Plugin អាចផ្តល់ effect, transition, importer, exporter, AI tool និង panel តាម API version។ Panel ស្នើ commands មិនអាចកែ private state ដោយផ្ទាល់។

ចាប់ផ្តើម declarative packages មុន executable plugins។ Executable ត្រូវ isolation, permissions, quotas, IPC validation និង compatibility negotiation។

Signature ប្រាប់ identity មិនធានាសុវត្ថិភាព។ Out-of-process ក៏មិនមែន full sandbox បើគ្មាន OS restrictions។

Project រក្សា plugin metadata ពេល plugin បាត់។ Test timeout, denied permission, malformed messages និង missing plugin export។

## Part 34 — Creator Ecosystem

Submission មាន draft, validation, review, approved, suspended និង retired states។ ត្រូវមាន provenance, rights, preview, compatibility និង dependencies។

Automation ពិនិត្យ malformed package; human review ពិនិត្យ content និង misleading claims។ ត្រូវមាន report និង appeal workflow។

Published versions មិនកែ bytes ចាស់។ Takedown និងរបៀបដោះស្រាយ old project dependencies ត្រូវមាន legal/licensing review មុន commercial launch។

ចាប់ផ្តើម internal content និង invited creators មុន public marketplace។ Test rollback, compromised account និង broken update។

## Part 35 — Free / Pro Platform

Entitlement policy ដាច់ពី Editor Core។ Policy សម្រេច feature/content access; renderer គណនា plan ដែលបាន authorize។

Technical unsupported និង Pro locked មិនមែនបញ្ហាដូចគ្នា។ GPU មិនគាំទ្រមិនគួរបង្ហាញថាត្រូវបង់ Pro។

កំណត់ offline access និង cached proof policy ច្បាស់។ Billable AI usage ត្រូវ durable ledger និង idempotent settlement។

Test logout, expiry, restore purchase និង offline reopen។ កុំលុប user media ពេល subscription ផ្លាស់។

## Part 36 — Search និង Discovery

Index localized text, tags, categories និង compatibility។ Favorites, recents និង collections ប្រើ stable IDs។

Featured ជា editorial មិនដូច trending ដែលត្រូវមានទិន្នន័យ។ កុំបង្កើត popularity ចៃដន្យ។ Search គួរបង្ហាញ assets ដែលអាចប្រើបាន។

Local index សម្រាប់ offline; remote search មាន pagination និង cancel stale query។ Recommendations គួរជាជម្រើសមាន privacy controls។

Test Khmer query, empty results, duplicate names, keyboard selection និង missing download។

## Part 37 — Localization

UI strings ត្រូវ externalize មាន pluralization និង context។ កុំភ្ជាប់ translated fragments ដែលធ្វើឱ្យប្រយោគខុស។

RTL, mixed-direction និង Khmer shaping ត្រូវ test។ Stable IDs មិនផ្លាស់ពេល language ផ្លាស់។ User caption text មិនត្រូវ auto-translate ពេលប្តូរ UI language។

Caption translation បង្កើត document/track ដែល review បាន។ Test long labels, dates/numbers, fallback និង shortcuts នៅ text field។

## Part 38 — Accessibility

Control នីមួយៗមាន accessible name, role, state និង keyboard path។ Timeline clip ប្រាប់ label, start, duration និង actions ដោយមិនចាំបាច់ drag ឱ្យត្រូវ pixel។

ផ្តល់ numeric input ជំនួស drag, visible focus, reduced motion និង status មិនប្រើពណ៌តែឯង។ Tooltip មិនជំនួស accessible name។

យោង [WCAG 2.2](https://www.w3.org/TR/WCAG22/) និង test native screen reader។ សាក workflow import→trim→caption→export ដោយ keyboard និង focus restoration ក្រោយ dialog។

## Part 39 — Testing

ត្រូវមាន domain tests, command properties, persistence fixtures, render conformance, media integration, UI និង stress tests។

Synthetic media មាន frame numbers, color quadrants និង audio ticks ធ្វើឱ្យ source-time, crop និង sync error មើលឃើញ។ Real media ត្រូវមានការអនុញ្ញាត។

ប្រៀប preview/export នៅ composition timestamp ដូចគ្នា។ Lossy output ត្រូវ tolerance សមស្រប។ Caption bounds និង exact dimensions ត្រូវអះអាងក្នុង test។

Failure injection មាន disk full, missing font, worker hang, corrupt package និង stale job។ Short tests pass មិនធានា long 4K workflow គ្រប់ PC។

## Part 40 — Observability

Logs មាន job ID, revision, phase, backend, elapsed time, exit code និង sanitized error។ Heartbeat ប្រាប់ថារស់; progress ប្រាប់ថាការងាររីកចម្រើន។ ទាំងពីរខុសគ្នា។

Metrics មាន queue wait, render latency, dropped frames, memory peaks និង cancel latency។ Logs មាន retention limit។

Diagnostics bundle ត្រូវ redact paths, tokens, transcript និង private media តាម default។ Upload ត្រូវ consent។

Debug view អាចបង្ហាញ RenderPlan, source time និង cache key។ Test redaction។ Stuck 0% ត្រូវអាចដឹងថាជាប់ phase ណា។

## Part 41 — Security

Project, media, fonts, templates, plugins និង responses ជា untrusted input។ កំណត់ size, nesting, decompression និង parser budgets។ Validate archive paths មុន extract។

Secrets នៅ credential storage មិននៅ logs។ Backend ត្រូវពិនិត្យ ownership មិនមែនត្រឹម login រួច។

មាន package/update verification, dependency review និង vulnerability response។ Media workers គួរមាន isolation តាម platform។

Test traversal, huge metadata, cycles, cross-account access និង malformed IPC។ Marketplace ត្រូវ security និង licensing review ពិតប្រាកដ។

## Part 42 — Folder Architecture

បែងតាម ownership មិនមែន line count តែប៉ុណ្ណោះ៖

```text
apps/       desktop / mobile / web
packages/   editor_core / timeline / render_contract
            content_schema / project_format / ui_system
adapters/   media_native / render_gpu / render_ffmpeg
            storage_local / cloud_client / ai_local
services/   platform_api / job_workers / catalog
content/    authoring / validation / reference_packages
tests/      conformance / fixtures / integration / performance
docs/       decisions / contracts / runbooks
```

នេះជាផែនទីអនាគត មិនមែនបញ្ជាឱ្យបង្កើត empty folders ទាំងអស់។ Module នីមួយៗមាន public API, owner, tests និង dependency rule។

កុំដាក់ logic គ្រប់យ៉ាងក្នុង utils។ Refactor boundary មួយម្តងដោយរក្សា behavior tests។ បំបែក file មិនស្មើបំបែក state ownership។

## Part 43 — Development Rules

ឈ្មោះត្រូវបង្ហាញ units និង intent ដូចជា sourceIn, sequenceStart, compositionPixels។ កុំប្រើ currentVideo ដែលមិនដឹង asset ឬ clip។

ពិនិត្យ file ប្រហែល 500–800 lines ប៉ុន្តែមិនបំបែក coherent code ចៃដន្យដើម្បីបំពេញលេខ។ Small files ដែល shared mutable state ខ្លាំងនៅតែពិបាកថែ។

Async ត្រូវមាន ownership, cancellation, disposal, stale result policy និង errors។ កុំលាក់ failure ជា empty thumbnail រហូត។

Behavior change មាន tests/docs។ Architecture decision record មាន context, alternatives, decision, consequences និង revisit trigger។

## Part 44 — Feature Development Template

គ្រប់ feature សរសេរ problem, UX, requirements/non-goals, owner, data/units, API, UI states, commands, rendering, persistence, tests, performance, diagnostics និង Definition of Done។

ឧទាហរណ៍ Apply selected៖ ចាប់ live selected clip revision ហើយ copy តែ groups ដែលជ្រើស ទៅ exact target IDs។ មិន copy independent music។

Command មាន sourceId, targetIds, groups និង expectedRevision។ Validate locks មុន apply atomic transaction។ Undo មួយស្តារទាំងអស់។

Test apply→កែ source→apply ថ្មី, excluded settings unchanged, locked policy, undo និង export parity។ Done មិនមានន័យថា installer បាន verify បើមិនទាន់ build/test។

## Part 45 — Product Roadmap

Stage 0: foundation—IDs, time, state, recovery, tests។ Gate: deterministic commands និង reopen។
Stage 1: basic editor—import, trim, preview, audio, export។ Gate: offline end-to-end។
Stage 2: timeline—split, ripple, links, snap, history។ Gate: randomized tests។
Stage 3: professional—transform, text, caption, color។ Gate: render parity និង Khmer។
Stage 4: content—schemas, presets, templates។ Gate: 10 packages lifecycle។
Stage 5: performance—proxy, scheduler, virtualization។ Budget ចាប់ផ្តើមមុននេះផង។ Gate: benchmark។
Stage 6: advanced—masks, ramps, nesting, multicam។ Gate: complex fixtures។
Stage 7: AI—reviewable jobs និង privacy។ Gate: quality/cancel tests។
Stage 8: cloud—backup, sync, comments, collaboration ក្រោយ។ Gate: conflict/security។
Stage 9: creators—publish, moderation, rights។ Gate: operational review។
Stage 10: master—cross-platform, plugins, reliability។ Gate: sustainable maintenance។

កុំសន្យាថ្ងៃចប់ដោយគ្មាន team capacity និង measurements។ Companion roadmap មាន dependencies, risks, tests និង exit criteria លម្អិត។

## Part 46 — Feature Matrix

Matrix មាន System, Feature, Sub-feature, Priority, Required engine, Dependencies, Difficulty, Platform និង Stage។ វាជា planning inventory មិនមែន implemented list។

P0 ការពារ correctness/data; P1 core workflow; P2 creativity; P3 advanced strategy។ Difficulty មិនមែនចំនួនថ្ងៃ។ Platform ជាទិសដៅមិនមែន certified support។

Feature status គួរជា proposed→specified→prototyped→implemented→verified→released។ កុំដាក់ “done” មួយជំនួសទាំងអស់។

បំបែក captions ទៅ import, timing, shaping, style, export, cancel និង recovery។ វាធ្វើឱ្យ dependencies និង tests ច្បាស់។

## Part 47 — Study Roadmap

Beginner៖ types, functions, files, Git, tests។ លំហាត់គណនា clip duration និង timeline table។ ត្រូវពន្យល់ asset ខុសពី clip។

Intermediate៖ immutable state, commands, async, time maps។ Build split/undo ក្នុង memory និង three-clip editor។ ត្រូវពន្យល់ source time ខុសពី sequence time។

Advanced៖ media, matrices, render, cache, profiling។ Build labeled-frame transform និង preview/export harness។ ត្រូវពន្យល់ invalidation និង alpha/color។

Professional៖ migration, recovery, accessibility, observability។ Simulate interrupted save ហើយ build feature មាន tests/budgets/docs។ ត្រូវពន្យល់ cancellation ownership។

Master៖ distributed systems, governance, security និង operations។ Design sync conflict និង plugin permissions។ ត្រូវដឹង complexity ណាដែលមិនគួរ build នៅឡើយ។

រៀនតាមលំហាត់ និង tests មិនមែនចាំពាក្យទាំងអស់។ Study companion មានសំណួរ និង projects បន្ថែម។

## Part 48 — Master Dictionary

Dictionary ដាច់ដោយឡែកមាន English term, simple English, Khmer explanation, professional meaning និង Klipio example។ ការមានភាសាទាំងពីរក្នុង dictionary គឺតាមតម្រូវការពិសេស មិនមែនដាក់សៀវភៅពីរចំហៀងគ្នា។

រៀន time, render និង state terms មុន។ ពាក្យ snapshot មានតម្លៃនៅពេល export មិនអាចអាន inspector mutable state។ ពាក្យ GPU មានតម្លៃនៅពេលវាស់ memory និង transfer cost។

រក្សាពាក្យដូចគ្នាក្នុង schema, code, UI និង tests។ បើ scale ឬ time អាចច្រឡំ ត្រូវបញ្ជាក់ coordinate space និង domain។

## Part 49 — ពី Function ទៅ Professional Product Experience

បន្ថែមនៅ 2026-09-07។ នេះជា product/engineering specification សម្រាប់អនាគត មិនមែនការបញ្ជាក់ថា app បានអនុវត្តគ្រប់ចំណុចរួចទេ។ យើងមិនយកការអះអាងក្នុង attachment ថាបាន audit repo និង screenshots ទាំងអស់ មកធ្វើជាភស្តុតាងថ្មី។

Function ធ្វើការបាន មិនទាន់ស្មើ feature ពេញលេញ។ Product ដែលប្រើងាយត្រូវមាន engine ត្រឹមត្រូវ, controls ដែលយល់បាន, content ដែលជ្រើសបាន, undo, save និង recovery។

[CapCut beginner tutorial](https://www.capcut.com/resource/capcut-tutorial-for-beginners) ពិពណ៌នា import → timeline editing → creative content → export។ វាជា workflow reference មិនមែនភស្តុតាង architecture ខាងក្នុង ឬការអនុញ្ញាតឱ្យចម្លង assets។ Design ខាងក្រោមជាសំណើរបស់ Klipio ផ្ទាល់។

អានជាមួយ Parts 3–4, 11–16, 22–25 និង 39–44។ [Klipio Editor Improvement Plan](../04_EDITOR_ARCHITECTURE/Klipio-Editor-Improvement-Plan.md) ផ្តោត performance/implementation; chapter នេះផ្តោត experience ដែលដាក់លើ engine។

### 1. Feature completeness — lifecycle ទាំងមូល

Function សួរថា engine អាចធ្វើបានទេ។ Feature សួរថា user អាចរកឃើញ, ប្រើ, កែ, រក្សា និងសង្គ្រោះបានទេ។

```text
Discover → Open → Configure → Preview → Apply → Edit
                         ↓
             Undo / Redo → Save → Reopen → Export
                         ↓
                  Failure / Recovery
```

Caption experience ត្រូវមាន entry point, language/backend, exact targets, edited audio snapshot, progress និង cancel។ បន្ទាប់ពី generate មាន timeline blocks, transcript/timing editor, style browser, typography, animation និង Apply selected។ ចុងក្រោយត្រូវ undo, save/reopen និង export ដូច preview។

បើ video ទី 3 failed ក្រោយទី 1 និងទី 2 complete ត្រូវរក្សា captions ពីរនោះ។ Retry មិនបង្កើត captions ស្ទួន។ បើ project ផ្លាស់ពេល worker រត់ ត្រូវ review stale result មុន apply។

Undo ការកែ timeline មិនដូចសងថ្លៃ remote AI។ បញ្ជាក់អ្វី reversible និងអ្វីមិនអាច undo។ Test មិនបញ្ចប់ត្រឹម service return text ទេ។

### 2. Design System តែមួយ

កុំឱ្យ feature នីមួយៗបង្កើត button, spacing, color និង dialog ខុសគ្នា។ Foundation មាន semantic colors, typography, spacing, radius, elevation, icons, motion និង density។

Components មាន Button, IconButton, NumericField, SliderField, Dropdown, Tabs, SegmentedControl, Menu, Tooltip, Dialog, Panel, InspectorRow, PropertySection, AssetCard, CreativeAssetCard, TimelineClip និង TimelineHandle។

គ្រប់ component កំណត់ default, hover, focus, pressed, selected, disabled, loading និង error តាមភាពសមស្រប។ Success អាចជាសារខ្លី មិនចាំបាច់ប្តូរគ្រប់ button ទៅបៃតង។

NumericField មាន value, unit, bounds, precision, mixed state, transient update, commit, cancel និង reset។ Slider និងលេខត្រូវដូចគ្នា។ Drag មួយមាន history transaction មួយ។ Invalid input មិនត្រូវបំផ្លាញ committed value។

មាន component gallery សម្រាប់ Khmer, long labels, themes និង keyboard focus។ UI theme មិនត្រូវប្តូរពណ៌ដែល user បានកំណត់ក្នុង video។

### 3. Workspace ដែលមាន ownership ច្បាស់

```text
Project / Save / Undo / Workspace / Export
-------------------------------------------------------
Creative Browser | Program Monitor | Contextual Inspector
Media / Audio    | Source optional | Selected properties
Text / Captions  |                 |
Effects          |                 |
Transitions      |                 |
-------------------------------------------------------
Timeline / Tracks / Playhead / Zoom / Edit tools
```

Panel resize/collapse បាន ប៉ុន្តែ responsibility នៅដដែល។ ប្តូរ browser tab មិនត្រូវកែ clip settings។ Source monitor មិនមែន program composition។

រក្សា docking និង panel size ក្នុង workspace preferences ដាច់ពី project។ Window តូចប្រើ tabs/drawers មិនលាក់ Export ក្រៅអេក្រង់។ បាត់ monitor មួយត្រូវ restore layout ឱ្យមើលឃើញ។

Home export card ចុចបើក details; cancel ជា control ផ្សេង។ បិទ details មិនមែន cancel job។ Test resize ពេល playback, keyboard, focus return និង docking មិនបង្កើត project revision។

### 4. Context-sensitive Inspector

Selected Video បង្ហាញ Basic, Transform, Crop, Mask, Animation, Speed, Adjustment និង Effects។ Selected Text បង្ហាញ content, Font, Style, Layout, Transform និង Animation។ Selected Audio បង្ហាញ Volume, Fade, Pan, Voice/Noise, Speed និង Effects។

Caption បង្ហាញ Transcript, Timing, Style និង Layout។ Multiselect បង្ហាញ properties ដែលប្រើរួមបាន និង mixed values។ គ្មាន selection បង្ហាញការណែនាំ ឬ sequence settings ដែលមាន label ច្បាស់។

Inspector ជា derived view មិនមែនច្បាប់ចម្លង mutable transform ទីពីរ។ Input buffer អាចនៅក្នុង UI ប៉ុន្តែ commit ត្រូវពិនិត្យ target/revision។

បើប្តូរ selection ខណៈកំពុងវាយលេខ ត្រូវ commit ទៅ original target ឬ cancel តាម policy ច្បាស់។ កុំយកលេខដែលកំពុងវាយទៅ apply លើ video ថ្មីដោយចៃដន្យ។

### 5. Progressive Disclosure

បង្ហាញ common controls មុន specialist controls។ Transform មូលដ្ឋានមាន Position, linked Scale, Rotation និង Opacity។ Advanced មាន Anchor, independent X/Y, Flip, Blend និង precise coordinates។

Beginner អាចប្រើ text preset ហើយ expert នៅអាចកែ font/layout។ បើកែ preset បង្ហាញថា customized។ Collapse section មិន reset values។

ចងចាំ expanded sections ជា preference។ Search អាចបង្ហាញ advanced controls។ Tooltip ពន្យល់ផលប៉ះពាល់ មិនត្រឹមសរសេរឈ្មោះដដែល។

Test beginner មិនបើក advanced និង expert ប្រើ exact values។ ទាំងពីរប្រើ commands ដូចគ្នា។

### 6. Data-driven Creative Libraries

បំបែក Definition, Instance និង Installation state។ Definition ជា immutable versioned content; Instance ជាការប្រើក្នុង project; download state ជា local runtime metadata។

Definition មាន ID/version/type, localized names, category/tags, thumbnail/preview, implementation ID, parameter defaults, dependencies, compatibility, license reference និង access class។

Registry រួមអាចគាំទ្រ effects, transitions, filters, text/caption styles, animations, stickers, LUTs, templates, music និង sounds។ Type នីមួយៗមាន validator ផ្ទាល់។

JSON configure primitive ដែល engine មាន។ វាមិនអាចបង្កើត shader ថ្មីដោយដាក់ឈ្មោះទេ។ Text presets 10 អាច reuse shaping/stroke/shadow ប៉ុន្តែ curved text primitive ថ្មីត្រូវ engineering និង tests។

អនុវត្ត validation, version pinning និង limits មុនបន្ថែម content រាប់ពាន់។

### 7. Creative Browser និង Asset Cards

Pattern រួមមាន Search, Categories, Recent, Favorites, Downloaded, New និង Featured។ Trending ត្រូវមានទិន្នន័យពិត មិនបង្កើត popularity ចៃដន្យ។

Card មាន poster, name, selected/favorite, availability, compatibility និង Free/Pro។ Animated preview មាន resource limit។ Keyboard និង touch ត្រូវមាន preview action មិនពឹង hover តែឯង។

បំបែក state ជា axes៖

```text
Interaction: idle / hovered / focused / pressed
Selection: selected / unselected
Availability: remote / downloading / installed / failed
Access: allowed / locked
Capability: supported / unsupported
Preview: stopped / preparing / playing / failed
```

Asset អាច favorite ហើយ unsupported ក្នុងពេលតែមួយ។ កុំប្រើ enum តែមួយដែលបាត់ព័ត៌មាននេះ។

Download failed មាន retry; unsupported មានមូលហេតុ។ Favorite មិនស្មើ install។ Double click ពេល downloading មិនត្រូវបង្កើត clips ពីរ។

Virtualize lists, cancel off-screen previews, រក្សា scroll/filter និង empty state។ Keys ប្រើ content identity/version មិនមែន row index។

### 8. UI State និង Editing State

```text
EditorSession
├── ProjectController
├── TimelineController
├── SelectionController
├── PlaybackController
├── InspectorController
├── MediaLibraryController
├── HistoryController
└── WorkspaceController
           ↓ Commands
       Editor Core
           ↓
 Immutable Project Revision
```

Controllers មិនមែន project truth 8 កន្លែងទេ។ Core ជាម្ចាស់ durable revision។ Controller នីមួយៗ coordinate responsibility តាម contract។

Playback time, panel layout និង input buffer មិនមែន durable edit ដូច transform។ Worker មាន identity, revision, generation និង owner។ Export ចាប់ snapshot មិនអាន live inspector។

Extract responsibility មួយម្តងពី shared widget state។ File តូចច្រើនមិនបញ្ជាក់ clean architecture។ បង្កើត controllers បន្ថែមដោយមិនដក authority ស្ទួន អាចធ្វើឱ្យច្របូកច្របល់ជាងមុន។

### 9. Interaction Quality Standard

Feature specification ត្រូវមាន hover, focus, selected, keyboard, context menu, tooltip, cursor, drag preview, valid/invalid drop, snap, cancel, loading, empty, error, retry, disabled reason, progress និង success។ មិនពាក់ព័ន្ធអាចសរសេរ not applicable ជាមួយមូលហេតុ។

Drag លើ locked track បង្ហាញ invalid reason ហើយ release មិនកែ។ Snap បង្ហាញ alignment និងអាច bypass។ Library empty ផ្តល់ clear filters/import។ Missing font ប្រាប់ affected style និង replacement action។

Export finalizing ខុសពី rendering; កុំបង្ហាញ success មុន verify។ Cancel requested បង្ហាញ cancelling រហូត worker ឈប់។

Polish មិនមែន animation តែប៉ុណ្ណោះ។ Reduced motion និង screen-reader announcements ត្រូវគិតផង។

### 10. Preview-first ដោយមិន mutate project

```text
Preview → capture target/revision → transient overlay
   ├── Leave / Escape / selection change → discard
   └── Apply → validate → commit one command
```

កុំ mutate project សម្រាប់ hover ហើយសង្ឃឹមថា undo អាចស្តារវិញ។ Autosave/export អាចចាប់ការកែបណ្តោះអាសន្ននោះដោយចៃដន្យ។

Preview token ភ្ជាប់ target identity។ Effect download មកយឺតមិនត្រូវលេចលើ selected clip ថ្មី។ Revision ផ្លាស់ត្រូវ cancel ឬ validate rebase។

Export ប្រើ committed state មិនរួម transient preview។ Template preview អាចប្រើ isolated miniature composition។

Test hover/leave មិនបង្កើត revision, Escape restore, Apply ម្តង, undo, stale download និង export ពេល preview។ វាអនុវត្តលើ effects, transitions, filters, styles, animations, LUTs និង templates។

### 11. Content ជាផ្នែកមួយនៃការអភិវឌ្ឍ

Engineering track មាន timeline, render/audio, text, effects, animation, export និង performance។ Content track មាន presets, titles, captions, templates, stickers, music/sounds, thumbnails និង preview media។

ចាប់ផ្តើម pilot assets 10 ដែលបានគិតគូរ មិនចាំបាច់ 1,000 ភ្លាម។ Asset មាន owner/provenance, ID/version, dependencies, supported parameters, accurate preview, localized metadata, rights និង offline/reopen/export tests។

Content density ល្អគឺជម្រើសមានប្រយោជន៍ខុសគ្នា មិនមែន preset ដដែលប្តូរឈ្មោះ។ កុំបង្ហាញ preview ដែល engine មិនអាច export។

ធ្វើ primitive ឱ្យរឹងមុន author content ហើយ review content និង engineering ជាមួយគ្នាមុន publish។

### 12. Definition of Done

Feature ត្រូវមាន evidence សម្រាប់ functional tests, design system, keyboard/accessibility, undo/redo, save/reopen, preview/export parity, responsive panels, empty/loading/error/retry, performance, regression និង documentation។

Release ត្រូវ build/install/smoke test ដាច់ដោយឡែកពេលមានការអនុញ្ញាត។ Documentation មិនផ្តល់ green checkmarks ឱ្យ app ដោយស្វ័យប្រវត្តិ។

Status គួរមាន proposed, specified, implemented, verified និង released។ Gate ដែល waive ត្រូវមាន reason និង owner។

### 13. Workflow និង functions 10 ដំបូង

ប្រើ user problem → complete experience → owning system → data/units → command → UI states → engine → shared components → persistence → render/export → tests → measure → document → release។

ធ្វើ journeys 10 ឱ្យចប់៖

1. Import មាន thumbnails ផ្ទាល់ និង retry/offline។
2. Selection/Inspector មាន target ត្រឹមត្រូវ និង mixed values។
3. Trim/Split មាន timing និង undo ត្រឹមត្រូវ។
4. Reframe មាន gizmo/numeric/export ដូចគ្នា។
5. Apply selected ប្រើ latest values និង checked groups/exact targets។
6. Text មាន preset, editability, shaping និង reopen។
7. Captions ប្រើ edited range, per-item progress និង partial recovery។
8. Creative style មាន temporary preview និង one-command commit។
9. Save/Recovery រក្សា latest revision និងដោះ failure។
10. Export batch មាន files ត្រឹមត្រូវ, details, progress និង cancel។

លំដាប់៖ baseline tests → shared controls → workspace/inspector → browser → text/caption journey → curated content។ កុំបំផ្លាញ core ដែលធ្វើការបាន។ ផែនការនេះបន្ថែមលើ playback/export correctness plan មិនជំនួសវា។

### 14. Product Quality Rule

Klipio មាន identity ផ្ទាល់តាម consistency, clarity, predictability, speed, hierarchy, content quality, polish, correctness, persistence, parity និង accessibility។ ចម្លងពណ៌ competitor មិនធ្វើឱ្យបានគុណភាពទាំងនេះ។

រាល់ milestone សាក user journey ពេញមួយដោយគ្មាន developer ជួយ។ កត់ពេល user ស្ទាក់ស្ទើរ, បាត់ selection context, undo មិនបាន ឬ recovery មិនបាន។ Issue មាន owner, expected behavior, test និង result។

សួរបីចំណុចដាច់គ្នា៖ ធ្វើការត្រឹមត្រូវទេ? យល់ងាយទេ? នៅរឹងពេល failure/load ទេ? មួយមិនជំនួសមួយ។

គោលដៅឥឡូវគឺ experiences 10 ដែលច្បាស់ មិនមែនអះអាង competitor parity។ Chapter នេះជាឯកសារ ប៉ុណ្ណោះ មិនបានកែ app code, assets, installer ឬ EXE។


## ការថែរក្សាសៀវភៅ

កំណែទីមួយនេះគ្របដណ្តប់គ្រប់ Part ជា architecture handbook។ វាមិនអះអាងថាឯកសារមួយអាចជំនួសការសាកល្បង និង engineering ទាំងអស់ទេ។ បន្ថែម experiments និង measured decisions ពេល product រីកចម្រើន។

ប្រភព official FFmpeg, OpenTimelineIO និង W3C បានពិនិត្យនៅ 2026-09-07។ Architecture, contracts និង roadmap ភាគច្រើនជាសំណើ Klipio។ Version-specific commands ត្រូវ verify ជាមួយ runtime ដែល bundle។
