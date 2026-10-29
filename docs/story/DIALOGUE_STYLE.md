# How Lamploom speaks

Status: **proposal, not built**. These rules guide the complete proposed dialogue files in [dialogue/](dialogue/). The exact data and evaluation contract is [SCHEMA.md](dialogue/SCHEMA.md); individual personas and three voice samples each are in [CHARACTERS.md](CHARACTERS.md). The fourteen canonical IDs belong to [story_manifest.json](story_manifest.json).

## Warmth with something to say

Let a character notice a concrete thing, express a small preference and leave room for an answer. A broad cup, a dry place on a bench or the corner of a patch can carry a feeling without a speech about kindness. The valley is magnificent; its residents mostly need a comfortable place to put their paws.

Affection is specific. Brindle remembers where someone likes to sit. Rillik admits what the mark does not tell them. Brumlet asks plainly for quiet. Do not make every character an endlessly approving host or every reply a lesson. People can be tired, particular, mistaken, exuberant or uncertain without becoming hostile. A misunderstanding is resolved by hearing more, not by identifying a culprit.

Humour comes from useful objects, differing perspectives and the character's own habits. A cup can have an ambitious wobble. A bird can produce a beautiful map with nowhere to stop. Never make smallness, slowness, another body, an accent, a need for quiet or the player declining into the joke. Avoid baby talk and cute misspellings. These are neighbours, not mascots performing for praise.

The Kindly Crown is healthy and does not speak. Its light can colour an observation, but it is never a warning gauge, a divine command or a reward for virtue. The player is the existing cream woodland creature, not a chosen saviour. Nobody needs the player to become louder, brighter, faster or more social to be welcome.

## Line shape for a game UI

- A node's `text` contains at most **180 Unicode characters**, including spaces and punctuation. Aim for one idea in one or two short sentences. Split a longer exchange into linked nodes rather than squeezing it into small type.
- Choice labels contain at most **65 Unicode characters**. State the player's words or intended next step clearly. “I will look at both marks.” is an intention; it cannot assert that inspection has already occurred.
- Use plain English and ordinary contractions. No em dashes in dialogue or choices. Prefer a full stop, comma or a new node. Avoid semicolon chains, decorative ellipses, all-caps urgency and excessive exclamation marks.
- Read the line at normal speed. The player must understand it without remembering three earlier clauses. Repeat the important place or object name when a pronoun would be ambiguous.
- Give the player a gracious way to leave. Back, close and later remain available through the future interface. Do not attach disappointment, relationship loss or a countdown to a postponed choice.
- Do not put essential instructions only in a sound, colour change, animation, camera move or distant light. Use readable text and the ordinary contextual interaction. Keep reduced-motion and reduced-effects variants semantically complete.
- Do not bake key names into character speech. The actual prompt can use the player's bound controls. “Try your Glow here” survives rebinding better than an instruction to press a particular key.
- Scene descriptions, the narrator's interpretation and NPC speech must remain distinct. The data's only action-caption speakers are Plink and Nuzzle; the future UI labels those lines as observations.

Examples of the intended economy, each below the limit:

> “The notice names one arrival. The reply makes room for several.”

> “That flower already knows this patch. We can show Thimble now.”

> “The lanterns will be here when you come back.”

These are authoring examples, not additional required nodes or hidden objectives. Complete playable proposals live in the JSON files.

## Vocabulary and continuity

Use **the Kindly Crown / 暖冠**, **Lamploom / 灯织镇**, **first melt**, **paired flood marks**, **upstream notice**, **downstream reply**, **spore-silk**, **mycelium-felt**, **covered lantern**, **ground display** and **rolling welcome** consistently. Introduce an unfamiliar craft word beside an ordinary object: a felt pad, a silk awning, a notice sleeve. Do not stack invented nouns into a sentence.

Use “the gathering” or “the lantern-and-balloon gathering” in ordinary speech. “Rolling welcome” describes people arriving over time; it is not a moving festival float. A “reply” means information or acknowledgement from the receiving place, not a magical resonance that fixes the tree. The “small lights” of Chapter 2 can mean recognisable flowers; do not assert that every unlocked plant emits light.

Keep the source's mechanical vocabulary accurate. Planting costs 25 magic, regeneration is automatic, flowers bloom immediately, the garden has eight places and the home has six furniture places. Existing arrangements count. Write “when you feel like planting” rather than “come back when it has grown.” A keepsake `seed_envelope` is not a new seed unlock. A `felt_seat_pad` is not automatically a new functional decoration. Dialogue cannot change magic, capacity, time, weather or installed gameplay rules.

