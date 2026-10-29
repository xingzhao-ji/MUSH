# MUSH story bible

Status: **proposal, not built**. This is an original narrative proposal for the concept-1 valley, preserving the existing cream woodland player and the current cozy game verbs. It does not install characters, dialogue, inventory, regions or quests.

## Read the bible

| File | Purpose |
| --- | --- |
| [WORLD_LORE.md](WORLD_LORE.md) | Valley, Kindly Crown, Lamploom, seven regional cultures, history and gathering customs |
| [CHARACTERS.md](CHARACTERS.md) | Fourteen full personas, visual designs, voices, relationships, routines and player activities |
| [ARTLIST.md](ARTLIST.md) | Early art handoff: individual turnaround prompts, scales, homes, props and festival sets |
| [PLOT.md](PLOT.md) | Six main chapters, fourteen personal stories, progression conditions and optional regional invitations |
| [DIALOGUE_STYLE.md](DIALOGUE_STYLE.md) | English voice, regional speech habits, short UI lines and companion captions |
| [dialogue/SCHEMA.md](dialogue/SCHEMA.md) | JSON data contract, dispatch, condition/effect semantics and state ownership |
| [dialogue/](dialogue/) | One fully written dialogue graph per character, including the six hosts' main chapters |
| [EVENTS.md](EVENTS.md) | Exact future world-interaction prompts and objective evidence for eighteen external events |
| [story_manifest.json](story_manifest.json) | Shared machine-readable cast, scales, quest IDs, objective conditions and event descriptions |
| [tools/check_dialogue.py](tools/check_dialogue.py) | Dependency-free parser, graph checks and representative progression checks |

Read lore and characters for the fiction, then plot for sequence. The manifest fixes names and identifiers; CHARACTERS fixes appearance and persona; ARTLIST turns those appearances into production prompts. PLOT fixes narrative outcomes; JSON contains the actual playable line proposal. EVENTS supplies the surrounding interaction copy. SCHEMA describes how a future adapter should interpret the data without treating conversation as proof of physical action.

## Story direction

The colossal mushroom tree is **the Kindly Crown (暖冠)**; the town beneath it is **Lamploom (灯织镇)**. The central story restores a chain of invitations and water notices. The healthy tree does not need saving. A rolling lantern-and-balloon gathering replaces the mistaken assumption that everyone must arrive together.

The named places, histories and inhabitants are proposals. The current source supplies walking, looking, Float, Glow, interaction, eight garden places and six furniture places. Planting costs 25 regenerating magic and blooms immediately; no proposed quest adds combat, death, deadlines or punishment. Give/carry, named NPCs, journal flags and the dialogue loader require later implementation.

## Sources and implementation boundary

The requested [story-bible brief](/Users/xingzhaoji/MUSH-exchange/briefs/B-story-bible.md), [project README](../../README.md), [status](../STATUS.md), [verification record](../VERIFICATION.md), [world plan](../WORLD_PLAN.md), [background direction](../../design-reference/background-brief.md) and supplied concept-1 vista anchor this proposal. Character names and Chinese renderings are original proposed labels, not completed localization. No real-person likenesses, brand references, borrowed quotations or sacred cultural designs are part of the proposal.

Read-only startup inspection found `main.tscn` → `scripts/playable.gd` → the active planting lineage → `scripts/main.gd`. The composition creates `BakedWorld`, whose runtime loader restores pinned baked resources and installs the cached surfaces; authoring helpers are not assumed to run. The source contains an unnamed resident placeholder and existing restoration interactions. None of that establishes that this named cast or these JSON graphs are installed. This delivery deliberately makes no native, exported, headless, visual, audio, motion or device acceptance claim.

The final handoff reports checked counts and the exact checker output. Run it again after any JSON or manifest edits:

```sh
python3 docs/story/tools/check_dialogue.py
```

The story scope is finite: six main quests plus one personal quest for each of fourteen characters. All their meetings, eight time/weather greeting variants per character, accept/defer paths, preparation, waiting, completion, aftermath, relationship stages, festival exchanges and idle captions are authored here. Optional visits to later regions are invitations, not additional accepted quests with unwritten dialogue.

## Validation status

Checked on 2026-10-28: **14 character JSON files, 628 dialogue nodes, 20 quests** (six main and fourteen personal). The standard-library checker passes parsing, schema and expression checks, all links, structural reachability, all eight time/weather greetings, **329 progression checks** and **four deliberately invalid in-memory cases**. The art list contains 58 entries. Local Markdown links resolve. This is authored-data verification only; engine integration and play acceptance remain unperformed.

## Review and rollback

The only intended repository changes are this `docs/story/` folder. Rollback is to remove the newly added story files listed in the handoff, after checking for subsequent edits by collaborators. No tracked runtime file, asset or save is changed, and no commit is made. The brief separately authorizes the report at `/Users/xingzhaoji/MUSH-exchange/codex/B-report.md`.
