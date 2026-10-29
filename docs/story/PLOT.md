# A light left for you

Status: **proposal, not built**. Six main chapters and fourteen complete personal stories, using the IDs in [story_manifest.json](story_manifest.json) and the authoring contract in [dialogue/SCHEMA.md](dialogue/SCHEMA.md). The existing cream woodland player makes a home, discovers why a gathering invitation has become confusing, and helps neighbours restore a patient chain of water notices and replies. The Kindly Crown is healthy throughout. The restored thing is communication.

## Play contract and progression

The present prototype supplies walking, looking, Float, Glow, contextual interaction, planting and home decoration. Planting costs **25 magic**, magic regenerates automatically, and planting **blooms immediately**. There are **eight garden places** and **six furniture places**. Decoration requires being grounded inside the home. Those rules remain unchanged. Existing suitable plants and furniture count; no quest asks the player to erase an arrangement, buy a particular item or grow a plant for several days.

The story adds no runtime system in this delivery. Named NPCs, dialogue, visit tracking, quest flags, a quest pouch, give/carry, public prop interactions, sitting, Lamploom and the expanded landscape all require later implementation. “Fits current verbs” means a natural narrative use for an existing action, not a claim that the named story scene is playable. Proposed carry objectives use reusable world loan props with retained source copies; completion souvenirs belong to a separate story pouch. Neither has weight, loss or capacity pressure. Rewards are keepsakes, not new seeds, functional furniture, magic refills or ability unlocks.

The main path is strictly ordered:

`m_home → m_garden → m_marks → m_weave → m_agreement → m_festival`

Every main quest has `<id>_accepted` and `<id>_done`. An offer and an explicit acceptance precede its objective; completion requires the objective and acknowledgement of its completion exchange. The table lists objective conditions in addition to that acceptance. All conditions in a row are required. Main chapter completion stays true after later garden or home changes.

| Chapter and owner | Previous chapter | Objective conditions from manifest | What is restored |
| --- | --- | --- | --- |
| `m_home`, Brindle | None | `visited: home`; `furniture_placed_gte: 1` | A place from which to welcome someone |
| `m_garden`, Thimble | `m_home_done` | `garden_planted_gte: 3` | A recognisable near end of the invitation route |
| `m_marks`, Rillik | `m_garden_done` | `visited: plunge_pool`; `flag: e_marks_read` | The meaning of a paired arrival and reply |
| `m_weave`, Selvie | `m_marks_done` | `flag: e_signal_tested` | A clear, steady way to acknowledge a message |
| `m_agreement`, Ombel | `m_weave_done` | `visited: town`; `flag: e_water_plan_shared` | A public notice that includes more than one arrival |
| `m_festival`, Puffrel | `m_agreement_done` | `flag: e_festival_ready` | The gathering's patient welcome |

Only **one furnishing** and **three occupied garden places** are main-path thresholds. No main or personal story requires all eight garden places or all six furniture places. No story condition spends magic. A `magic_lt: 25` hint may explain that the resource returns by itself; `magic_gte: 25` may offer planting encouragement. Neither creates a story gate, and reading or replying to dialogue consumes none. Starting from an empty garden, the three placements use the existing planting rules, including regeneration; starting with three plants satisfies the same objective immediately.

The source's day/night and rain/clear settings map to `day`, `night`, `rain` and `clear`. The data also authors `dawn` and `dusk` flavour for a possible future presentation state; they do not claim a present clock. Time and weather alter greetings, shelter and the finale's view. They never hide a required character, expire a quest, remove a reward or create a missed event. If only day and night are available, use those lines. Waiting for a specific hour or weather is never necessary.

## Chapter 1: An Open Door (`m_home`)

**Host and place:** Brindle at the proposed `home_terrace`, then the existing home activity represented by `home`.

Brindle has brought a simple question rather than a commission: where would the player like a visitor to pause? A well-meaning sketch of a fully arranged room makes Brindle hesitate. The player needs only one chosen furnishing. An existing piece is welcome; the player can also go indoors, stand on the floor and decorate using the familiar home interaction. The story does not select a style or fill the remaining places on their behalf.

On accepting the chapter, the player may explore as long as they wish. Completion checks that they have visited `home` and have at least one furniture place occupied. Brindle notices the actual act of choosing, without claiming that the piece is necessarily a chair. The discovery is that a home can be prepared for someone without deciding who that someone must be.

