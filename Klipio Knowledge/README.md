# Klipio Knowledge

Future-platform blueprint • Edition 1 • 2026-09-07

Start with the separate [English book](01_KLIPIO_MASTER_BLUEPRINT/English.md) or [សៀវភៅភាសាខ្មែរ](01_KLIPIO_MASTER_BLUEPRINT/Khmer.md). Both cover Parts 0–49. These are future design proposals, not current-code documentation or proof that features exist. The editions are separately written; the Khmer edition retains English technical terms and is more concise.

## Library map

Update 2026-09-07: both books now include Part 49, Professional Product Experience Gap, covering all 14 topics from the supplied specification. There are now 50 numbered parts (0–49). The new chapter covers complete workflows, reusable cards, contextual inspectors, safe temporary previews, state ownership, content production, and evidence-based completion gates.

1. [Master books](01_KLIPIO_MASTER_BLUEPRINT/English.md): platform concepts and system design.
2. [Product specification](02_PRODUCT_SPEC/Specification.md): users, journeys, requirements, acceptance.
3. [UI/UX design system](03_UI_UX_DESIGN_SYSTEM/Design-System.md): components, interaction, state.
4. [Editor architecture](04_EDITOR_ARCHITECTURE/Contracts.md): ownership, data contracts, vertical slice.
5. [Timeline engine](05_TIMELINE_ENGINE/Specification.md): time math and reversible operations.
6. [Render engine](06_RENDER_ENGINE/Specification.md): coordinates and preview/export conformance.
7. [Effect system](07_EFFECT_SYSTEM/Specification.md): primitives, definitions, instances.
8. [Asset/content system](08_ASSET_CONTENT_SYSTEM/Specification.md): manifests and lifecycle.
9. [Backend/cloud](09_BACKEND_CLOUD/Specification.md): local-first sync and service boundaries.
10. [AI system](10_AI_SYSTEM/Specification.md): reviewable jobs and resource limits.
11. [Roadmap](11_ROADMAP/Roadmap.md): eleven gated stages.
12. [Feature matrix](12_FEATURE_MATRIX/Feature-Matrix.md): planning inventory, not completion claims.
13. [Engineering rules](13_ENGINEERING_RULES/Rules.md): delivery template and review rules.
14. [Study book](14_STUDY_BOOK/Study-Book.md) and [dictionary](14_STUDY_BOOK/Dictionary.md): exercises and bilingual terminology.

## How to use this library

Read the [Klipio Editor Improvement Plan](04_EDITOR_ARCHITECTURE/Klipio-Editor-Improvement-Plan.md) for source-review findings, prioritized changes, and two-video/seven-video validation milestones. It includes a Khmer summary and does not claim the proposed fixes are implemented.

Read foundations, then select one roadmap gate. Write a feature specification using the engineering template. Implement a thin end-to-end workflow with tests. Record evidence and update the decision log. Do not scaffold the entire future source tree empty or replace the existing app wholesale.

Companion specifications are in English; the Khmer book explains every requested subject independently. The dictionary is intentionally bilingual. This is a Markdown edition, not a typeset PDF/Word release.

## Evidence and scope

These knowledge updates change documentation only, including this navigation README. Application code, source media, installers and EXE files are outside scope. No application tests or release builds are claimed here. Documentation checks cover chapter presence, internal links, and library structure.

Official references are linked where used in the books. The proposed design is original and is not a description of CapCut/Filmora internals. Full legal, security, hardware, and real-media qualification remain implementation work.


## Updated knowledge system

Blueprint = what Klipio should become. Specification = required behavior. [Implementation Status](CURRENT_IMPLEMENTATION_STATUS.md) = inspected current evidence and uncertainty. Roadmap = next work and dependencies. Engineering Rules = constraints on delivery. [Benchmarks](18_PERFORMANCE_BENCHMARKS/Benchmark-Protocol.md) = measurement methodology and, only after runs, evidence. Study Book = learning exercises.

```text
Master Blueprint → Product Direction → UI & UX → Editor Architecture
→ Engine Specifications → Content Systems → Backend / Cloud / AI
→ Roadmap → Feature Matrix → Engineering Rules
→ Implementation Status → Performance Evidence → Study System
```

Physical folder numbers are preserved to avoid breaking the existing library.

- [UI/UX detailed index](03_UI_UX_DESIGN_SYSTEM/Design-System.md): 25 focused specifications plus the product-experience contract.
- [Project persistence](15_PROJECT_PERSISTENCE/Specification.md): schema, migration, save and recovery.
- [Audio engine](16_AUDIO_ENGINE/Specification.md): graph, sample time, sync, effects and tests.
- [Text engine](17_TEXT_CAPTION_ENGINE/Text-Engine.md) and [caption engine](17_TEXT_CAPTION_ENGINE/Caption-Engine.md): separate ownership with shared rendering.
- [Benchmark protocol](18_PERFORMANCE_BENCHMARKS/Benchmark-Protocol.md) and [result template](18_PERFORMANCE_BENCHMARKS/Result-Template.md): no invented measurements.
- [Documentation identity review](DOCUMENTATION_IDENTITY_REVIEW.md): retained external references and corrected navigation.

The product, architecture and visual identity belong to Klipio. External editors are research references only. Existing blueprint, timeline/render contracts, roadmap and feature inventory are preserved; specifications do not promote features to Verified or Released.


## Numbering Note

Knowledge folder numbers organize the documentation library. Master Blueprint Part numbers organize chapters inside the master book. They are independent numbering systems and must not be treated as equivalent. Parts 0–49 do not correspond one-to-one to folders 01–18; existing numbering is intentionally preserved.

For example, Knowledge folder `17_TEXT_CAPTION_ENGINE` does not mean Master Blueprint Part 17.

## Documentation Source of Truth

| Document | Authority |
|---|---|
| Master Blueprint | Long-term product and architecture direction |
| System Specification | Expected behavior and contracts |
| Engineering Rules | Mandatory implementation constraints |
| Feature Matrix | Planning inventory, not completion evidence |
| Roadmap | Build order and gates |
| CURRENT_IMPLEMENTATION_STATUS | Evidence-based view of current implementation and uncertainty |
| Performance Benchmarks | Measured runtime evidence when a real result exists; protocols/templates are not results |
| Source Code + Tests | Actual implementation and executable checks; test existence alone does not prove a passing run |

When documentation and implementation status disagree, do not assume either is correct automatically. Inspect current source code, tests, and the relevant Git revision.

**[Documentation QA Checklist](DOCUMENTATION_QA_CHECKLIST.md)** — mandatory consistency review for significant Klipio Knowledge updates. Repository-relative references resolve from the Klipio checkout, independent of operating system or installation drive.
