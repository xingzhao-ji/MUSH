# MUSH characters

**Status: proposal, not built.** Canonical identifiers, names, species, heights, quest events and rewards come from [story_manifest.json](story_manifest.json). These are fourteen proposed residents, visitors and small companions. They do not replace the existing playable cream woodland creature, whose rounded ears, cream palette and tucked round tail remain unchanged. The player is not an extra named member of this roster.

The Kindly Crown (暖冠) is healthy. The shared problem is an incomplete exchange of water notices and invitations, followed by a gathering that learns to welcome arrivals over time. Nobody must cure a dying tree, defeat an enemy or race a festival clock. Lamploom (灯织镇), its citizens and the other regions remain proposals.

Walking, looking, Float, Glow, contextual interaction, planting and indoor decoration are existing prototype verbs. **NPC dialogue, relationships, schedules, invitations, quests, journal flags, reward inventories, giving and carrying are future systems.** References below to doing these things describe a possible implementation, not functionality available today. Existing planting remains 25 regenerating magic per plant, with eight garden places; indoor decoration retains six furniture places and its grounded requirement. Already planted flowers and already placed furniture count. New story keepsakes do not silently become unlocked furniture or seed types.

Heights measure the natural neutral silhouette, ground to the top of head or upright ears, excluding detachable equipment. They are art targets, not new collider specifications. Brumlet's height is a natural supported seal posture, not a bipedal standing height. Small companions retain their small scale; framing and captions can aid readability without making them player-sized. All cultural practices, materials, patterns and histories below are invented for this watershed. They borrow no sacred motifs, national dress or real-person identities.

## Roster at a glance

| ID | Name / 简体中文 | Species | Height | Home region | Story responsibility |
| --- | --- | --- | ---: | --- | --- |
| `brindle` | Brindle / 绒枝 | Valley woodland creature | 0.95 m | Granite Falls Valley | Makes welcome personal |
| `thimble` | Thimble / 顶针 | Dormouse | 0.42 m | Granite Falls Valley | Lets the garden hold different choices |
| `rillik` | Rillik / 涓刻 | Water vole | 0.70 m | Granite Falls Valley | Reads paired flood records |
| `selvie` | Selvie / 丝芙 | Silk moth | 0.58 m | Tuff Tower Highlands | Makes a reply visible across the mist |
| `avren` | Avren / 岩温 | Alpine pika | 0.64 m | High Ice Basin | Carries first-melt news and learns to bring replies |
| `pumel` | Pumel / 泉团 | Rock hyrax | 0.73 m | Mineral Springs Terraces | Makes shared objects fit real users |
| `copperleaf` | Copperleaf / 铜叶 | Hedgehog | 0.61 m | Autumn Gorge Woods | Makes room for dry, slower routes |
| `puffrel` | Puffrel / 蓬络 | Jerboa | 0.76 m | Tuff Tower Highlands | Hosts a festival that can stay on the ground |
| `nacri` | Nacri / 贝纹 | River otter | 1.05 m | Karst Lagoon Coast | Keeps both ends of an exchange visible |
| `brumlet` | Brumlet / 雾砾 | Small shore seal | 0.67 m | Basalt Shore | Gives quiet welcome equal importance |
| `ombel` | Ombel / 翁蓓 | Badger | 1.12 m | Granite Falls Valley | Shares responsibility for the town's invitations |
| `quillip` | Quillip / 羽粒 | Wren | 0.18 m | Granite Falls Valley | Draws maps with places to stop |
| `plink` | Plink / 叮点 | Lantern beetle | 0.09 m | Granite Falls Valley | Shows that less light can be enough |
| `nuzzle` | Nuzzle / 团嗅 | Moss snail | 0.12 m | Granite Falls Valley | Makes the ground route matter |

## Brindle / 绒枝

**ID:** `brindle`. **Species and scale:** valley woodland creature, 0.95 m. **Location key:** `home_terrace`.

**Appearance.** A broad pear silhouette with low oval ears, a short muzzle, heavy soft paws and a compact oval tail close to the body. Warm soot-brown fur, a muted russet back and oatmeal muzzle distinguish Brindle from the cream player. A sleeveless moss-grey mycelium-felt work wrap has rounded pockets and plain flax ties. The signature prop is a folded square felt seat pad with one ochre repair corner. Wear is soft and cared for; there are no medals, weapons or ornate costume cues.

**Persona.** Patient and observant, with the bad habit of making a visitor comfortable before asking what comfort means to them. Brindle values permission and dependable little promises, wants the terrace to be a place people return to, and fears a prepared seat may feel like an obligation to stay. They straighten cushions, then deliberately muss one so the room looks usable. Their humour is dry and domestic: a leaning shelf is “taking a rest,” never a moral failure. Affection becomes less busy as trust grows.

**Voice.** Short concrete invitations, one choice at a time, often leaving an easy way to decline. Brindle says “if you like” sincerely, not on every line. They do not narrate the player's emotions.