The first scale reveal is framed through the oval window and terrace rail. A nearby lamp is small enough to shade with a paw; beyond it, Lamploom's distant windows seem to cross the valley like a loose thread. The Kindly Crown's golden underside is a steady landmark. Brindle mentions a gathering notice that assumes everyone will arrive together, but this is an everyday curiosity, not an alarm.

**Home and garden consequence:** one chosen object makes the home feel inhabited. The garden remains freely available, and prior plants are retained. The next chapter asks what would help someone recognise this terrace. **Completion:** `m_home_done`, then the Thimble chapter becomes offerable. It does not unlock decoration or change the present home rules.

## Chapter 2: Three Small Lights (`m_garden`)

**Host and place:** Thimble in `garden`; available after `m_home_done`.

Thimble calls flowers “small lights” because they help a familiar place stand out, not because every plant is literally a lamp. Thimble once drew a perfectly matching border and now likes the idea of a garden that shows who lives beside it. The player chooses any already unlocked varieties, including repeated varieties, for any three garden places. Three existing plants satisfy the chapter. Colour, species, arrangement and whether Glow is active are not evaluated.

As the garden becomes recognisable, Thimble explains that travellers historically remembered a chain of useful places: a bright patch, a warm window, a covered stop, the next notice. The home is the near end of that chain, not an estate to be completed before the player may participate. The wider reveal follows the eye from a flower at paw height to a waterfall, then to a small garden on another bench. The valley is inhabited at many scales.

Thimble has seen an old drawing of paired marks near the plunge pool and cannot reconcile it with the single line on the current public notice. The player is invited to ask Rillik. No flower is harvested or handed over, and no garden place becomes a permanent quest prop.

**Home and garden consequence:** the player keeps their own three-or-more plants and all remaining empty places. The room is unchanged. **Completion:** acknowledge Thimble's observation with `garden_planted_gte: 3` to set `m_garden_done`. This does not unlock a seed variety, change regeneration or begin a growth timer.

## Chapter 3: What the Water Remembers (`m_marks`)

**Host and place:** Rillik at the proposed dry `plunge_pool` overlook; available after `m_garden_done`.

If the personal low-mark story is still unfinished, Rillik initially reads the lower mark as a small, less important water level beside a larger record. If the player has already compared its rubbing, Rillik recalls that discovery and proposes reading both records together. Looking at the pair reveals writing placed in relation to each height. One records the arrival of water and an upstream message. The other records an acknowledgement and the local situation below. They belong together. A small mark can carry information a larger mark cannot.

After acceptance, the player walks to the dry overlook and interacts with both marks. The proposed world interaction, not a conversation choice, sets `e_marks_read`. The player need not enter the pool, approach an unprotected edge, use Float or wait for water to rise. `visited: plunge_pool` confirms the visit. Rillik's completion exchange accepts the new reading without turning the earlier interpretation into humiliation.

From this lower vantage, the West Wall, falling water and high basin source show why one local observation cannot describe an entire watershed. The paired marks date from the practical high-water years when neighbours raised floors and improved messages. The tree is visible in the distance, healthy and untroubled; there is no hidden illness behind the water story.

**Home and garden consequence:** the player now understands the terrace's own position above the water. No flooding, damage or relocation occurs at home. The garden remains a personal place within this larger geography. **Completion:** `m_marks_done`. Rillik suggests testing a clear acknowledgement at Selvie's awning before copying another public notice.

## Chapter 4: A Reply Across the Mist (`m_weave`)

**Host and place:** Selvie at the proposed `silk_awning`; available after `m_marks_done`.

Selvie is mending an awning and has the public notice beside the current upstream copy and downstream reply. Reading them together reveals the entire misunderstanding: the displayed invitation repeats an older arrangement for one shared ascent. The new messages describe several comfortable travel windows and a sheltered welcome. No one has refused to come. A reused notice omitted the relationship between the messages.

The player helps test a steady acknowledgement across a short sheltered sightline. They can use the existing Glow verb or a proposed hand-operated covered lantern. Both branches are equal, quiet and untimed. No flashing code, precision input, bright-light requirement or magic charge is introduced. After `m_weave_accepted`, the actual awning interaction checks the completed demonstration and sets `e_signal_tested`. Dialogue may offer to try it; dialogue never sets that flag.

The scale reveal is through the silk rather than from a higher dangerous ledge: openings frame bridges, rooflines and distant crowns. The patch allows some light to pass and softens the rest. Selvie describes highland makers leaving repairs visible so another maker can understand the object. A notice can do the same for a reply.

