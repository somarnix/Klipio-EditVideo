# UI / UX design system

Status: proposed. Values require visual and accessibility validation.

## Workspace ownership

Top bar: project identity, save state, undo/redo, workspace, export.
Left browser: assets and creative content.
Center: source and program monitors with clearly different labels.
Right: selected-target inspector.
Bottom: timeline, track headers, tools, zoom, playhead.
Home: projects and persistent background-job cards.

A job card opens the detail dialog; its cancel control is a separate target. Clicking the card must not cancel the job.

## Tokens and components

| Token family | Initial roles | Rule |
|---|---|---|
| Color | surfaces, text, border, accent, warning, error, focus | Semantic names; theme swaps values |
| Space | 4,8,12,16,24,32 | No random margins per feature |
| Type | body, label, heading, timecode | Test Khmer fallback and large text |
| Density | compact, comfortable | Same behavior, different spacing |
| Motion | normal, reduced | No essential information only in animation |
| Elevation | base, panel, menu, modal | Predictable overlay ordering |

Components: action button, icon button, numeric input, slider+number, enum picker, tab strip, search field, menu, tooltip, modal, progress panel, inspector section, asset card, thumbnail strip, track header, trim handle, keyframe editor.

## Interaction contract

All controls declare accessible name, enabled reason, focus policy, value units, and command binding. Disabled actions explain why. Numeric controls allow exact input and validation. Drag updates preview; release commits; Escape restores before-state.

Multiselect uses mixed value rather than adopting the first clip's settings. Apply selected opens target input and setting-group checkboxes. Display resolved target count before commit.

## State examples

Media card: queued → processing → ready; failure → retry; offline → relink.
Export: validating → preparing → rendering → finalizing → completed, with cancelling/failed branches.
Save: dirty → saving revision N → saved N, or failed with Save As.
None of these should display an indefinite spinner without a phase or recovery action.

## Layout and tests

Persist layout separately from project. Clamp restored window positions to available displays. Test resized panels, minimum window width, 200% text, keyboard-only workflow, screen reader descriptions, theme contrast, and missing thumbnails.

A component gallery includes success, error, empty, loading, unavailable, mixed, and disabled states. Review the same gallery before adding a new custom control.



## Detailed Klipio UI System specifications

- [Klipio visual identity](01_Design_Principles.md)
- [Semantic color system](02_Color_System.md)
- [Typography and Khmer](03_Typography.md)
- [Spacing, grid and density](04_Spacing_Grid_Density.md)
- [Klipio icons](05_Icon_System.md)
- [Reusable Klipio components](06_Component_Library.md)
- [Klipio workspace](07_Editor_Workspace.md)
- [Klipio Creative Browser](08_Creative_Browser.md)
- [Klipio contextual inspector](09_Inspector_System.md)
- [Klipio Timeline UI](10_Timeline_UI.md)
- [Klipio Preview Monitor](11_Preview_Monitor_UI.md)
- [Effect browser adapter](12_Effect_Browser.md)
- [Text browser adapter](13_Text_Browser.md)
- [Complete caption experience](14_Caption_UI.md)
- [Transition browser adapter](15_Transition_Browser.md)
- [Klipio Audio UI](16_Audio_UI.md)
- [Klipio Color UI](17_Color_UI.md)
- [Animation and keyframe UI](18_Animation_Keyframe_UI.md)
- [Menus and context menus](19_Context_Menus.md)
- [Keyboard shortcut system](20_Keyboard_Shortcuts.md)
- [Drag and drop contracts](21_Drag_Drop_Interactions.md)
- [Feedback and recovery](22_Loading_Empty_Error_States.md)
- [Klipio UI motion](23_Motion_Animations.md)
- [Accessibility contract](24_Accessibility.md)
- [Klipio UI release gates](25_UI_QA_Checklist.md)
- [Professional Product Experience](Professional-Product-Experience.md)

These names specify proposed Klipio components; they do not certify implementation. Consult [current status](../CURRENT_IMPLEMENTATION_STATUS.md).