- “There is room by the window, if you like.”
- “That cushion has settled in before either of us.”
- “You can leave a place open without knowing who will come.”

**Relationships.** Ombel taught Brindle how to mend felt but tends to turn one visit into a town plan; Brindle helps bring the plan back to a single person. Thimble delivers garden clippings and accepts Brindle's uneven pots. Brumlet trusts Brindle to offer quiet company without questions. Brindle admires Puffrel's enthusiasm while reminding them that a seated guest is participating too.

**Home and routine.** A small mushroom lodge beside the player's proposed home terrace, above the flood marks. Morning means opening an oval window and airing pads; afternoon is spent repairing cushions on the porch; evening brings a covered lamp and whichever neighbours happen by. These are flavour schedules, never timed access gates.

**Plot work.** Owns `m_home`, “An Open Door.” Brindle connects the first furnished home with the much larger chain of welcome under the Kindly Crown. In `q_brindle`, “A Place Left Open,” they stop preselecting the perfect guest corner. The player arranges a seat **or any chosen furniture** inside the home, then invites Brindle to look. Event `e_brindle_seat`; keepsake `felt_seat_pad`. The lesson is accepting the player's arrangement, not grading it.

**Player actions.** Explore the terrace, plant nearby and decorate indoors using today's verbs. Future contextual dialogue records the visit; future invitation/reward handling supplies the pad. No compulsory sitting mechanic, carrying requirement, extra furniture slot or new decorative recipe is assumed. Later the player may give Brindle a clipping through the future giving system, without buying affection or changing the main path.

## Thimble / 顶针

**ID:** `thimble`. **Species and scale:** dormouse, 0.42 m. **Location key:** `garden`.

**Appearance.** A round head, large cupped ears and a small spherical torso above tiny hind feet; the long furry tail arcs low behind rather than curling like the player's tucked tail. Hazel fur, cream cheeks and pale warm pink inner ears sit above a faded celadon seed apron. Woven stem cord closes the apron; two broad leaf pockets keep its silhouette simple. The signature prop is an oversized blank seed envelope, creased and repaired with a small translucent plant-fibre patch.

**Persona.** Energetic, precise and quietly sentimental. Thimble values variety and wants to start a garden that does not merely copy the one they remember from childhood. They fear choosing a favourite will exclude something else. They count buds twice, keep beautiful empty husks, and apologise to a watering cup after bumping it. Their humour comes from extremely serious gardening comparisons applied to small inconveniences. Growth means praising a different choice without adding advice.

**Voice.** Quick paired observations, sensory words and friendly self-corrections. They speak about leaves, room and light rather than harvesting efficiency.

- “A round leaf! I had been expecting a pointed one. Good.”
- “I saved the empty envelope. It still holds the possibility.”
- “Three flowers can disagree about colour and share the same rain.”

**Relationships.** Brindle's irregular pots make Thimble anxious until they see how well the flowers fit. Nuzzle is their slow garden companion, never a pest. Plink prefers the shadier part of their carefully lit beds, teaching Thimble not to design for everyone by guessing. Pumel exchanges broad pots for honest reports about awkward rims.

**Home and routine.** A low seed nook in the dry base of Brindle's garden-side store, with a warm oval opening and a root-free moss porch. Thimble checks dew at morning, sorts seed envelopes at midday and watches the garden change colour at evening. They remain findable without waiting for a specific hour.

**Plot work.** Owns `m_garden`, “Three Small Lights”: three planted garden places reveal that welcome can begin at one doorstep. `q_thimble`, “Room for a Different Leaf,” asks the player to plant any unlocked variety and show the chosen place; an existing plant counts. Event `e_thimble_leaf`; keepsake `seed_envelope`. The envelope is a memento, not a promised seed unlock or required consumable.

**Player actions.** Plant within the existing eight places, look at a chosen flower, explore the moss edge and use Glow optionally to enjoy it. Future NPC interaction recognises the choice and awards the envelope. Giving a plant or moving garden slots is not required or claimed as built. Magic regenerates normally; Thimble never asks the player to empty the meter.

## Rillik / 涓刻

**ID:** `rillik`. **Species and scale:** water vole, 0.70 m. **Location key:** `plunge_pool`.

**Appearance.** A compact barrel body, blunt nose, tiny round ears and a low straight tail. Dark umber waterproof fur fades to clay-tan at the throat. A short muted slate-blue felt shoulder wrap leaves the arms free; a plant-fibre belt holds a roll of rubbing paper. The signature prop is a broad graphite-coloured rubbing block in a padded timber grip, not a chisel. Hands and feet are soft and broad, without exaggerated claws.

**Persona.** Methodical, generous with knowledge and uncomfortable being unsure in front of others. Rillik values accurate memory, wants the old flood marks to help living people, and fears becoming a keeper of facts nobody can use. They check a measurement by holding their breath, then laugh at themselves for it. They label drawers with descriptions so detailed that Ombel asks for a shorter version. Their humour is literal and self-directed; the river can surprise them without becoming an enemy.