**Home and garden consequence:** the home and three planted places already form a useful welcome. Nothing must become brighter or more elaborate. A lamp seen from the terrace can be a reply rather than a spectacle. **Completion:** `m_weave_done`; Ombel can offer the public arrangement chapter. The Crown's steady glow is scenery, not evidence that a repair succeeded.

## Chapter 5: Room for Every Arrival (`m_agreement`)

**Host and place:** Ombel at the proposed `town` notice stand; available after `m_weave_done`.

The journey arrives at Lamploom's plateau. Roofs that looked like points from home now have benches, cup shelves and ordinary doors. The Kindly Crown is immense overhead, but Ombel's immediate concern is where a guest can put down a damp wrap. The town's scale becomes welcoming through these small uses.

Ombel has been trying to arrange one perfect moment for everyone. With the paired messages in view, the community chooses a rolling welcome: sheltered ground displays can be enjoyed at any time, while a calm-weather balloon view is an optional addition. Visitors do not owe explanations for coming later, staying briefly or preferring the quiet landing. The conversation permits assent, clarification and postponement without a wrong answer or relationship penalty.

After accepting `m_agreement`, the player interacts at the town stand to share both the copied upstream notice and the downstream reply. The physical interaction includes the sheltered and calm-weather arrangements and sets `e_water_plan_shared`. `visited: town` is also required. Carrying and sharing copies are proposed interactions; selecting an agreeable line alone is not proof that the stand changed.

**Home and garden consequence:** the player may include the home terrace in the welcome, with its current furnishing and plants. There is no demand to host every guest, provide a meal or spend remaining capacity. The unfilled places are still theirs. **Completion:** `m_agreement_done`. Puffrel offers a gathering that begins when the player chooses, without a countdown.

## Chapter 6: The Lanterns Stay (`m_festival`)

**Host and place:** Puffrel at the proposed `balloon_yard`; available after `m_agreement_done`.

Puffrel has laid out a basket beneath the silk. The discovery from the personal basket story is echoed here without requiring that story: an invitation can be complete before anything rises. Puffrel asks whether the player would like to begin the gathering. Choosing “later” preserves the offer indefinitely.

After `m_festival_accepted`, the player explicitly chooses **Begin the gathering** at the balloon yard. This is a proposed world interaction and sets `e_festival_ready`. A sheltered ground display is always available, in rain or clear weather, day or night. An optional calm-weather flight view can be selected where the future presentation supports it; it does not transport the player, require flying control or contain an exclusive ending. Source `clear` alone is not proof of physical flight conditions, so the staged flight view remains an authored presentation choice. Reduced motion can retain steady lanterns and grounded silhouettes.

The finale shows the valley answering at many scales: the garden near the home, a patched awning, the shared notice, a quiet seat, town windows and the Crown above them all. Personal-story keepsakes can add contextual callbacks when their quests are done. If none are done, the full gathering and main ending still occur. Nobody remarks that a guest or object is missing.

**Home and garden consequence:** the concluding conversation returns the player's attention to their own terrace, one chosen light among many. Their arrangement stays exactly theirs. **Completion:** `m_festival_done`. The celebration remains a recurring social setting, all personal stories remain available, and future-region invitations create no new active quest debt. The main plot has ended.

## Fourteen personal stories

Each personal story is optional and independent of main-story completion. Its owner offers it on meeting; the player may accept, defer or leave. The data distinguishes `q_<id>_accepted`, `q_<id>_prepared` and `q_<id>_done`. A preparation exchange at the character's visited location explains or chooses the approach. Then a proposed world interaction validates the physical action and sets the manifest's `e_*` event. Only afterward may a completion exchange award the unique keepsake and set the done flag. Accepting, choosing a colour or promising to carry something cannot perform the physical step.

All personal events require accepted and prepared flags and their owner's location visit, as described in SCHEMA. Suitable existing plants/furniture count when shown. The eight garden places and six home furniture places are not pooled or increased. No side story is a main-path requirement. The friend conversation follows a completed personal story; the trusted conversation follows friendship and `m_festival_done`. Both are voluntary, and neither decays. [EVENTS.md](EVENTS.md) owns the exact world prompts and validates the final choices and actions below; preparation explains those choices without performing them.

### Brindle: A Place Left Open (`q_brindle`)

