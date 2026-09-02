# Study book and practical curriculum

Learn in small verified projects. Each level has a conceptual goal, a small exercise, a Klipio exercise, a project, and an assessment.

## Beginner

Concepts: variables, immutable values, functions, types, lists/maps, files, tests, Git commits.
Small exercise: given sourceIn=10, sourceOut=18, speed=2, return duration=4.
Klipio exercise: print a table of asset IDs and clip IDs and explain duplicates.
Project: command-line sequence inspector reading a small trusted JSON fixture.
Assessment: What is an asset versus a clip? Why is a filename not an ID? What does a failing test tell you? Can you revert your own small code change without deleting media?

## Intermediate

Concepts: modules, interfaces, dependency direction, commands, transactions, async cancellation, rational time.
Small exercise: implement half-open interval containment and split with boundary validation.
Klipio exercise: implement MoveClip and undo using an in-memory model.
Project: synthetic three-clip editor with save/reopen and no native decoder.
Assessment: Why must split account for speed? What is an atomic transaction? How do you reject a stale thumbnail? Why is widget state not project state?

## Advanced

Concepts: decode versus render, transforms, alpha, color, audio samples, caches, profiling.
Small exercise: calculate contain/cover for 1920×1080 into 810×1080.
Klipio exercise: render labeled quadrants with rotation and caption coordinates.
Project: preview/export comparison harness with exact timestamps.
Assessment: Which coordinate space is font size in? What makes a cache key valid? Why might GPU processing be slower? What information must a time map contain?

## Professional

Concepts: migrations, failure injection, accessibility, resource budgets, diagnostics, review.
Small exercise: interrupt a save before replacement and recover the prior revision.
Klipio exercise: complete Apply selected as a transaction with target parsing and lock tests.
Project: one shippable feature with schema, UI states, tests, benchmarks, docs and rollback plan.
Assessment: Can cancel claim completion before process exit? How do you handle unknown effects? How do you prove a setup works without the source drive? What does a successful unit test not prove?

## Master

Concepts: distributed state, security boundaries, creator governance, compatibility, operational cost.
Small exercise: simulate two devices editing revision 10 and resolve the conflict without loss.
Klipio exercise: design content pinning plus safe package upgrade.
Project: a private catalog pilot with reviewed packages, offline reopening and incident runbook.
Assessment: Which actions are not reversible? Why is signing not sandboxing? When should a service be split? Which features should remain deferred despite being technically possible?

## Worked exercise answers

Duration is 8/2=4 seconds.
Split sequence [5,9) at 6.5 maps source 10+(6.5−5)×2=13.
Contain is 0.421875; output foreground is 810×455.625 before raster rounding, centered vertically by policy.
A 36-unit caption in an 810×1080 composition shown at one-third scale has nominal 12-unit display size; export retains the composition size.
Cache identity must include the source and requested time; selecting another video invalidates request generation, not the old asset itself.

## Study method

Predict the result first. Run a tiny experiment. Compare expected/actual. Explain the failure in your own words. Add a regression test. Only then enlarge the feature. Maintain a notebook of decisions and measurements, not a list of copied commands.