**Voice.** Measured sentences that distinguish observation from interpretation. A correction is gentle and specific. Warmth appears in small admissions rather than long lectures.

- “That mark tells us the water arrived. The lower one tells us someone answered.”
- “I know the height. I am still learning what it meant.”
- “My shortest note has acquired another page.”

**Relationships.** Avren brings upstream observations; the two initially mistake sending information for sharing it. Nacri notices missing return labels in Rillik's archive. Copperleaf persuades Rillik that a route note should include resting places. Quillip copies their marks, and Rillik learns to leave blank map space instead of correcting it.

**Home and routine.** A stone-plinth record lodge on the dry plunge-pool terrace, above recorded high water. Morning comparison of the waterline, afternoon drying of paper under an awning, evening open archive time. The player meets Rillik at a protected overlook, never by entering moving water or balancing on an exposed ledge.

**Plot work.** Owns `m_marks`, “What the Water Remembers,” using `e_marks_read` to compare the paired marks. Reveals that shared records include a reply, not merely an upstream warning. `q_rillik`, “The Low Mark,” visits the low mark **from the dry overlook** and compares its rubbing. Event `e_rillik_rubbing`; keepsake `flood_rubbing`. Rillik learns that an incomplete record can be repaired honestly without inventing a missing fact.

**Player actions.** Walk, look, explore and use contextual interaction at the proposed overlook. Float is optional elsewhere and never the route requirement. Comparing, taking or giving the rubbing requires future dialogue/inventory handling. No climbing, swimming, precision jump or water simulation is added by this story.

## Selvie / 丝芙

**ID:** `selvie`. **Species and scale:** silk moth, 0.58 m body height, approximately 0.92 m relaxed wing spread. **Location key:** `silk_awning`.

**Appearance.** An upright soft teardrop body with two feathery antennae and four quiet hand-like forelimbs above two supporting feet. Broad folded wings make a scalloped cape silhouette. Chalk-cream fuzz, dusty mauve wing fields and pale apricot edges pair with an undecorated charcoal tool sash. Wings have irregular plain colour fields, not eye spots or culturally borrowed motifs. The signature prop is a large rounded timber spool wound in faded amber spore-silk.

**Persona.** Inventive and warm, but prone to hiding repairs in the hope nobody notices a flaw. Selvie values useful beauty, wants their cloth to be trusted in different weather, and fears a visible mend will disappoint the people relying on it. They test a seam by humming one steady note and have a private collection of almost-matching scraps. Humour is a kindly exaggeration of materials: cloth can be stubborn, but never treacherous. Trust brings a willingness to show the patch before the polished result.

**Voice.** Tactile verbs, small colour observations and open choices. They pause between alternatives so either answer feels welcome.

- “The amber patch will show. I think I would like it to.”
- “A seam is two edges agreeing to stay near.”
- “Let us try one steady light. The mist has enough movement already.”

**Relationships.** Puffrel is a longtime highland craft partner whose larger ideas sometimes outrun Selvie's quiet tests. Avren's precise notices give Selvie a reason to build readable signal coverings. Plink is consulted about glare, not used as a battery. Nacri trades plain coastal dyes and teaches Selvie to keep both makers' names in a repair's written record, handled outside the text-free concept art.

**Home and routine.** A guest room in the silk-awning lodge beside the future balloon yard, shared as a workshop with Puffrel, with separate sleeping nooks. Selvie stretches cloth in the morning, mends under the awning in rain and folds panels before evening. In wind, work moves inside without making quests unavailable.

**Plot work.** Owns `m_weave`, “A Reply Across the Mist.” The steady signal test `e_signal_tested` accepts either Glow or a hand-operated covered lantern, with no flashing or timing requirement. The reveal is an out-of-date notice, not illness in the Kindly Crown. `q_selvie`, “The Unmatched Patch,” lets the player choose either patch colour and help display the mended panel. Event `e_selvie_patch`; keepsake `patch_sample`.

**Player actions.** Explore the awning and optionally use Glow. Existing contextual interaction is the intended input; choosing a patch, mounting cloth and recording the signal are future world-event/NPC systems. Carrying the cloth would be future functionality, not a new current verb. Both colours have identical progression; no precise aiming or paid magic effect is required.

## Avren / 岩温

**ID:** `avren`. **Species and scale:** alpine pika, 0.64 m. **Location key:** `courier_steps`.

**Appearance.** A short oval body with broad round ears held slightly outward, close-set hind feet and no prominent visible tail. Cool pebble-grey fur, a pale chin and muted cinnamon ear rims; a deep teal felt shoulder mantle has a simple overlapping weather flap. A small flat document case of oiled plant fibre rests across the back. The signature prop is its broad, easy-grip rolled notice tube with a plain pale-stone end cap.

**Persona.** Conscientious, brisk and more easily moved by homesickness than they admit. Avren values reliable messages, wants every downstream community to feel included in first melt, and fears that pausing will let someone down. They rehearse a greeting while climbing steps and collect smooth pebbles that fit the same pocket. Their humour is precise understatement about their own luggage. They learn that hearing a reply is part of a delivery, not a delay.