1. **Offer:** at `home_terrace`, Brindle admits to bringing a room sketch that leaves no space for its resident's own ideas. The player can offer to show a chosen furnishing.
2. **Prepare:** visit the terrace and discuss what makes a place feel usable. Any one existing furnishing qualifies; a seat is an example, not a forced furniture type.
3. **Do:** arrange a piece while grounded inside the home if needed, then invite Brindle to look. The proposed showing interaction verifies the arrangement and invitation before setting `e_brindle_seat`.
4. **Complete:** Brindle recognises the player's choice rather than grading the room. Grant `felt_seat_pad` and set `q_brindle_done`.
5. **Afterward:** Brindle stops proposing complete layouts and asks what the player is enjoying. The keepsake pad is a story souvenir; it does not occupy a seventh furniture place or install a new usable chair.

### Thimble: Room for a Different Leaf (`q_thimble`)

1. **Offer:** at `garden`, Thimble worries that a leaf unlike the sample sketch makes the border look mistaken.
2. **Prepare:** the player chooses to show any unlocked variety already planted, or plant one using the normal 25-magic rule. No new seed is required.
3. **Do:** show Thimble the chosen occupied garden place. Existing plants count. The real showing interaction sets `e_thimble_leaf`; merely saying “that one” in a dialogue without a selected place does not.
4. **Complete:** Thimble adds the different leaf to the idea of the garden rather than removing it. Grant `seed_envelope`; set `q_thimble_done`.
5. **Afterward:** the empty keepsake envelope preserves a label or memory. It is not a functional seed unlock, a planting fee or a requirement to use an extra garden place.

### Rillik: The Low Mark (`q_rillik`)

1. **Offer:** at `plunge_pool`, Rillik wonders whether a low mark deserves as much care as the more dramatic high-water line.
2. **Prepare:** agree to compare a rubbing from the dry overlook. The route is walked, with no wading or Float gate.
3. **Do:** explore the low mark and compare its rubbing with Rillik through the proposed world interaction; set `e_rillik_rubbing`. This personal examination is distinct from the main chapter's paired-mark event `e_marks_read`.
4. **Complete:** the low mark records a useful local reply, however modest its height. Grant `flood_rubbing`; set `q_rillik_done`.
5. **Afterward:** Rillik begins asking what a mark says before ranking how large it is. The rubbing can be kept without installing it as home decoration or completing Chapter 3 automatically.

### Selvie: The Unmatched Patch (`q_selvie`)

1. **Offer:** at `silk_awning`, Selvie has two good patch colours and hesitates because neither perfectly disappears into the old silk.
2. **Prepare:** discuss the offered amber and violet patches. Neither is the superior answer or a prerequisite for a different ending.
3. **Do:** choose either patch at the awning and help display its mended spore-silk panel. Only the displayed panel sets `e_selvie_patch`. A colour choice alone does not do the mending or hanging.
4. **Complete:** Selvie keeps the repair legible as part of the panel's life. Grant `patch_sample`; set `q_selvie_done`.
5. **Afterward:** Selvie points out old and new threads with equal affection. The personal patch neither supplies nor substitutes for the main signal test.

### Avren: First Melt, Second Telling (`q_avren`)

1. **Offer:** at `courier_steps`, Avren has a careful first-melt copy and worries that repeating the upstream account without its reply will tell only half the story.
2. **Prepare:** agree to take a nonconsumable copy to the sheltered notice stand. Avren includes the downstream reply; no main-chapter completion is required to understand this local task.
3. **Do:** carry and show the complete copy at the stand, then report that the reply is included. The proposed handoff interaction validates the copy before setting `e_avren_notice`.
4. **Complete:** Avren is glad the receiving community's words are present too. Grant `melt_notice`; set `q_avren_done`.
5. **Afterward:** Avren can share a personal memory without treating every conversation as a formal delivery. The souvenir is another retained copy, not the only document the town needs, and does not bypass `e_water_plan_shared`.

### Pumel: The Cup That Tips (`q_pumel`)

1. **Offer:** at `potters_bench`, Pumel has made a beautiful narrow cup that feels uncertain on the local display ledge.
2. **Prepare:** discuss the broad base and the two offered finishes. The player's preference cannot spoil the cup.
3. **Do:** try the broad base on the stable ledge, then choose warm ochre or soft cream in the proposed prop interaction. Successful placement plus either finish choice sets `e_pumel_cup`; no manual balancing test or breakage is involved.
4. **Complete:** Pumel accepts the changed shape as knowledge about its new home. Grant `broad_based_cup`; set `q_pumel_done`.
5. **Afterward:** Pumel asks where future objects will rest before finishing them. The cup stays in the story pouch unless a later decorative implementation is explicitly designed; it consumes none of today's six furniture places.

