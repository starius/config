---
name: produce-audiobook
description: End-to-end, human-in-the-loop workflow for producing a reproducible AI-narrated audiobook from EPUB, PDF, or text with ElevenLabs, multi-voice casting, overlap generation, pause-based splicing, pronunciation repair, dry-master ASR comparison, restrained music and effects, metadata, cover art, and an optional period-appropriate illustrated video. Invoke only when the user explicitly names `$produce-audiobook` or explicitly asks to use the `produce-audiobook` skill; never invoke implicitly for ordinary audiobook, TTS, audio-editing, or image requests.
---

# Produce an Audiobook

Use this workflow to carry one book from source text to a human-approved audio release. Treat TTS output as costly, nondeterministic source material and all local assembly as cheap, repeatable work.

## 1. Establish the project contract

Before generating audio:

- Identify the canonical edition and language. Preserve the original EPUB/PDF/text unchanged.
- Confirm rights to the text, voices, generated output, music, effects, photographs, and illustrations.
- Define deliverables: dry narration master, sound-designed audiobook, release container, and optional illustrated video.
- Define the spoken opening and ending. Normally announce author and title before the literary text, omit technical publishing boilerplate, and close with author, title, and original publication year; obtain human approval for deviations.
- Inspect available memory, storage, encoders, and ASR tools. Avoid monolithic local jobs that may exhaust the machine.
- Estimate TTS usage from cleaned text plus overlaps and reserve quota for repairs. Never spend the whole budget on the first pass.

Use human gates rather than producing the entire book immediately:

1. voice auditions;
2. opening and contrasting-middle samples;
3. one logical arc, usually 30–70 minutes;
4. successive logical arcs;
5. full listening pass and release approval.

## 2. Build immutable source and state layers

Keep four distinct layers:

1. **Canonical text:** extracted, proofread literary text with stable unit IDs.
2. **Immutable sources:** original book, untouched TTS responses, licensed sound assets, accepted images, and source metadata.
3. **Declarative decisions:** cast, pronunciation rules, chunk plan, splice boundaries, sound plan, chapter plan, and visual timeline.
4. **Derived outputs:** decoded PCM, intermediate mixes, review clips, ASR transcripts, final audio, and video.

For every accepted binary source, record size and SHA-256. Make the local build verify this lock before assembly. Never let a build rewrite source manifests or raw-request timestamps.

Keep secrets outside the project. The canonical local build must never call ElevenLabs or require an API key.

## 3. Prepare canonical text

- Extract the book while retaining chapter, paragraph, sentence, and dialogue structure.
- Remove page counts, publisher matter, navigation debris, OCR artifacts, and duplicated headers only after distinguishing them from literary front matter.
- Compare suspicious OCR forms with an authoritative scan or edition. Never silently modernize an unusual historical form merely because it sounds unfamiliar.
- Assign stable IDs to sentences or short paragraph units. Map every generated chunk back to an exact inclusive range of these IDs.
- Separate spoken prompt text from canonical display text. Pronunciation spellings and prosody punctuation may alter the prompt, but must not alter the canonical transcript.
- Mark chapter starts and all dialogue spans before chunking.

## 4. Approve and lock voices

Generate short auditions, not whole chapters. Use the same representative passage for approximately three candidate voices. Also test 1–2 pages from the opening and 1–2 pages from a stylistically different middle passage.

For every approved role, lock:

- service and account accessibility;
- voice ID, not just the displayed voice name;
- model, seed, settings, pronunciation dictionaries, and prompt conventions;
- a canonical reference sample and its text;
- role traits such as age, energy, social register, emotional range, and special delivery.

When blind-comparing seeds, name audition files with the seed alone so the listener can identify the chosen sound without metadata bias.

Do not assume a private or cloned voice is portable between accounts. Verify the same voice ID and settings before using another account, and use it only when licensing and account access permit. A matching display name is insufficient.