**Voice.** Clear observations first, feelings just after. Lists rarely exceed two things. “Delivered” gradually becomes “heard and answered.”

- “First melt has reached the upper basin. I brought room for your reply.”
- “This pebble travelled lightly. I packed rather more.”
- “I can stay for a cup. The notice will still be true afterward.”

**Relationships.** Rillik respects Avren's records, but both initially overlook downstream answers. Ombel offers a guest nook with no checkout countdown. Copperleaf gives Avren a route with places to rest. Nacri's two-address parcel helps Avren understand that an exchange has two homes. Brumlet shares their homesickness without demanding a grand confession.

**Home and routine.** Originally a low corbelled hall in High Ice Basin; while visiting, a sheltered loft nook in Ombel's Lamploom hall. At morning Avren checks notice sleeves at the courier steps, spends afternoon comparing replies with Rillik and joins a quiet table at dusk. First melt is an invented seasonal community practice of sharing observations, not a borrowed sacred rite.

**Plot work.** Supplies the upstream half of the main notice exchange and supports `m_agreement`. `q_avren`, “First Melt, Second Telling,” carries a copy to the sheltered notice stand and returns with acknowledgement that the downstream reply is included. Event `e_avren_notice`; keepsake `melt_notice`. The personal change is from being useful by leaving quickly to being useful by listening.

**Player actions.** Explore the steps and notice stand by walking. Future carrying, posting and NPC conversation complete this task; the copy is not destroyed and cannot be lost to weather. Looking at the stand can be offered as the same future interaction if a carrying presentation is omitted. No speed check, stamina mechanic or physically simulated parcel is necessary.

## Pumel / 泉团

**ID:** `pumel`. **Species and scale:** rock hyrax, 0.73 m. **Location key:** `potters_bench`.

**Appearance.** A sturdy rounded rectangle with short ears, a broad muzzle, small strong paws and no prominent tail. Warm sand-brown fur and a pale throat contrast with a terracotta mycelium-felt apron. Simple clay-worn bands protect the wrists. The signature prop is a squat mineral-glazed cup with a disproportionately broad foot, cream outside and a quiet turquoise interior; nothing steams or glows on the character sheet.

**Persona.** Affable, stubborn about measurements and willing to laugh first at their own prototypes. Pumel values objects that feel good to use, wants visitors of different sizes to find a cup that fits, and fears “beautiful” may become an excuse for uncomfortable design. They set down every new cup, tap the rim twice and listen. They invent absurdly formal names for failed pots, then reuse the clay. Growth means asking before assuming what another body needs.

**Voice.** Weight, warmth and balance are their everyday vocabulary. They ask direct practical questions and use compact, cheerful deadpan.

- “Does that handle suit your paw?”
- “An excellent cup. A rather ambitious wobble.”
- “We can keep the colour and change the base.”

**Relationships.** Thimble reports honestly about pots. Brumlet needs a low, stable vessel and helps Pumel see that a handle is not useful to everyone. Ombel sometimes orders matching sets; Pumel suggests a family of different shapes instead. Selvie shares a preference for visible, thoughtful repairs.

**Home and routine.** Home is a cool-side pottery lodge at Mineral Springs Terraces, outside hot runoff; their visit uses a small lodge and sheltered workbench in Lamploom. Morning is for setting out dry work, midday for trying handles and evening for tea. Any future kiln is background craft, never a player fire-management task or a claim that hot springs are safe to enter.

**Plot work.** Helps make the rolling welcome materially comfortable and supplies stable lamp bases. `q_pumel`, “The Cup That Tips,” tests a broad base on a stable display ledge and offers a finish choice. Event `e_pumel_cup`; keepsake `broad_based_cup`. The disagreement resolves through a shared test, not by exposing an incompetent maker.

**Player actions.** Explore the workbench and inspect the cup with look/interact. Finish selection and cup placement at the demonstration ledge are future contextual events. The reward is a story keepsake; making it placeable within the home's existing six slots is a separate future feature. Carry/give handling, if used, is future and gentle, with no breakage state.

## Copperleaf / 铜叶

**ID:** `copperleaf`. **Species and scale:** hedgehog, 0.61 m. **Location key:** `covered_walk`.

**Appearance.** A low dome of broad, soft-looking quills above a narrow pale muzzle and small dark paws. Quills are copper, umber and muted gold in large readable groups, never needle-sharp horror detail. A slate waxed plant-fibre shoulder cover sits over the back without hiding the silhouette. The signature prop is a flat route-card folio with a leaf-shaped closure, hanging low on a wide strap.

**Persona.** Wry, practical and quietly delighted by unplanned discoveries. Copperleaf values making a journey comfortable, wants the rainy gorge route to feel like a choice rather than an ordeal, and fears being valued only for arriving quickly with news. They test benches before recommending them, tuck wet leaves into the wrong pocket and remember the exact roof that stayed dry in a shower. Their humour prizes sensible luxuries. Learning to ask for company is their personal stretch.