Avoid language of rescue, curse, corruption, sacrifice, debt, chosen bloodline, conquest or a dying Crown. Avoid urgency such as “before it is too late,” “last chance,” “everyone is waiting for you,” or “you missed it.” A character may say they hoped for a simultaneous arrival, then learn another arrangement. The script must not reproduce that old expectation as an actual player deadline.

## Culture is a way of noticing

Every culture is invented from the proposed ecology in WORLD_PLAN and [WORLD_LORE.md](WORLD_LORE.md). The distinctions are conversational habits and useful objects, not imitated real accents, sacred sayings, national stereotypes or costume shorthand. Do not use phonetic spellings to mark an outsider. Residents are individuals; travel, mixed households and craft exchange make the borders between habits porous.

| Region | Shared speech habit | Useful concrete language | Keep it varied |
| --- | --- | --- | --- |
| High Ice Basin | Identify what was observed, then leave room for a reply | Source, melt, sleeve, dry stone, second message, sheltered turn | Avren is exact because of their work; not every basin resident is solemn or terse |
| Granite Falls Valley | Describe a place in relation to its neighbour or next use | Window, ledge, mark, pool, pad, garden, room | Brindle invites, Rillik qualifies evidence, Ombel organises; they do not share one catchphrase |
| Mineral Springs Terraces | Ask where something will rest and whom it must fit | Base, rim, weight, warmth, broad, stable | Practical testing can be playful; avoid portraying everyone as a serene craft sage |
| Autumn Gorge Woods | Include a pause or shelter in a route description | Roof, turn, dry copy, bench, leaf, rest | A longer route is a preference, not a sign that the whole region fears adventure |
| Tuff Tower Highlands | Speak of joining, mending and choosing a suitable moment | Patch, seam, shade, silk, basket, steady, calm | Selvie's tactile quiet differs from Puffrel's bright announcements |
| Karst Lagoon Coast | Keep both ends of an exchange in the sentence | Here, back, tag, shelf, ferry, return, both | Nacri's sociability is personal; avoid commerce jargon or making every resident a trader |
| Basalt Shore | Offer sensory facts and permission for a pause | Wind, wall, felt, low seat, water, quiet | Brumlet is companionable, not an oracle; silence does not confer mystical authority |

A regional first-melt or patch custom can be explained through someone using it. Do not have a newcomer recite an entire culture in a first meeting. A line about a felt notice sleeve can lead to a second optional line about why the sleeve matters. The player never needs to pass a lore quiz to continue.

## Fourteen individual voices

The voice markers below remain recognisable from greeting through trust. Progress changes what a character is comfortable saying, not their entire personality.

| Character | Rhythm and signature attention | Humour and trust movement | Avoid |
| --- | --- | --- | --- |
| `brindle` / Brindle | Short practical invitations; names one comfortable place or object; offers one choice at a time | Domestic understatement; gradually asks before preparing everything | Repeating “if you like” in every line, choosing the player's emotions, grading a home |
| `thimble` / Thimble | Quick paired observations and gentle self-correction; notices leaves, space and possibility | Very serious small gardening comparisons; learns to enjoy a choice without adding advice | Crop efficiency, forced variety, treating immediate blooms as a timed crop |
| `rillik` / Rillik | Measured statement of evidence, followed by what remains uncertain | Overlong labels and self-directed corrections; admits that a small record can matter | Omniscient exposition, declaring an inference a fact, humiliating another observer |
| `selvie` / Selvie | Tactile verbs and small colour differences; offers alternatives with equal weight | Mild personification of cloth; lets a useful repair stay visible | Making one patch the correct answer, ornate poetry in every seam, hidden flaw as moral shame |
| `avren` / Avren | Observation first, feeling second; lists no longer than two items | Exact understatement about luggage; learns that staying to hear a reply is part of delivering | Hurry prompts, duty as self-neglect, claiming all source notices predict downstream conditions |
| `pumel` / Pumel | Direct questions about paws, handles, weight and a stable base | Cheerful deadpan about ambitious prototypes; asks rather than assumes what another body needs | Treating beauty as foolish, one ideal body, breakage penalties |
| `copperleaf` / Copperleaf | Crisp unhurried route phrases; names the next roof or useful stop | Wry appreciation of sensible luxuries; becomes willing to ask for company | Timid caricature, relentless weather worry, shortest-route superiority |
| `puffrel` / Puffrel | One bright announcement, then a genuine choice | Makes tiny setup successes grand; learns to offer a grounded display with full enthusiasm | Countdown language, shouting, calling stillness the consolation option |
| `nacri` / Nacri | Flowing but compact pairs: here and back, this shelf and that home | Organised parcels and misplaced personal cups; says what they need as well as delivering care | Bargaining jargon, forcing a permanent address, “two homes” as divided loyalty |
| `brumlet` / Brumlet | Short spacious sentences, a specific sensation and a plain preference | A quiet literal observation punctures grandness kindly; can request quiet without apology | Mystical wisdom, repeated ellipses, silence as sadness or a problem to cure |
| `ombel` / Ombel | Grounded statement followed by a practical invitation | Lists and spare hooks outgrow their plan; learns to leave a place unassigned | Royal authority, gatekeeping, assigning every visitor a role |
| `quillip` / Quillip | Neat little discoveries, one detail per breath; an occasional repeated word | A fine aerial view misses a useful bench; learns to draw for feet | Chirp spelling, exhaustive completion maps, treating a blank as failure |
| `plink` / Plink | Third-person caption of a position, turn, step or settled pause | Tiny practical shelter choices; later faces the player from a comfortable nook | Speech, inner thoughts, flash language, being used as a battery or carried lamp |
| `nuzzle` / Nuzzle | Third-person caption of feeler contact, a route choice or continuing motion | Scale and patience create a mild visual joke without mocking slowness | Speech, sleepy spelling, an oracle voice, timed escort, a promise the snail could not make |