### Copperleaf: A Dry Way Home (`q_copperleaf`)

1. **Offer:** at `covered_walk`, Copperleaf has described a route by its destination but omitted the useful place to stop.
2. **Prepare:** agree to carry the dry copy along the covered walk and check the marked rest. No rain is required to make the route meaningful.
3. **Do:** explore that walk with the proposed card and show the resting place. The world interaction sets `e_copperleaf_route`; the card is never soaked, lost or consumed.
4. **Complete:** Copperleaf revises the route description to include a comfortable pause. Grant `route_card`; set `q_copperleaf_done`.
5. **Afterward:** Copperleaf can recommend the longer comfortable route and ask someone to share it. Rain and clear weather alter observations only, and the player never has to hurry between roofs.

### Puffrel: A Basket on the Ground (`q_puffrel`)

1. **Offer:** at `balloon_yard`, Puffrel thinks a basket waiting on the ground has not yet done anything worth sharing.
2. **Prepare:** discuss a ribbon for the grounded display and the nearby place to pause.
3. **Do:** attach either offered ribbon through the proposed prop interaction and acknowledge the accessible seat or viewpoint beside the basket. This is narrative sitting or resting; watching from beside it counts, with no animated sit or required duration. Basket decoration and this acknowledgement are later story interactions, not claims about present home decoration. Set `e_puffrel_basket` when both actions are acknowledged by the world.
4. **Complete:** Puffrel sees that a shared view can be enough. Grant `basket_ribbon`; set `q_puffrel_done`.
5. **Afterward:** Puffrel offers the ground display with the same warmth as a flight view. This story can finish in any weather and does not start or replace the main festival.

### Nacri: The Parcel With Two Homes (`q_nacri`)

1. **Offer:** at `exchange_steps`, Nacri has two address tags on a shared parcel and assumes one must be removed to avoid a misunderstanding.
2. **Prepare:** agree to look at both tags before choosing how to describe the parcel.
3. **Do:** explore both labels at the exchange steps, then agree to retain both on the parcel in the proposed label interaction. The host tag says where it is useful now; the home tag says where it is welcome back. Set `e_nacri_labels` only after inspection and confirmation.
4. **Complete:** Nacri no longer treats affection for two places as a sorting error. Grant `double_address_tag`; set `q_nacri_done`.
5. **Afterward:** Nacri can talk about Lamploom and the lagoon as two true connections. No shipment is dispatched, address is erased or travel commitment imposed on the player.

### Brumlet: A Quiet Place for the Sea (`q_brumlet`)

1. **Offer:** at `quiet_landing`, Brumlet misses the shore and finds the busy gathering place a little too full of small noises.
2. **Prepare:** discuss the wind-sheltered listening places and agree to bring a soft felt liner.
3. **Do:** visit either proposed sheltered nook, choose it and carry/place the liner there through the proposed world interaction, setting `e_brumlet_liner`. Nothing requires audio perception or a timed period of listening; readable observation conveys the moment.
4. **Complete:** Brumlet accepts that a quiet place here can hold a memory of elsewhere. Grant `felt_liner`; set `q_brumlet_done`.
5. **Afterward:** Brumlet is comfortable accepting company without filling every pause. The gathering never pressures Brumlet into the crowd, and the liner is a keepsake rather than new acoustic or furniture functionality.

### Ombel: The Spare Window (`q_ombel`)

1. **Offer:** at `town`, Ombel keeps reassigning an empty window niche because a welcoming building seems, to Ombel, as if every part should already be planned.
2. **Prepare:** discuss looking at the unassigned niche and making a welcoming arrangement that still leaves space for later visitors.
3. **Do:** explore the niche, choose the folded cloth or small empty dish, and place it through the proposed world interaction. The niche remains a town prop outside the six home furniture places. Set `e_ombel_window` after the niche visit and arrangement are recorded.
4. **Complete:** Ombel realises that leaving a place open can itself be a finished act. Grant `oval_window_model`; set `q_ombel_done`.
5. **Afterward:** Ombel asks before allocating the remaining space. The model is a souvenir and the niche is not a new house, quest hub or housing unlock.