**Voice.** Unhurried, crisp and lightly amused. Distances become useful descriptions: “one sheltered turn” rather than an impressive number.

- “The short way is shorter. This way has a roof.”
- “I have marked a good place to stop. That belongs on a map.”
- “The rain can finish its sentence while we sit here.”

**Relationships.** Quillip initially draws the quickest line; Copperleaf adds a place for tired feet. Avren is a willing but hurried pupil. Nuzzle becomes proof that ground routes deserve attention before shortcuts. Brindle supplies a spare pad without requiring a visit in return.

**Home and routine.** A deep-eaved lodge along Autumn Gorge Woods' sheltered bank route; the Lamploom visiting nook opens onto a covered walk. Morning route notes, afternoon leaf sorting and an evening seat with a view of the rain. Weather offers alternate greetings, not availability restrictions.

**Plot work.** Makes the main shared notice include sheltered arrivals and supports `m_agreement`. `q_copperleaf`, “A Dry Way Home,” carries a dry route card along the covered walk and shows a marked resting place. Event `e_copperleaf_route`; keepsake `route_card`. Copperleaf moves from quietly planning for everyone to inviting someone to share the journey.

**Player actions.** Walk and explore a comfortable ground route; Float can be an optional personal detour, never the objective. Carrying, showing the card and NPC follow-up are future systems. Rain cannot ruin the card or reset progress. A resting place can be acknowledged through interaction without adding a sitting mechanic.

## Puffrel / 蓬络

**ID:** `puffrel`. **Species and scale:** jerboa, 0.76 m including upright ears. **Location key:** `balloon_yard`.

**Appearance.** A small narrow torso, very long upright ears, generous hind feet and a long fine tail with a soft dark tip. Pale cinnamon fur, a creamy belly and dusty rose inner ears; a plum spore-silk waistcoat has two round unmarked toggles. A plain broad strap carries a coil of peach ribbon. Their signature prop is a small timber tether winder with a thick soft cord, shown resting rather than pulled taut.

**Persona.** Exuberant, hospitable and inclined to promise the most spectacular version first. Puffrel values shared delight, wants the festival to be memorable and fears a grounded balloon will disappoint everyone. They narrate tiny setup successes as grand arrivals and give spare ribbons names based on their shapes. Their humour is buoyant, never teasing someone for staying low. They learn that spectacle can make space for stillness without losing its joy.

**Voice.** Short bright announcements followed by a real choice. They avoid counting down, urging hurry or calling a calmer option the lesser one.

- “The basket has arrived exactly where we left it!”
- “Would you like the ribbon here, or somewhere quieter?”
- “A festival can lift your spirits with both feet on the ground.”

**Relationships.** Selvie is the craft partner who turns big promises into reliable cloth. Brumlet is a friend whose preference for a quiet ground display changes Puffrel's idea of a finale. Ombel helps replace a single arrival hour with a rolling welcome. Plink is offered a shade before any lantern is brightened. Puffrel admires Avren's calm precision and learns not to mistake it for lack of excitement.

**Home and routine.** A separate sleeping nook in Selvie's silk-awning lodge, with the balloon yard outside on broad level ground. Morning is for inspecting grounded baskets, afternoon for arranging ribbons and evening for greeting whichever guests are present. Balloon trips are a later optional calm-weather view, with a satisfying sheltered display available in any weather.

**Plot work.** Owns `m_festival`, “The Lanterns Stay.” After acceptance, the player explicitly chooses Begin the gathering to set `e_festival_ready`; no clock starts. `q_puffrel`, “A Basket on the Ground,” decorates the grounded basket with a chosen ribbon and shares its still display. Event `e_puffrel_basket`; keepsake `basket_ribbon`. Watching from beside it counts; an animated sit is not required.

**Player actions.** Explore the yard, look at the display and optionally use Glow. Exterior basket dressing, invitations, beginning the gathering, sitting and balloon travel are future event/NPC features, not extensions silently granted to current indoor decoration or Float. The player can stay near the basket using ordinary movement; no airborne course or timed tether sequence is proposed.

## Nacri / 贝纹

**ID:** `nacri`. **Species and scale:** river otter, 1.05 m in an easy upright posture. **Location key:** `exchange_steps`.

**Appearance.** A long tapered torso, small round ears, broad whisker pads, strong low feet and a thick tail that rests behind. Deep chestnut fur, a pale throat and dark wet-looking paws; a soft jade reed-cloth crossbody sling leaves the shoulders free. Its two broad pockets are visibly different sizes. The signature prop is one rounded fibre parcel with two plain oblong address tags on separate cords, shown blank in art.

**Persona.** Sociable, observant and good at making a stranger feel remembered. Nacri values reciprocal exchange, wants to belong both at the lagoon market and in the valley, and fears being asked to choose one home to make others comfortable. They remember where a parcel began but forget where they put their own cup. Their humour enjoys gentle reversals: the parcel is organised, the courier less so. They grow more willing to say what they need rather than express care only through deliveries.