For Plink and Nuzzle, `speaker` still identifies the observed character as required by the JSON format. It is a data identifier, not a claim of spoken language. A line such as “Nuzzle touches the leaf, then follows the lower edge” reports visible action. “Nuzzle tells you the path is safe” invents speech and a safety claim. A line such as “Plink settles beneath the shade” is valid; “Plink thanks you for saving the festival” reads a mind and invents a crisis. Player choices can express intent, but cannot translate a creature's movement into a binding agreement.

## Conversations, conditions and physical truth

First meetings establish one memorable detail, not the entire plot. Repeat greetings cover all eight combinations of four authored time bands and two weather states. Relationship lines build from acquaintance to a voluntary friend conversation after the personal story, then to a voluntary trusted conversation after the main festival. No affection value falls while the player is away.

Daily routines are presentation guidance. Work can move under a roof or a character can rest at their usual place, with the same conversation available there or at a clear sheltered fallback. Sleep, night, rain, a ferry timetable or a balloon's lack of flight never makes a required topic inaccessible. A greeting may notice rain without implying the player must stop enjoying it.

The existing source maps directly to `day` or `night` and `clear` or `rain`. `dawn` and `dusk` are later authored flavour bands. Do not write “wait until dawn” as an objective or imply a continuous clock already exists. Snow, squalls and regional wind belong to future environmental presentation and require an explicit mapping or a later schema revision; no undeclared weather key is smuggled into this version.

Quest dialogue separates **offer**, **acceptance**, **preparation**, **physical event**, **completion** and **aftermath**. Accepted/prepared/done flags and keepsakes can be committed by acknowledged dialogue nodes according to SCHEMA. External `e_*` flags belong to future world interactions. Visit IDs, garden/furniture counts and magic belong to their actual state owners. A line promising to show a plant cannot count it, a line choosing a ribbon cannot attach it, and a line approving a notice cannot post it.

Before an event, use intention or an accurate prompt: “I will take the copy to the stand.” After its event flag is true, a completion line can say that the reply is included. Do not let the completion topic appear before the validated event. Both main and personal stories must be readable after being postponed, and completed branches must not restart the same request or give duplicate items.

The six main chapters are a complete arc without any personal quest. Personal stories add intimacy and optional festival callbacks, never missing-guest guilt. Festival entries work before and after the finale, with a complete sheltered ground presentation and optional calm-weather view. The ending does not require Glow, Float, a particular time, a full magic meter, every garden place or every furnishing.

## Final authoring pass

Read each character's lines together for voice, then read each quest in order for physical truth. Check that a reader can distinguish a promise from an accomplished act. Check that every colour choice, quiet choice and “later” has the same access to completion. Check that references to future travel are invitations, not unresolved accepted quests.

Run the standalone checker described in SCHEMA for parse, limits, links, vocabulary and representative state coverage. Its pass is authoring-data evidence. It does not establish an installed loader, native UI fit, actual world interactions, motion quality, audible comfort, localization quality or device performance. Those later reviews must preserve the readable alternatives, original game rules and the player's freedom to leave and return.