Keep the cast economical. Give separate voices where speaker identity materially helps comprehension. When the text explicitly describes several simultaneous speakers, use enough distinct voices to honor that fact. Record performance needs such as chanting, shouting, intoxication, age, or dialect in the cast plan rather than improvising them during assembly.

## 5. Plan chunks for continuity

Choose chunk boundaries at chapters, paragraphs, sentences, or natural rhetorical pauses, never at arbitrary character positions.

Start each non-chapter chunk with one or two sentences already present in the previous chunk. Choose overlap length by sentence length and dramatic continuity, not a fixed character count. The overlap warms up cadence, breathing, timbre, and emotional state; it is not intended for the final assembly.

At chapter boundaries, do not carry dramatic continuity across the break. Plan at least two seconds of explicit silence in the local assembly.

Avoid both extremes:

- Tiny chunks cause repeated voice ramp-up and many audible seams.
- A chapter-sized or book-sized request makes one defect expensive to repair and hard to diagnose.

Record for each chunk: stable text-unit range, overlap units, prompt text, voice lock, expected previous/next anchor, raw output path, and status. Never regenerate already approved text merely to continue the book.

## 6. Preserve every ElevenLabs response

Save each request as an immutable audio-plus-metadata pair. Preserve at least:

- raw returned audio;
- exact submitted text;
- voice ID, model, seed, and settings;
- pronunciation dictionary state;
- character or word alignment when returned;
- request ID and timestamp.

Never trim, normalize, tag, or overwrite raw responses. Store a new raw object for every retry. Before paying for a repair, search older raw generations for a correct reusable passage.

Track quota per generation and stop cleanly when exhausted. Local editing, mixing, ASR, and rebuilding must remain possible without further credits.

## 7. Assemble speech at acoustic pauses

Decode compressed TTS sources to PCM for editing. Encode the release only after speech and sound design are approved.

Use alignment only to locate a candidate region. Confirm every cut acoustically with silence detection, waveform inspection, and listening.

For overlapped chunks:

1. Find the full repeated context in both chunks.
2. Find a real pause after the repeated context in the new chunk.
3. Cut in the middle of corresponding pauses, not at the nominal end of a word.
4. Prefer keeping the previous chunk through its physical end when it already contains a complete carried sentence or paragraph; begin the next chunk after that carried material.
5. Insert or retain explicit chapter silence rather than trusting a TTS boundary to provide it.

Never patch at an approximate word timestamp. A slightly early cut creates missing consonants or syllables; a slightly late cut creates duplicated syllables or sentences. Replace a complete sentence, dialogue turn, or paragraph between natural pauses.

If a pause still contains a plosive click or timbral threshold, place a short clean silence inside the existing pause and apply a very short fade to the incoming audio. Never fade across an audible phoneme. Use waveform zero/low-energy regions to avoid clicks.

Make the assembly manifest the single source of timeline truth. Recompute all downstream timestamps after every edit; never reuse stale clock positions from an older master.

## 8. Handle dialogue without role leakage

- Distinguish character speech from narrator attribution. Text such as “she said” belongs to the narrator unless an explicit editorial decision removes it.
- Remove an attribution only when voice identity makes it redundant, the sentence remains grammatically complete, and the human reviewer approves the textual omission.
- Keep each long monologue on one locked voice, seed, model, and settings. Do not construct one character's continuous story from unrelated voice variants.
- Alternate speakers only at natural pauses. Never change voice inside one uninterrupted utterance.
- When a text repair overlaps a voice reassignment, generate the corrected passage once with the correct role instead of spending credits on two repairs.
- Compare a suspect character passage with the locked reference sample and manifest. Do not diagnose identity from the displayed voice name alone.

## 9. Classify defects before repairing them

Choose the cheapest repair that addresses the actual layer:

| Defect | Repair |
| --- | --- |
| OCR or missing/wrong text | Correct prompt from canonical source and regenerate a natural unit |
| Wrong stress or pronunciation | Regenerate a contextual unit with targeted pronunciation guidance |
| Bad pause or intonation | Adjust prompt punctuation/prosody and regenerate the unit |
| Wrong character voice | Regenerate the whole natural utterance with the locked role |
| Cut syllable, duplicate tail, pop, or seam | Move splice boundaries in existing raw audio first |
| Music/effect problem | Change only the local sound-design plan |

For a TTS repair, include several lead-in sentences so the voice reaches the established delivery, then use only the corrected sentence/turn/paragraph between pauses. Do not insert an isolated regenerated word.

If the replacement reaches the physical end of a raw asset, use the actual decoded end or the next reliable pause. Do not prescribe a guessed end timestamp that can shave off the last syllable.

## 10. Repair stress and prosody contextually

Before changing pronunciation, verify the printed form, grammar, meaning, and historical usage. Homographs and inflected forms may require different stress in different contexts. Never apply a global replacement when only one occurrence is wrong.

Escalate interventions in this order:

1. combining acute accent in prompt text;
2. explicit `ё`, hyphenation of particles, or disambiguating punctuation;
3. punctuation or a conservative prompt-only phrasing adjustment to expose the intended syntax;
4. pronunciation dictionary or phoneme/IPA entry scoped to the exact context;
5. phonetic Cyrillic spelling in the TTS prompt only.

Preserve the book's spelling in canonical text, metadata, subtitles, and QA checklists. Verify the generated sound: a written stress mark is not evidence that the model followed it.

Use punctuation to enforce a meaningful pause or change of intonation, but do not rewrite the author's syntax without explicit approval.

## 11. Audit text and every montage event

Maintain a dry speech master with no music or effects. Fully decode it after each substantial rebuild.

Run a capable local ASR model over the dry master and align the transcript to canonical text at sentence/paragraph level. Prioritize:

- missing words, clauses, and sentences;
- duplicated words or passages;
- clipped beginnings and endings;
- reordered passages;
- unexpected text introduced by overlap.

Inspect mismatches manually. ASR is not a reliable stress checker and does not replace listening.

Generate review clips around every:

- chunk splice;
- repair insertion;
- speaker change;
- chapter boundary;
- music or effect event.

Give each clip 6–10 seconds of pre-roll and enough post-roll to hear the complete result. Report its current position in the full master and the exact canonical text expected there. Mark repaired words and splice points with an asterisk in a full-book listening checklist.

For suspicious boundaries, inspect waveform, level on both sides, silence shape, and tiny repeated phoneme tails. After repairs, rebuild the dry master, rerun ASR comparison, regenerate current review timings, and repeat until clean.

Stop after each logical arc for human review. Do not treat a successful automated comparison as permission to skip a final beginning-to-end human listen.

## 12. Add music and environmental sound last

Lock narration first. Describe music and effects in a declarative mix plan so they can be changed without touching TTS or splice decisions.

- Use music at the opening, selected major chapter boundaries, and ending rather than every scene.
- Allow an opening phrase at full volume, then fade it deeply under narration.
- Preserve at least two seconds of semantic chapter pause even when music bridges the break.
- Use ambience only when directly motivated by the text and useful for place or action.
- Start a sustained ambience audibly, fade and duck it beneath continuing speech, and remove it before it becomes tiring.
- Place brief one-shot sounds at a natural event, but verify that they cannot be mistaken for a splice click.
- Reject broadband or noise-like effects that read as recording damage.
- Review every sound event in context, including the literary sentence before and after it.

Preserve downloaded sound assets unchanged and record creator, source URL, download URL, license, and hash. Prefer public-domain or CC0 material when possible.

## 13. Build release audio from the approved timeline

Derive chapter times from the final assembly manifest after all pauses and overlays. Embed author, title, original year, genre, narration disclosure, cover, and chapters. Verify tags in a second tool or player.

Keep a high-quality archival master and create delivery formats from it. Prefer:

- MP3 when old-car and broad device compatibility dominate;
- M4B when precise chapter navigation and audiobook-player behavior dominate.