**Voice.** Flowing but compact, often pairing two concrete places or people. Questions include the return journey. Nacri never turns speech into bargaining jargon.

- “One tag tells it where to go. The other says it may come back.”
- “I know every parcel here. Has anyone seen my cup?”
- “Two homes are not half a home each.”

**Relationships.** Avren becomes a fellow messenger who learns to carry replies. Rillik learns from Nacri's two-ended record keeping. Brumlet shares a lower, quieter landing away from the busy exchange. Selvie exchanges dyes and careful cloth repairs with them. Ombel offers an open guest nook instead of asking for a permanent address.

**Home and routine.** A reed-and-mycelium stilt hall at Karst Lagoon Coast, with a small exchange lodge above Lamploom's safe landing. Morning unpacking, midday sharing news and evening sorting return tags. Proposed ferry schedules supply atmosphere only; the player cannot miss a required departure.

**Plot work.** Connects upstream notices with downstream replies and provides the clearest personal image for the main restoration. `q_nacri`, “The Parcel With Two Homes,” explores both tags at the exchange steps and agrees to retain both. Event `e_nacri_labels`; keepsake `double_address_tag`. Nobody claims or confiscates the parcel; its contents are shared craft samples, not a mystery threat.

**Player actions.** Walk, inspect both labels and use future NPC/contextual choices. A later give/carry presentation may move the parcel, but this quest can resolve at its resting place. No trade economy, swimming, boat handling or mandatory purchase is assumed. The tag reward records a relationship, not ownership of another person's home.

## Brumlet / 雾砾

**ID:** `brumlet`. **Species and scale:** small shore seal, 0.67 m ground-to-head in a natural foreflipper-supported resting posture; approximately 1.28 m nose-to-hind-flipper length. **Location key:** `quiet_landing`.

**Appearance.** A horizontal spindle body with a broad rounded head, tiny ear openings, short foreflippers and paired rear flippers. Steel-grey fur is softly mottled with pale pebble shapes; the muzzle and underside are warm off-white. A loose moss-green felt shoulder drape sits over the upper back without pretending the seal has arms or a waist. A folded slate-blue felt liner rests beside the foreflipper as the signature prop. No human legs, boots, bipedal posture or tail tassel.

**Persona.** Companionable, perceptive and comfortable with silence, though initially reluctant to state a need in a busy gathering. Brumlet values unforced company, wants a place where sea memories can sit alongside valley life and fears their quiet request will be treated as everyone's problem. They arrange three smooth pebbles before settling and notice changes in wind before changing the subject. Their humour is slow and well placed; a single literal observation can undo Puffrel's grand speech kindly.

**Voice.** Short, spacious sentences with sensory specificity. They say what is comfortable without apologising indefinitely. Silence is not written as mysterious wisdom or inability to converse.

- “Here, I can hear the water without the wind in it.”
- “The balloon is very tall. This cushion is my height.”
- “Stay if you like. We do not need a subject.”

**Relationships.** Puffrel learns to offer the ground display as a complete celebration. Pumel makes low stable cups after listening to Brumlet's needs. Nacri supplies familiar coastal news without insisting on a return trip. Brindle becomes an easy companion. Avren finds someone who understands missing a place while enjoying another.

**Home and routine.** A low sheltered shore lodge on Basalt Shore, with a dry low-entry guest retreat at Lamploom's quiet landing. Wide gradual ground routes join it to the town. Morning is spent observing water, afternoon resting in shade and evening sharing the quieter edge of the display. They are not stranded and do not need the player to drag, carry or rescue them.

**Plot work.** Helps the main agreement include quiet, ground-level participation. `q_brumlet`, “A Quiet Place for the Sea,” chooses a wind-sheltered listening place and carries a soft felt liner there. Event `e_brumlet_liner`; keepsake `felt_liner`. Choosing the place is an expression of preference, not a treatment or cure.

**Player actions.** Explore two comfortable listening positions and look toward the water. Future dialogue records a choice; future carry/placement handles a lightweight liner. The proposed complete flow has a direct interaction alternative without physical dragging. No water traversal, seal-riding or sound-identification test is required; captions can convey the sensory observation.

## Ombel / 翁蓓

**ID:** `ombel`. **Species and scale:** badger, 1.12 m. **Location key:** `town`.

**Appearance.** Broad shoulders, a gently tapered face, low rounded ears and weighty paws form an upright soft trapezoid. Charcoal and warm ivory facial stripes are broad and calm; body fur is dusty grey. An amber-brown felt apron coat has simple timber buttons and an open lower hem. The signature prop is a small oval-window model in a carrying frame, its tiny shutter open. The character has no civic crown, rank badges or borrowed ceremonial clothing.

**Persona.** Generous, capable and tempted to answer a question before hearing the whole of it. Ombel values a town where people can find a place, wants every visitor included and fears an unassigned space will look like neglect. They collect spare hooks, count windows when thinking and keep trying to provide a reason for every empty shelf. Their humour admits the limits of administration: a list can hold a great deal, but not a visitor. They learn to share decisions and leave some room unplanned.