### Quillip: The Map That Leaves Space (`q_quillip`)

1. **Offer:** at `map_perch`, Quillip has made a splendid aerial map that says little about where a small walker might stop.
2. **Prepare:** agree to inspect the terrace sightline from the ground. Quillip can come down to the player's perspective.
3. **Do:** explore the sightline and mark one comfortable stopping place on the proposed map. A viewed place is enough; no flying, climbing, precision aiming or hidden landmark hunt is required. Set `e_quillip_map`.
4. **Complete:** Quillip adds the stop and leaves some paper blank for what another traveller may notice. Grant `foldout_map`; set `q_quillip_done`.
5. **Afterward:** Quillip gives distances with rests and landmarks. The map is a story keepsake; it does not enable fast travel or claim undiscovered regions are already accessible.

### Plink: A Little Less Bright (`q_plink`)

1. **Offer:** at `lantern_nook`, a descriptive caption shows Plink moving from a bright edge toward shade. Plink has no spoken line and no translated inner monologue.
2. **Prepare:** the player may intend to try Glow or the shaded steady lantern. The caption reports the beetle's position, not an agreement it supposedly voiced.
3. **Do:** use either option in the proposed nook interaction, then allow Plink to settle in the dimmer resting place. There is no flashing, mandatory high brightness or magic deduction in dialogue. Set `e_plink_shade` when the resting choice is observable.
4. **Complete:** the caption shows Plink resting beneath the shade. Grant `lantern_shade`; set `q_plink_done` through the acknowledged interaction, without implying the beetle spoke or crafted a reward.
5. **Afterward:** Plink returns to the comfortable nook. The shade is an associated keepsake, not an unlock for accessibility settings or an obligation to use Glow elsewhere.

### Nuzzle: The Long Way Round (`q_nuzzle`)

1. **Offer:** at `moss_step`, a caption shows Nuzzle feeling along the edge of a step and turning toward an existing ground-level route.
2. **Prepare:** the player intends to look along that route. The snail is observed, never made to speak or perform a comic struggle.
3. **Do:** explore the route and place a loose leaf as its marker through the proposed world interaction. This is no new path construction, physics push or timed escort. The player's walking pace does not hurry the snail. Set `e_nuzzle_leaf`.
4. **Complete:** a caption shows Nuzzle continuing beside the leaf. Grant `leaf_marker`; set `q_nuzzle_done`. The keepsake records the shared moment, not an object the snail manufactures or hands over.
5. **Afterward:** Nuzzle may be seen along the same comfortable route. Float remains optional for the player and never becomes the solution that the ground-travelling companion must copy.

## Invitations beyond the completed story

The six chapters all resolve within the proposed valley and town. Travellers can talk about other regions during first meetings, personal stories, friendships and the festival. These are complete conversations and optional future destinations. They create no extra quest ID, active objective, inaccessible reward, unresolved cliffhanger or obligation to leave home.

| Possible later visit | Host and connection | A self-contained reason to go |
| --- | --- | --- |
| High Ice Basin | Avren; follow the source above the falls | Compare copied first-melt notices in a sheltered stone hall |
| Granite Falls Valley beyond the home | Rillik and Quillip; follow the lake's benches | See the same water from another comfortable overlook |
| Mineral Springs Terraces | Pumel; follow the warm tributary's dry route | Try a cup on the communal test table |
| Autumn Gorge Woods | Copperleaf; follow the outlet and covered stops | Share a route with room for long rests |
| Tuff Tower Highlands | Selvie and Puffrel; take a later authored pass | See a balloon laid out in a shaded court and admire a repair |
| Karst Lagoon Coast | Nacri; follow exchange toward the lagoons | Visit the other address on a familiar parcel |
| Basalt Shore | Brumlet; a later coastal connection | Sit on the sheltered side of a wind wall with a view of the outwash |

Regional climates are authored identities from WORLD_PLAN, not a new calendar simulation. A future chapter would need its own approved scope and acceptance criteria. This story ends with a home to return to, all fourteen personal stories finishable, and enough blank space on the map to make another visit an invitation.

## Authoring checks and evidence boundary

The standalone JSON checker validates dialogue data, links, expressions, coverage and representative proposed progression. Its result cannot verify a path, character, prop event, inventory operation, motion, sound or an exported game. The world-event requirements above remain implementation acceptance criteria. No Godot run, runtime edit, new save schema or built-region claim belongs to this documentation task.