For MP3 chapters, use packet/frame-aware times and byte offsets where supported, but expect player-dependent seek error because a marker may fall inside an MP3 frame. Do not repeatedly re-encode an approved MP3 merely to adjust tags; remux/tag without touching the audio stream when possible.

Fully decode the release, confirm duration and stream parameters, test several chapter jumps, and compare the release audio hash or decoded signal with the approved sound-design master as appropriate.

## 14. Create an optional illustrated edition

Create pictures only after the audio timeline is stable.

- Map images to large narrative scenes using text anchors, not equal time slices. Hold one image for several minutes, or ten minutes and longer for a sustained scene.
- Use a verified public-domain author portrait or another licensed opening image when appropriate.
- Derive visual direction from the book's period, place, material culture, emotional register, and historical visual traditions. Do not hard-code one art movement for all books.
- Establish canonical character references. Attach the identity reference to every generation; conversation history alone is not reliable identity control.
- Generate prompts in reviewable batches of about five. Let the human approve direction before producing the full sequence.
- Inspect every candidate for fingers, limbs, repeated faces, age, costume, architecture, props, perspective, and impossible body/object intersections. Do not trust incoming filenames; identify content and map it to the intended scene.
- Repair a failed prompt with explicit staging, geometry, camera placement, and exclusions rather than only asking for “better quality.”
- Store prompt, reference images, accepted output, rejection reason, scene ID, and textual anchor.
- Add titles and thumbnail typography locally so spelling and layout remain reproducible; do not rely on generated text inside images.

Locate each visual transition by recognizing a small window around its anchor phrase in the final audio, finding the actual pause before the phrase, cutting at the pause midpoint, and rounding to the video frame grid. Store both the acoustic anchor and actual frame position.

For a highly compatible upload master with rarely changing images:

- use conventional constant-frame-rate H.264/AAC, `yuv420p`, BT.709, and `faststart`;
- choose 1440p when source art supports it; avoid meaningless 4K upscaling;
- use a roughly ten-second closed GOP and force an IDR frame at each image boundary;
- encode each bounded “one image, one duration” segment independently, then concatenate identical encoded streams without re-encoding.

Do not send a multi-hour sparse-image concat directly through an `fps` filter: FFmpeg may materialize or buffer enormous runs of duplicate frames. Segment encoding keeps peak memory independent of book length and creates a restartable cache.

After muxing, fully decode the video, verify streams and chapters, confirm a keyframe at every visual boundary, extract a frame from every segment, compare it with the normalized source image, and build a contact sheet for human review. Include the platform-appropriate disclosure that narration and/or scene illustrations were AI-generated.

## 15. Preserve reproducibility and handoff

Version-control only irreplaceable inputs and assembly logic:

- canonical source edition;
- accepted immutable TTS audio and response metadata;
- cast, seeds, prompt rules, and pronunciation decisions;
- splice, chapter, sound, and visual manifests;
- accepted licensed music/effects and their source records;
- accepted images, references, prompts, and source records;
- build and validation scripts plus a pinned environment such as `flake.nix`.

Treat final masters, review clips, ASR models/transcripts, extracted text, and other mechanically reproducible artifacts as build outputs. Keep rejected experiments locally when useful, but do not include them in the canonical source set. Never delete user files merely to clean the project.

Require one command to validate locked sources and one command to rebuild locally without API access. A clean rebuild must not dirty version-controlled source files.

## Completion gate

Declare the audiobook complete only when:

- the human approved the narrator, cast, and representative style samples;
- canonical text alignment shows every intended unit exactly once;
- all splices, repairs, voice changes, chapter breaks, music, and effects passed contextual review;
- the dry master passed full decode and ASR-assisted comparison;
- the final release passed full decode, metadata, chapter, and player checks;
- the human completed a full listening pass;
- the project rebuilds from immutable sources without ElevenLabs access;
- any illustrated edition passed image, timeline, keyframe, decode, and contact-sheet review.