**Voice.** Grounded declarative sentences followed by a practical invitation. They move from “I have arranged” toward “What shall we leave open?” without becoming a different person.

- “We have copied the notice. Now let us hear the answer.”
- “I prepared a place for everything. The everything grew.”
- “That window can be welcoming before we know who will use it.”

**Relationships.** Brindle brings Ombel's town-sized care back to individual choices. Avren stays in their guest loft without an expiry date. Nacri demonstrates why one permanent address is not always the right answer. Puffrel works with Ombel on the rolling festival. Rillik is a trusted record keeper whom Ombel learns not to turn into an unquestioned authority.

**Home and routine.** Lamploom's open-window hall, a modest timber and felt lodge on a stone plinth near the shared notice stand. Morning shutters, afternoon replies and evening a lamp at the unassigned window. Ombel is a caretaker and convenor, not a monarch, gatekeeper or owner of the Kindly Crown.

**Plot work.** Owns `m_agreement`, “Room for Every Arrival.” At `e_water_plan_shared`, both the upstream notice and downstream reply are shared, including shelter and calm-weather options. `q_ombel`, “The Spare Window,” explores an unassigned niche and chooses a welcoming arrangement. Event `e_ombel_window`; keepsake `oval_window_model`. The niche stays open to later arrivals rather than being awarded to a single winner.

**Player actions.** Explore the town and use contextual interaction. Choosing the niche arrangement is a future world event, separate from today's indoor decoration. Posting notices, recording agreement, invitations and rewards need future systems. No vote timer, faction reputation, building ownership or citizen simulation is claimed.

## Quillip / 羽粒

**ID:** `quillip`. **Species and scale:** wren, 0.18 m perched height; approximately 0.25 m wingspan. **Location key:** `map_perch`.

**Appearance.** A tiny round chest, fine short beak, cocked tail and thin feet form a jaunty comma silhouette. Warm bark-brown feathers have restrained darker bars and a pale buff chest. A narrow moss-coloured cord supports a very light folded-paper case; there are no sleeves, human hands or boots. The signature prop is a miniature foldout map, laid beside the perch or held by the beak, never oversized enough to erase the bird's scale.

**Persona.** Curious, exacting and easily carried away by a beautiful overview. Quillip values making places understandable, wants to make a map that feels generous and fears empty space will look like ignorance. They name bends after temporary shapes, revise those names and then forget the first version. Their humour is rapid observational enthusiasm. They learn that a map for feet must contain things wings can ignore.

**Voice.** Neat little discoveries, one detail per breath. A small repeated word marks excitement without turning all speech into chirping.

- “A bend, a bench, another bend. Much better.”
- “I drew the view. You found the way through it.”
- “This blank bit is where we can stop.”

**Relationships.** Copperleaf adds shelter and pauses to Quillip's routes. Rillik provides reliable marks and accepts fewer labels. Nuzzle reveals why the low route matters. Puffrel likes overhead maps; Quillip learns to supply a ground version too. Thimble leaves a comfortable twig perch at the garden edge.

**Home and routine.** A shallow dry nest niche above the map perch on the town-side terrace, with a small hood against rain and a low consultation ledge for ground neighbours. Morning sightlines, afternoon corrections and evening listening to reports from walkers. They can be found at the ledge without the player flying up to the nest.

**Plot work.** Links the intimate terrace to the wider view and helps ground the main route in reachable places. `q_quillip`, “The Map That Leaves Space,” explores a terrace sightline and marks one comfortable stopping place. Event `e_quillip_map`; keepsake `foldout_map`. The map is deliberately unfinished without being broken.

**Player actions.** Walk, look and explore; Float can give an optional different view. Future marking and conversation record a ground-accessible stop. No flight course, cartography minigame, compass mechanic or exhaustive exploration percentage is required. Carrying the paper would use the future item system.

## Plink / 叮点

**ID:** `plink`. **Species and scale:** lantern beetle, 0.09 m resting height; approximately 0.14 m body length. **Location key:** `lantern_nook`.

**Appearance.** A rounded pill-shaped beetle with six low legs, two short clubbed antennae and smooth shell covers. The shell is muted plum with an amber abdomen visible at the rear; the natural light is steady and subtle. A narrow soft moss-fibre loop can carry a petal-sized shade, with no tiny human outfit. The signature prop is a translucent cream leaf shade resting beside them. Face detail stays kindly and minimal; no fangs, exposed anatomy or piercing luminous eyes.

**Persona.** Direct, sociable in small groups and very clear about preferences once asked. Plink values comfortable light, wants a place near the gathering without being its brightest object and fears being praised only for glowing. They rotate pebbles until the shadow falls neatly and keep finding excellent roofs under cups. Their humour is miniature and matter-of-fact. They need no lesson in becoming brighter or braver.

