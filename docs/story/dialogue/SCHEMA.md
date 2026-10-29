# Dialogue data contract

Status: **proposal, not built**. UTF-8 JSON, schema version 1. This folder is loadable data for a future dialogue adapter; the current Godot game does not load it. The checker is a standalone Python standard-library authoring tool, not runtime code. No executable expressions, evaluation strings, dependencies or save migrations are included.

## File and node shape

One `<character_id>.json` per character in [the manifest](../story_manifest.json). IDs are lowercase ASCII letters, digits and underscores, starting with a letter. Node IDs are unique across the collection and begin with their character ID plus `_`. Each file has exactly these top-level fields:

```json
{
  "schema_version": 1,
  "character": "brindle",
  "quests": ["q_brindle", "m_home"],
  "entries": {
    "meeting": ["brindle_example"],
    "greeting": [],
    "quest": [],
    "relationship": [],
    "festival": [],
    "idle": [],
    "main": []
  },
  "nodes": [
    {
      "id": "brindle_example",
      "speaker": "brindle",
      "kind": "meeting",
      "text": "The door opens both ways. Stay a little, or come back later.",
      "conditions": [{"not_flag": "met_brindle"}],
      "effects": [{"set_flag": "met_brindle", "value": true}]
    }
  ]
}
```

The example illustrates structure only, not a complete character file. `main` is present only for the six chapter hosts. All other channels must be nonempty in deliverable files. A node requires `id`, `speaker`, `kind`, `text`. Optional fields are `conditions`, `effects`, `next`, `choices`. A choice has `text`, `next`, optional `conditions`. A node may have either `next` or `choices`, never both. A missing link ends that exchange. Empty choices, null links and cross-file links are invalid. A choice label is player speech or a clear action intention, not an NPC line.

`kind` names its channel: `meeting`, `greeting`, `quest`, `relationship`, `festival`, `idle`, `main`. Speakers are the owning character. Plink and Nuzzle's `text` fields are third-person action captions, rendered with the same readable text UI and identified as observation; they are not translated animal speech. No voice or sound is necessary to understand them.

## Conditions

A condition list is AND. An empty/missing list is true. For OR, write two entry nodes or two choices. Each condition is one atomic object, using exactly one key below. Unknown keys or values are errors, never silently true.

| Condition | Meaning | Values |
| --- | --- | --- |
| `{"flag":"q_brindle_done"}` | A durable story flag is true | Declared flags below |
| `{"not_flag":"q_brindle_done"}` | A durable story flag is false or absent | Declared flags below |
| `{"garden_planted_gte":3}` | Occupied garden places at least threshold | Integer 0–8 |
| `{"furniture_placed_gte":1}` | Occupied furniture places at least threshold | Integer 0–6 |
| `{"magic_gte":25}` | Current magic at least threshold | Integer 0–100 |
| `{"magic_lt":25}` | Current magic below threshold | Integer 0–100 |
| `{"visited":"plunge_pool"}` | Location visited in this story profile | Declared locations below |
| `{"time":"night"}` | Narrative time band matches | `dawn`, `day`, `dusk`, `night` |
| `{"weather":"rain"}` | Narrative weather matches | `clear`, `rain` |

The adapter reads counters from validated gameplay state, never from UI labels. Existing garden plants/furniture count immediately, including older saves. No plant species, arrangement, color or furniture identity is required for the main story. A future integration can snapshot a chapter's successful objective into its completion flag; removing furniture or rearranging a garden afterwards never reverses it. The existing prototype also has a separate restoration patch; do not count it as one of eight garden places. It is not an additional quest in this proposal.

The current source's day/night and rain/clear settings map to those exact bands. `dawn` and `dusk` are future authored presentation states, not a claim that the prototype has a natural clock. If unavailable, use `day` or `night`. These four time bands and two weather states are the full dialogue vocabulary here; future regional snow/gust effects need explicit mapping or a schema revision. Time/weather select flavor and presentation, never an expiring objective or mandatory wait.

Declared locations are `home`, plus every character's `location` in the manifest. These are narrative IDs, not Godot node paths. `home_terrace`, `garden` and `home` fit the present clearing/home activities; even these need future visit tracking. Every other named destination is proposed staging, not a verified reachable location.

## Flags and world events

Flags default false. All authored writes are monotonic `true`; cancelling or leaving a conversation sets no failure state. For every character `<c>` declare `met_<c>`, `friend_<c>`, `trusted_<c>`, `q_<c>_accepted`, `q_<c>_prepared`, `q_<c>_done`. For every main quest `<m>` declare `<m>_accepted`, `<m>_done`. External event flags are each character's `quest.event` and the four `world_events` keys in the manifest. There are no hidden relationships, romance scores, daily quotas or affection decay.