**Voice.** Plink does not speak. Short action captions show a clear preference through position and movement; they do not translate flashes or invent private thoughts. Flashing is never a language or input puzzle.

- “Plink steps beneath the leaf and settles.”
- “Plink inspects the cup, then rests under its handle.”
- “In the softer light, Plink turns toward you.”

**Relationships.** Selvie asks Plink to choose comfortable signal coverings. Puffrel learns not to decorate a living friend as a lamp. Thimble leaves a shaded garden margin. Nuzzle shares low shelter without crowding. Brumlet understands enjoying a gathering from its gentler edge.

**Home and routine.** A dry crevice in a low lantern-nook post, beneath a removable leaf hood, with a clear walking approach. Plink rests in shade by day and visits nearby flowers in the evening. Daytime conversation remains available at the nook without waking penalties or a forced night setting.

**Plot work.** Provides a personal reason for the main steady-lantern option and less glare. `q_plink`, “A Little Less Bright,” tries Glow **or** a shaded steady lantern, then lets Plink choose a dimmer rest. Event `e_plink_shade`; keepsake `lantern_shade`. Both branches achieve the same warmth and progress.

**Player actions.** Look, explore and optionally toggle Glow. Future NPC/event handling records the shade choice and gives the keepsake. The companion is never captured, equipped or carried as a light. No blinking, strobe, brightness tolerance test or magic drain is required.

## Nuzzle / 团嗅

**ID:** `nuzzle`. **Species and scale:** moss snail, 0.12 m shell-top height; approximately 0.23 m extended body length. **Location key:** `moss_step`.

**Appearance.** A low rounded foot supports one broad spiral shell and a small soft head with two long upper feelers and two short lower ones. The body is warm grey-lilac, the shell muted ochre with broad cream growth bands, and a little moss grows naturally over its rear. No garments, humanoid limbs or saddle. The signature prop is a loose dull-green leaf marker set alongside the path, never stuck to the animal.

**Persona.** Attentive, determined and content to arrive at their own pace. Nuzzle values a route that remains a route when nobody is watching, wants to visit the mossy edge of the celebration and fears being relocated “for their own good.” They inspect every leaf edge and find pleasant pauses in places others call gaps. Their humour is calm literal timing, without making slowness a defect. Their story asks other neighbours to notice the ground rather than requiring Nuzzle to change.

**Voice.** Nuzzle does not speak. Small complete action captions describe tactile contact and chosen direction without claiming to read thoughts. Avoid prolonged letters, exaggerated sleepy speech or a wise-oracle register. Captions can be read at the player's pace.

- “Nuzzle follows the damp edge of the stone.”
- “At the tall step, Nuzzle turns toward the longer ground route.”
- “Nuzzle touches the loose leaf with one feeler, then continues.”

**Relationships.** Thimble treats Nuzzle as a garden neighbour rather than a pest. Quillip learns to map a ground route after watching them. Copperleaf supplies shelter information at snail scale. Plink shares a leaf roof. Brindle leaves a low clear threshold where possible instead of offering to carry them unasked.

**Home and routine.** A shallow moss-step recess at the garden's edge, with damp shade and a dry upper lip. Morning leaf inspection, afternoon shelter and an unhurried evening circuit. Their home and route remain outside planted slots; they neither eat progress nor demand a garden redesign.

**Plot work.** Makes the festival's welcome tangible at the smallest scale. `q_nuzzle`, “The Long Way Round,” follows an **existing ground-level route** and marks it with a loose leaf. Event `e_nuzzle_leaf`; keepsake `leaf_marker`. No bridge, excavation, new terrain or player-built path is implied.

**Player actions.** Walk, look and explore the low route. Future contextual placement and conversation confirm the loose marker; future giving could offer a leaf, but moving Nuzzle is never required. Float is optional for the player and cannot substitute for checking Nuzzle's ground route. The quest has no escort timer, follow-distance test or penalty for leaving and returning.

## Shared continuity and implementation boundary

- Personal plots are optional and remain available after the rolling festival. A reward acknowledges a shared moment; it does not purchase friendship, determine a moral score or gate a required main chapter.
- All fourteen can have first meetings, repeat greetings, weather/time observations, quest steps, festival lines, idle remarks and growing trust. Plink and Nuzzle use observable action captions throughout, including quest responses; they do not speak. Their distinct voices above guide the loadable proposals in [dialogue/](dialogue/). No relationship decay, missed-day penalty or real-time calendar is proposed.
- Main restoration concerns the paired flood records, a copied upstream notice, the downstream answer and inclusive invitations. The healthy Kindly Crown is the landmark under which people meet. It does not issue quests, speak, demand magic or change health with player progress.
- Notice text belongs in accessible dialogue/UI when implemented. Concept sheets show blank paper faces. Lighting and small-creature motion must respect reduced motion/effects and remain separate from gameplay physics.
- [ARTLIST.md](ARTLIST.md) is the production-facing concept proposal. It uses the same fourteen IDs and scales, covers every canonical reward and event prop, and supplies homes without claiming any settlement has been built.