A future world interaction sets external event flags after the described physical action. Dialogue must NEVER set `e_*` flags, visited locations, counters, magic, sky or weather. Merely choosing “I will help” is not evidence of an action. Personal event writers require `q_<c>_accepted` and `q_<c>_prepared`; they check the manifest action before setting its event. An existing suitable plant/arrangement can satisfy that action when shown, without replanting or repurchasing. Successful visits made before accepting a quest are retained. Quest events are latched until completion. Intermediate object choices and placements belong to the future world adapter, not extra undeclared dialogue flags; EVENTS.md defines what those interactions must preserve.

| Event | Producer and prerequisites |
| --- | --- |
| Each `e_<character>_*` | Proposed interaction described in the manifest; personal quest accepted and prepared; location visited; real objective satisfied |
| `e_marks_read` | Both paired marks inspected from the dry overlook, after `m_marks_accepted` |
| `e_signal_tested` | Signal checked at the awning, after `m_weave_accepted`; Glow or the covered steady lantern gives the same result |
| `e_water_plan_shared` | Both arrival and downstream reply shared at the town stand, after `m_agreement_accepted` |
| `e_festival_ready` | Player explicitly starts the gathering at the balloon yard, after `m_festival_accepted`; any weather/time, with a sheltered ground option |

All event producers remain to be built. Their plain-language descriptions are acceptance criteria, not evidence of live implementation. Carry/give objectives use proposed lightweight world loan objects with retained source copies, no weight penalty, loss or slot limit; showing a copy at its destination can finish a handoff. The separate proposed quest pouch stores completion souvenirs. EVENTS.md defines the loan lifecycle and exact interaction text. The current prototype has neither of these item systems. The art list distinguishes a story souvenir from a new functional seed, magic reward or furniture-slot unlock.

## Effects and persistence

Only these effects are valid:

```json
{"set_flag": "q_brindle_done", "value": true}
```

```json
{"give_item": "felt_seat_pad"}
```

`give_item` grants the unique story souvenir named by the manifest; it does not consume garden/furniture capacity, unlock a plant variety, charge currency, alter magic or insert an object into the current save. The proposed quest pouch owns these items. Repeating a grant is idempotent by item ID. There are no remove, purchase, teleport, force-motion or arbitrary-code effects. No effect can be inferred from text.

On entry, check conditions; display the text; commit that node's effects once the line is acknowledged. Then evaluate choices against the updated state. Navigation must not reapply unacknowledged effects. Store acknowledged flags and item grants in one durable transaction in a future integration; on write failure show an honest retry/unsaved state, preserving the current game's recovery behavior. A cancelled line does not advance. A completed node cannot award multiple copies after reload. Displaying a bark with no effects needs no save.

After acknowledgement, follow `next`, or let the player choose an eligible choice. Recheck target conditions before entering. If a condition has changed, return to the owning channel's dispatch; never show a blocked target. Menus pause gameplay as today, so no timed race is required. “Later,” back and conversation close always remain available; closing uses no additional authored node and never applies an unchosen choice.

## Dispatch and relationship progression

Explicit topics select their channel. First interaction selects `meeting` if unmet. Subsequent interaction may offer Story (`main`), Help (`quest`), Talk (`relationship`), Festival (`festival`) and Greeting (`greeting`). A caller picks the first eligible entry in that channel's ordered list. An unavailable topic is omitted. Idle rotates through eligible entries without interrupting player control; reduced motion does not suppress the readable text. No automatic topic may consume a player decision.

For `greeting`, every character has all eight time/weather combinations. Completion/late-stage entries precede pending/offer entries in quests and relationships so valid progress is never hidden. For companions, actionable prompts belong to the player choices; the creature's response remains an observable behavior.

Personal quests have one offer, an optional decision to accept, a visit/preparation step, a physical-world objective, completion and an aftermath. An offer can always be deferred before acceptance; an accepted quest stays available and can be left unfinished without a penalty. Relationship stages are acquaintance (`met`), friend (personal quest complete and a voluntary conversation), trusted (friend and main festival complete, with another voluntary conversation). The main story does not require friendship or any personal quest. All fourteen can be finished before or after the finale; the festival remains available as a recurring social setting.

## Authoring and validation

Text is original warm English, no em dashes, maximum 180 Unicode characters per line. Split longer exchanges into linked nodes; choice labels are at most 65 characters. Three explicit voice samples per character live in CHARACTERS.md and do not add hidden playable nodes. JSON strings are literal; no markup, interpolation or untranslated placeholders.

Run from the repository root:

```sh
python3 docs/story/tools/check_dialogue.py
```

The checker parses every file, rejects duplicate JSON keys and unknown fields, checks roster/quest coverage and declared expressions, validates every entry/next reference, checks structural reachability and complete greeting coverage, and walks the proposed graph through representative progression states. It checks isolated personal quests before and after the finale, deferral, missing main objectives and chapter prerequisites, and reward ownership. Four in-memory negative cases ensure broken links, forbidden world-event writes, early reward grants and a removed main-event gate fail. It never launches Godot or writes saves/reports. Passing is authoring-data evidence only; a runtime adapter, UI layout, localization, world-event implementation and playtesting remain future work.
