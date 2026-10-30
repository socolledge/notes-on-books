# Notes on Books — developer handoff

Single-file web app (index.html) deployed at https://socolledge.github.io/notes-on-books/
(GitHub repo: socolledge/notes-on-books; deploy = upload index.html, commit, wait for Pages build).
Backend: Supabase (auth + Postgres, schema in schema.sql, single-user RLS). The app asks for the
Supabase project URL + anon key on first run per device and stores them in localStorage.

Current version: v2.5 (index.html — the v2 UI is now THE app). legacy-v1.13.html kept as rollback.
REQUIRES A ONE-TIME DB MIGRATION before first use of v1.6+ — see the v1.6 entry below (already done
if you're reading this after having deployed v1.6; v1.7-v1.11 need no further migration).
- v1.0: authors/works/notes model, editor with quote/note panes, tags + pinned tags, configurable
  purposes with conditional fields, locators (page/EEBO/chapter/Kindle/folio), Chicago + MLA
  citations with 4 copy modes, search/filters, JSON/CSV export + JSON import (also the restore path),
  source-status badges (surrogate → "cite original").
- v1.1: autosave (1.2s debounce), tag-input focus fix (partial DOM updates), locator save-on-blur,
  Google Books added to lookup, URL metadata fetch (corsproxy.io fallback), programmable text-cleanup
  rules (settings.cleanup_rules) + built-ins (collapse spaces, linkify/strip bare URLs), bigger
  library fonts.
- v1.2: splash screen (procedurally generated feather SVG inline), works/library sorting, citation
  parser rewrite (handles EEBO/ProQuest "Last, First,d.YYYY. YYYY. Title. URL." plus Chicago
  footnote/bibliography formats), custom citation styles (settings.custom_styles, token templates
  like {authors} {title} {place} {publisher} {year} {pages}), bulk edit in library (select mode,
  bulk tag/purpose add/remove, "edit shared work" for citation fixes).

Architecture notes: all data cached in JS object DB on login; four <script> blocks in index.html
(1: state/citations/copy, 2: editor/work modal/parser/lookup, 3: library/works/people, 4: settings/
cleanup/export/import/boot). Settings persist in the settings table as one JSONB row per user.
Verify changes with: extract script blocks → node --check; citation formatter has been tested against
Chicago/Turabian and MLA reference examples.

This app was built in the Cowork session "local_2089317d-dd43-4599-a77b-ca0585ffbe05" (readable via
session-info tools for full history).
- v1.3: quill logo (shared SVG defs + <use>) in appbar/splash/auth, persistent library filters
  (localStorage nob_lib) + named saved views (settings.saved_filters), works→library jump
  (notes-count chip → filtered by work, sorted work+page), cleanup system v2 (built-in "join broken
  lines" for PDF hard returns; rules gain mode:text|html with \n \t tokens + regex flag; multi-step
  sequences in settings.cleanup_seqs), collapsible tag management, font consistency (CSS vars
  --qfont/--qsize/--nfont/--nsize with !important child overrides + paste sanitizer stripping
  source formatting), font settings (settings.fonts).
- v1.4: replaced ALL native <datalist> autocomplete (tag-in, lib-tag-in, pin-in, bulk-tag-add,
  work-modal author/editor/translator add) with a custom JS makeAutocomplete() component — fixes an
  iOS Safari datalist reliability bug where the native widget intermittently stole focus mid-type.
  Purpose-field library filtering: fields get a "filterable" checkbox in Settings purpose admin;
  filterable fields render as OR-within-field / AND-across-fields chip facets in Library
  (LIB.pf state, persisted in localStorage + saved views). Fixed author <select> not showing
  "selected" option after cascading pick. Sticky pane-head toolbars via position:sticky pinned
  below the appbar (--appbar-h CSS var, measured in JS) — quote/notes toolbars stay visible while
  the long text scrolls under the appbar. Cmd/Ctrl+B/I/U shortcuts on the rte panes. Cleanup system:
  🧹 button now captures the live text selection (via onmousedown, before modal focus-steal) so
  built-ins/rules/sequences apply to just the highlighted text when present (inline result, no
  paragraph rebuild) vs. the whole pane when nothing's selected; sequence builder got an inline
  "+ Define a new find/replace step" sub-form so a multi-step button can be built in one dialog
  without pre-creating each rule — steps defined this way are saved with hidden:true and excluded
  from both the cleanup menu's "Your rules" list and the Settings rules table (visible only inside
  their parent sequence's step description); deleting a sequence garbage-collects any hidden rules
  it exclusively owned.
- Post-v1.4 hotfix: "+ New work" did nothing on any device — a leftover `${peopleList}` reference in
  renderWorkModal()'s template (orphaned by the v1.4 datalist removal) threw a silent ReferenceError
  before the modal could show. Removed.
- v1.5: **Import from Kindle.** Settings → Backup & data → "Import from Kindle (HTML)" — pick a
  downloaded Kindle "Notebook Export" HTML file (Kindle app/site → book's Notebook page → Export
  Notebook). parseKindleHtml() walks the flat .bodyContainer div structure (.sectionHeading = chapter,
  .noteHeading + .noteText pairs = highlights/notes), pairing a Highlight with an immediately-following
  Note that shares the same Location into one record (quote + note); standalone highlights/notes import
  with the other field blank. parseKindleCitation() splits Kindle's own generated Chicago citation
  (consistently "Last, First, Last2, First2, ..., and LastN, FirstN. <i>Title</i>. Publisher, Year.")
  to get every author (not just the first) plus publisher/year — falls back to the plain .authors line
  if no citation is present. kindleMatchWorks() scores existing works by normalized title similarity
  (70%) + contributor last-name overlap (30%); the review screen (openKindleReview) shows the parsed
  citation, an "Add to" dropdown defaulting to the best match (or "Create a new work") which the user
  can override, and purpose chips to tag the whole batch. Choosing an existing work imports straight
  away; choosing "Create a new work" opens the normal work-editor modal pre-filled from the parsed
  citation (KINDLE_IMPORT flag makes saveWork() hand off to finishKindleImport() instead of its usual
  close/toast) so the user can fix author/editor roles (Kindle citations don't distinguish editors)
  before saving. finishKindleImport() dedupes against existing notes on that work by Kindle Location
  (safe to re-import an export after adding more highlights later), and files locators as
  chapter/page/kindle (not chapter_title/chapter_author, which are reserved for edited-volume
  chapter-citation formatting and would corrupt the footnote). Not captured: highlight color, and the
  standalone-"Note" case is implemented per Kindle's documented format but untested against a real
  file (the sample provided had highlights only).
- Post-v1.5 fix: iPhone virtual keyboard pushed the sticky pane-head toolbar off the top of the
  screen (worked fine on Mac and on iPad with a physical keyboard — the bug only shows when the
  on-screen keyboard actually opens). Cause: position:sticky/fixed elements are anchored to the
  layout viewport, but iOS shifts the *visual* viewport down under the keyboard without necessarily
  scrolling the document, so `window.visualViewport.offsetTop` goes nonzero and sticky elements end
  up positioned above what's actually visible. Fix: syncViewportOffset() tracks
  visualViewport's resize/scroll events (plus a few delayed re-checks on .rte focus/blur, since iOS's
  keyboard-open animation lags the event slightly) and writes the offset to a `--vv-offset` CSS var;
  `#appbar` and `.pane-head`'s sticky `top` both add it in. No-ops (0px) on devices that never pan the
  visual viewport, so it shouldn't affect the already-working Mac/iPad behavior.
- v1.6: **Scripture references.** New note field, alongside Locators in the editor ribbon: a
  "Scripture references" row with (a) cascading Testament → Book → Chapter selects plus verse-start/
  verse-end number inputs and an Add button, and (b) a free-text field ("or type directly, e.g. John
  3:16-21") parsed by the same engine. Multiple references per note, each removable via its chip's ×.
  BIBLE_BOOKS (in the state script block, near LOC_TYPES) is a 81-book table — 39 OT + 27 NT + 15
  Apocrypha (1–2 Esdras, Tobit, Judith, Additions to Esther [chapters numbered 10–16, continuing
  Esther's own numbering — Vulgate-style], Wisdom, Ecclesiasticus/Sirach, Baruch, Letter of Jeremiah,
  Prayer of Azariah, Susanna, Bel and the Dragon, Prayer of Manasseh, 1–2 Maccabees; KJV 1611 Apocrypha
  order/chapter counts per kingjamesbibleonline.org), shown as a separate section in the Testament
  dropdown per Shane's request. Each book carries common abbreviations (1Cor, I Cor., First
  Corinthians, etc. — normNumeralPrefix() folds roman-numeral/ordinal/word prefixes to a leading digit
  before matching) built into one big regex (BOOK_REGEX) used by both the free-text parser
  (parseScriptureRefText — also accepts a bare "Book Chapter" with no verse, since a manual entry is
  inherently deliberate) and the auto-detect scanner (detectScriptureRefs). Ranges: same-chapter
  (John 3:16-21), cross-chapter (John 3:16-4:2), and non-contiguous verse groups (Rom 8:1, 3, 5 → one
  chip covering all three, per Shane's answer) are all supported; verse-only whole-chapter refs
  (Genesis 1) are supported in manual entry only. Auto-detect (📖+ button, added to the existing
  rteBar() toolbar on both quote and note panes per Shane's answer) *only* matches explicit
  "Book chapter:verse" citations — it will never fire off a bare "Matthew 5" mention or infer an
  unmarked quotation, per Shane's explicit instruction ("not requiring the software to try to
  determine a scriptural quote and reference when the reference isn't explicit"); detected refs are
  merged into the note's existing list, skipping exact duplicates. Library gets a new "Scripture"
  text filter (parseScriptureQuery + refMatchesQuery) supporting book-only, book+chapter, and
  book+chapter:verse[-verse] queries, matched by range overlap against each note's stored refs (so a
  note tagged Romans 8:1-11 is found by a search for "Romans 8:5"); scripture refs also show as
  badges on library note cards and export to the CSV backup. **Requires a one-time migration** —
  existing installs must run `alter table notes add column scripture_refs jsonb default '[]';` in the
  Supabase SQL editor once before using this version (schema.sql updated for fresh installs).
- v1.7: Scripture reference refinements. (1) Chapter:verse separator now also accepts a bare period
  with no surrounding space ("Iob 21.23"), not just a colon — added as a second alternative
  (SCRIPTURE_SEP constant) alongside the existing `\s*:\s*` colon form, deliberately requiring zero
  space around the period so it can't misfire on an ordinary sentence-ending period followed by a
  sentence that happens to start with a number ("...chapter 1. 2 Samuel also..." does NOT match,
  verified in tests; "21.23" tight does). (2) BIBLE_BOOKS abbr lists gained Puritan/early-modern
  I-for-J spelling variants — Iob (Job), Iohn/Ioh (John, plus 1/2/3 Iohn), Iudges/Iudg (Judges),
  Iames/Iam (James), Iude (Jude), Ioel (Joel), Ionah/Ionas (Jonah), Ieremiah/Ierem/Ieremy (Jeremiah),
  Ioshua/Iosuah/Iosua (Joshua), Iudith (Apocrypha) — reflecting that I/J were the same letter in
  English typography through most of the 17th century, so period sources routinely print "Iob" for
  "Job" etc. (3) Settings → new "Scripture references" card → "📖 Update all scripture references"
  button: runs the same detectScriptureRefs() engine used by the editor's 📖+ button across every
  note in the library (quote_html + note_html), merges any newly-found references into each note
  (existing references, including manually-added or manually-edited ones, are never touched or
  removed), and upserts only the notes that actually changed. Meant to be rerun after a bulk import
  (Kindle, JSON) or whenever the detector itself gains new abbreviations/formats — exactly what v1.7's
  own period-separator and old-spelling additions are for, so it's worth a run after updating to v1.7
  if your library has older EEBO/Puritan-sourced quotes with period-style or old-spelling citations
  already sitting in their quote text.
- v1.8: fixes found against a real Puritan quote ("Rom. 5.1.6. and 2. Cor. 1.12. ... 2. Cor. 6.10.
  Act. 9.31.") that v1.7's period-separator support didn't fully cover. (1) The numeral-prefix pattern
  for two/three-author-number books (2 Corinthians, 1 Samuel, etc.) required the digit to be glued or
  space-separated from the book name/abbreviation ("2Cor"/"2 Cor") but not period-separated ("2.
  Cor.") — the standard early-modern form, since numerals were almost always followed by a period in
  this period's typesetting. BOOK_REGEX's digit-prefix transform now inserts `\s*\.?\s*` instead of
  just `\s*` after a leading digit. (2) Added the u/v typographical interchange common in
  early-modern English printing (v at word start was routinely set as u) as extra abbreviations: Prou
  (Proverbs), Leu (Leviticus), Reu/Reuelation (Revelation) — alongside the existing i/j convention
  from v1.7. (3) Added two abbreviations that turned out to be missing outright: Psal (Psalms — only
  Psa/Psalm/etc. existed, not the very common "Psal." form) and Act (Acts, singular, vs. only "Ac"
  before). (4) Verse-list continuation (the "one reference covering the group" non-contiguous-verses
  feature from v1.6) was comma-only; it now also accepts the tight period form, so "Rom. 5.1.6."
  parses as Romans 5:1, 6, same as "Rom 5:1, 6" already did — buildVerseGroup() was rewritten to
  regex-match each list piece instead of splitting on a fixed delimiter, so it handles either
  separator (or a mix) in one pass. All existing behavior (including the false-positive guards from
  v1.7, e.g. an ordinary sentence-ending period never triggers a match) reverified with zero
  regressions; the full real-quote example now yields all four references correctly: Romans 5:1, 6 /
  2 Corinthians 1:12 / 2 Corinthians 6:10 / Acts 9:31.
- v1.9: Auto-detect now also catches whole-chapter citations — "Romans 7." (a book, chapter number,
  and a trailing period with no verse digit immediately after — that case is still the v1.7/v1.8
  chapter:verse path). detectScriptureRefs() runs a second regex pass (same BOOK_REGEX, negative
  lookahead `\.(?!\d)` so it never fires where a period-form verse already matched, e.g. "Romans
  7.16" stays verse-level, not double-counted) and merges any new whole-chapter refs in, deduped
  against the first pass. A bare "Romans 7" with no punctuation at all is still ignored — the
  trailing period is what marks it as a citation rather than a book+chapter number appearing
  mid-sentence. Manual entry (dropdown with blank verse, or typing "Romans 7" in the free-text field)
  already supported whole-chapter refs since v1.6; this just extends the same shape
  (vStart/vEnd:null) to the auto-detect and bulk-updater paths, so they all agree.
  **Known, accepted tradeoff:** this reopens the exact ambiguity the v1.7 period-separator design
  went out of its way to avoid — "Genesis 1. The heavens were void." now reads as a citation to
  Genesis 1, because there's no way to distinguish a period-terminated chapter citation from an
  ordinary sentence-ending period without more context than a regex has. Shane asked for this
  explicitly, understanding the tradeoff; a wrongly-added reference is a one-click removal (the ×
  on its chip), not destructive.
- v1.10: per Shane's follow-up ("better a false positive than a dropped reference"), the trailing
  period requirement from v1.9 is gone — auto-detect now creates a whole-chapter reference for ANY
  "Book Chapter" not otherwise consumed by a chapter:verse match, including a completely bare "Romans
  7" with no punctuation at all ("Paul's argument in Romans 7 turns on the law" now tags Romans 7;
  same for "compare Numbers 6 and 7" → Numbers 6 and Numbers 7 both). This is a substantially more
  aggressive match — expect more false positives on ordinary prose that happens to put a small number
  after a book name (e.g. "I read Genesis 12 times") — which is the accepted tradeoff.
  **Bug fixed along the way:** the first version of this (v1.9) had a real bug, caught by testing
  before it shipped — for multi-digit chapters not already consumed by a verse match (e.g. scanning
  "Iob 21.23" — the whole-chapter regex's own negative lookahead correctly rejected "21" as a
  match, but the digit quantifier then *backtracked* to the shorter "2" and matched THAT instead,
  since a truncated "2" satisfied the same lookahead. Produced a bogus extra "Job 2" reference
  alongside the correct "Job 21:23". Fixed by adding a `(?!\d)` lookahead immediately after the
  chapter digits so the match can't be satisfied by a truncated prefix of a longer number — full
  regression suite (14 cases) and the real Puritan quote both reverified clean after the fix.
- v1.11: five smaller fixes/features from real-use feedback.
  1. Library search-term highlights (the hl() function, wraps matches in `<mark>`) now render green
     instead of the same yellow as manually-applied highlights in the editor — added a `.lib-hit`
     class + `--hl-search` CSS var, scoped so it doesn't affect `<mark>` tags that arrive via pasted
     content (sanitizePaste already converts a pasted `<mark>` into one; those stay yellow, unchanged).
  2. Diagnosed the broken "Theological Loci"/"Praxis Category" PhD fields from Shane's screenshot: a
     purpose field with `type:'select'` and an empty `options` array renders as a nearly-invisible,
     unusable `<select>` (one blank option, no explicit width — exactly the tiny floating-checkmark
     box in the screenshot). This is a *data* issue (those two fields are apparently configured as
     dropdowns with no options defined), fixable in Settings → the Purposes admin section → PhD →
     each field's type dropdown (switch to "text", or fill in the options box that appears next to a
     "dropdown" field). Shipped two robustness improvements regardless: the editor's select now gets
     an explicit width and a "no options set — fix in Settings" hint instead of silently rendering
     broken, and the Settings admin row now shows a red inline warning on any select field with zero
     options, so this is easy to spot next time instead of only visible as a mystery broken box in
     the editor.
  3. New library sort option, "sort: page number" (LIB.sort==='pagenum') — sorts purely by page
     number across the whole result set, no work-title tiebreak taking priority the way the existing
     "work + page" option does. Most useful filtered to a single work.
  4. New "New (same author)" button in the editor, to the left of "New" — starts a blank note but
     carries over the current note's work_id (and _authorSel, and purposes array — "same purpose
     category" per Shane's spec) from CUR; quote/note text, tags, locators, and purpose_values still
     reset to blank. Disabled (greyed, no-op) whenever CUR has no work_id, i.e. a blank editor with
     nothing selected — implemented as a template-conditional `disabled` attribute in renderEditor(),
     re-evaluated on every render.
  5. Fixed the Tx (remove formatting) button — `document.execCommand('removeFormat')` is a no-op with
     no active selection, so previously the button did nothing at all unless you'd first highlighted
     text. New clearFormatting(k) checks for a live, non-collapsed selection inside that pane (same
     check already used by the cleanup-button's PENDING_SEL capture) and only falls back to
     execCommand for that case; with nothing selected, it rebuilds the whole pane's HTML by walking
     it with fragText() (already used elsewhere for the cleanup system — preserves paragraph/line
     breaks) and re-wrapping with textToHtml(), which strips all inline formatting (bold/italic/
     underline/highlight/pasted `<mark>`) while keeping paragraph structure intact.

- v1.12 / v2.0-beta2: **data-corruption race in saveNote() — present since v1.0, found in the wild.**
  Symptom Shane hit: working down a filtered list on the iPad, editing each note and clicking
  straight to the next, one record vanished from the list and another appeared twice.
  Cause: `rec` and the server-side target id were captured synchronously (correctly), but the
  line that syncs the local cache ran AFTER the network await:
      Object.assign(DB.notes.find(n => n.id === CUR.id), rec);
  `CUR` is reassigned the instant another result card is clicked, so a save that was still in
  flight would find the *newly opened* note in DB.notes and stamp the *previous* note's content
  into it. Hence one apparently dropped, one apparently duplicated. The insert branch had the
  same flaw (`CUR.id = data.id` could brand the wrong note object). `flushSave()` compounded it
  by only awaiting a *pending* debounce timer, never a write already in flight — so clicking
  quickly sailed straight past it.
  Crucially this corrupted only the in-memory cache; the server row was always written correctly
  (verified: Shane's MacBook showed the record intact while the iPad showed the duplicate). It
  would only become permanent if the user then edited the mis-displayed note and saved, writing
  the wrong content over a real record.
  Fix: pin `const target=CUR` before any await and use `target`/`tid` exclusively afterwards;
  look the local row up by the pinned id; only clear `dirty`/save-state if `CUR===target`;
  serialize writes through SAVE_INFLIGHT and make flushSave() await it. Regression test drives
  the exact race against a stubbed slow network (60ms) and asserts all three notes keep their own
  content; the pre-fix logic reproduces the corruption on demand.
  Second bug found while investigating (v2 only): 18 call sites (filter chips, sort, collapse,
  clearLib, saved views…) triggered a full re-render without first calling syncPanes(), silently
  discarding whatever had been typed but not yet debounced. Fixed centrally in renderNotes() with
  an object-identity guard (PANE_OWNER===CUR) so typing survives a re-render, while a note switch
  still refuses to copy stale DOM text into the newly opened note.

- v1.13 / v2.0-beta3: five fixes from real use.
  1. Duplicate "Show details" control — when the details panel was collapsed, BOTH the facts strip
     and the vertical DETAILS strip offered to reopen it. Dropped the facts-strip button; the strip
     stays, mirroring the Results strip on the left.
  2. Bulleted and numbered lists in the quote/notes panes (execCommand insertUnordered/OrderedList),
     with CSS for ul/ol/li in .rte and .note-card. sanitizePaste() previously flattened every <li>
     into a <p>; it now preserves UL/OL/LI so pasted lists arrive as lists.
  3. Filters popover slammed shut the moment you picked an author, because every filter change calls
     renderNotes(), which rebuilds the popover markup and so discarded its `open` class. Open state
     now lives in a FILTERS_OPEN flag re-applied on render. Also made author→work cascade: the work
     dropdown lists only that author's works (it previously showed the entire library), and changing
     author clears a selected work that doesn't belong to them.
  4. Selecting a row scrolled the results list back to the top — renderNotesList() replaces the
     container's innerHTML, which resets scrollTop. Position is now captured before the rebuild and
     restored after, both on full renderNotes() and standalone list re-renders.
  5. "Sort: page number" mis-sorted records holding several locator types. Two causes: the old code
     took only the FIRST page locator, and it stripped non-digits from the whole value, so a range
     "193-195" became the number 193195. Now every page-type locator is scanned, all numbers within
     are extracted, and the lowest is used — so a range sorts at its low end, a record with two page
     locators sorts by its earliest, and chapter/kindle/EEBO locators are ignored entirely. Records
     with no page locator sort last. Fixed in both index.html and next.html.

- v2.0: **the UI rewrite was promoted.** next.html -> index.html; the old single-screen-per-mode UI
  is preserved as legacy-v1.13.html for rollback. Same origin, so sessions, connection values,
  saved filters and panel prefs all carry across the swap — no re-login, no re-setup.
- v2.1: **multi-select export.** Quote / Q+Note buttons now live in the results pane (left), acting on
  the ticked selection; Cite / Biblio stay in the details panel acting on the open note. The old
  Q+cite is gone — the new "Quote" does what it did (quote + citation), and "Q+Note" adds the user's
  note beneath. Checkboxes stay behind the existing ☑ select toggle (Shane's call — keeps the list
  clean for reading), with All / None appearing in select mode. Buttons show a live count, e.g.
  "Quote (12)". With nothing ticked they fall back to the currently open note, so a one-off copy
  doesn't force you into select mode.
  Export details: entries follow the list's current sort order (so page-number sort exports in page
  order); blank line between entries; a record with no note still leaves its blank line in Q+Note
  (rich version emits <p><br></p>); and repeat citations from the same work use **Chicago short form**
  after the first — shortCiteObj()/shortTitle() produce "Owen and Kapic, Overcoming Sin and
  Temptation, 204." (subtitle after ':' dropped, titles over four words trimmed with a leading
  article removed, two authors joined by "and", three or more as "et al."). Short-form tracking is
  per-export, not global. A surrogate source anywhere in the batch appends a cite-the-original
  warning to the copied-count toast.

- v2.2: six items from use in the field.
  1. Long work titles (Rogers) swallowed the results pane — .groupbar now clamps to two lines.
  2. Tag filtering gave no indication WHICH tags were active. Two causes: the popover's Tags summary
     showed only a count, and the chip list was pinned-tags + top-10-by-frequency, so a tag outside
     that set filtered invisibly with nothing on screen naming it. Active tags are now prepended to
     the chip list unconditionally and spelled out in the summary line.
  3. The ☑ toggle read as a filter. Relabelled "☑ Select" / "Done selecting", and the bulk bar now
     opens with a "Bulk edit — N ticked — changes below apply to all of them" caption.
  4. Highlight is one toggle instead of an apply/remove pair. selectionIsHighlighted() walks up from
     the selection to the .rte boundary looking for a MARK or a non-transparent inline background,
     so it handles both execCommand's spans and <mark> arriving via paste.
  5. **New work/author not appearing until a manual reload.** saveWork() ended with renderEditor(),
     which only re-renders the notes view — so adding a work while standing on the Works or Authors
     tab left that tab stale. Added activeView()/refreshActiveView(); saveWork and savePerson now
     re-render whichever view is actually on screen.
  5b. "+ New work" had effectively vanished from the note editor: the v2 rewrite moved it inside the
     Citation block's collapsed ✎ editor. It now has a "+" in that block's header, matching the
     pattern already used by Locators / Scripture / Tags.
  OUTSTANDING: Shane also reported an author that was absent from the Authors page even after a hard
  reload — i.e. missing server-side, not just stale. The happy path (+ New work -> look up online ->
  save) was reproduced in the harness and correctly writes people + works + work_contributors, so
  the trigger is something else in his sequence. Needs a direct SQL check against auth-visible rows
  to tell "never inserted" from "inserted but not displayed" before guessing further.

- v2.3: **the "missing author" was a name-inversion bug, not a lost write.** Resolved the item left
  outstanding in v2.2. The row existed in Supabase all along:
      name "Dixon, Thomas"   sort_name "Thomas, Dixon,"
  ensurePerson() assumed every name arrives "First Last" and derived sort_name by moving the last
  whitespace-token to the front. Given a name already in "Last, First" form — which is what an
  online lookup or a pasted citation often yields — that produces "Thomas, Dixon,". Since the
  Authors list sorts on sort_name, the author filed under T instead of D and looked absent.
  Added normalizePersonName(): if the raw string contains a comma it is read as "Last, First"
  (name -> "Thomas Dixon", sort_name -> "Dixon, Thomas"); otherwise the old last-token rule applies.
  Used by both ensurePerson() and savePerson()'s auto-fill, and ensurePerson now matches candidates
  against BOTH stored forms so an inverted spelling reuses the existing person instead of creating a
  near-duplicate. Existing bad rows need a one-off correction (Dixon; see below).

- v2.4: **works saved with no author at all — typed text was never committed.** Diagnosed from two
  orphaned works in Shane's data (Fenner's *Treatise of the Affections*; an Owen webpage), each with
  zero work_contributors while the matching person existed separately, created minutes apart.
  Cause: the work modal's author/editor/translator boxes only push a chip into MW._authors on Enter
  (or on clicking an autocomplete suggestion). Clicking "Save work" straight after typing discarded
  the text silently, so the work saved with no contributor — and because no chip appeared, the user
  reasonably concluded the author "wasn't in the list" and created it separately, producing exactly
  the orphan-person + orphan-work pair observed. Same class as the v1.1 locator Enter-required bug,
  whose save-on-blur guard the v2 rewrite dropped.
  Fix: commitPendingRoles() runs at the top of saveWork() so pending text is always captured, plus
  commitRolesOnBlur() (150ms deferred) so the chip appears as you tab away. The blur path is guarded
  against re-rendering — and thus re-opening — a modal that Save has already closed, and is
  idempotent so the Enter path can't double-add. Restored/added the same save-on-blur to the note
  editor's locator value, tag input and scripture free-text box; the scripture one only commits if
  the text actually parses, so a half-typed reference isn't nagged about.
  DATA CLEANUP still required for the pre-existing bad rows (see v2.3 note re Dixon/Flavel, plus the
  two orphaned works needing their authors re-linked, and the unused "W. Perkins" duplicate).

- v2.5: **Library health + author merge** (Settings → Library health).
  Scope deliberately narrow, per Shane: only states that produce wrong output or hide a record.
  A work with no notes is a legitimate PhD-bibliography entry, and an author he has not sourced yet
  is equally normal — neither is flagged, because a flag you learn to ignore is worthless. What IS
  flagged: (a) works with no contributor at all, which cannot form a citation and are what the v2.4
  commit bug produced; (b) malformed sort names, detected by trailing comma, sort_name identical to a
  multi-word name, or a surname that doesn't occur in the name — the states that filed Dixon under T
  and Flavel under J; (c) probable duplicate authors, grouped by surname; (d) probable duplicate
  works, grouped by normalized title. Verified that particle surnames (Van Engen) and family-name-
  last names (Sam Hyeong Rae Jo) are NOT false-flagged.
  Each fault has an inline action: open the work to add an author, one-click sort-name repair, or
  open the person to merge. mergePeople() moves every work_contributors row to the surviving record,
  deleting rather than duplicating a row where both people already contribute to the same work in
  the same role, then carries over any biographical field (dates/notes/urls) that is blank on the
  survivor before deleting the merged record — so a merge never silently loses data. The merge
  control lives in the person modal (Authors → open an author → "merge this author into…").

- v2.6 (2026-10-16, built in Claude Code rather than Cowork): requirements doc "Version 2.6".
  REQUIRES A ONE-TIME DB MIGRATION (people name parts) — see schema.sql header. The app runs
  without it (HAS_NAME_COLS=false: old name/sort-name fields, warning in Settings → Library health).
  1. Scripture: Roman-numeral chapters ("1 Thes. v. 16, 17", "Rom. viii. 28", "Psal. cxix.") via
     arabicizeRomanChapters() before detection; guards: capitalised book token, never a lone "I",
     numeral must be a valid chapter of that book, skip "i. e.". Two older bugs fixed alongside:
     normNumeralPrefix() turned I/II/III into digits before ANY word ("i. e." -> "1 e" -> Isaiah 1),
     now only before numbered books; and a verse list swallowed the number starting the next
     reference ("1 Cor. 13:4, 2 Sam. 12:7" -> 1 Cor 13:2, 4 and Samuel lost) — notBook lookahead.
  2. Work types: pub.type book|article|web. Articles: journal/volume/issue/pages/doi; webpages:
     site/accessed + first URL. Chicago note/bib/short and MLA for each. Custom-style tokens added.
  3. Lookup rewritten: Crossref (query.bibliographic — matches a whole pasted citation) + Open
     Library (with "Choose edition" -> /works/X/editions.json) + Google Books; failed sources are
     named. Parse = local split (new article pattern) + Crossref matches. DOI anywhere -> Crossref
     record. From URL reads citation_* meta incl. all authors and journal fields.
  4. Citations: chapter LOCATORS no longer appear in citations (citeLocs). The existing note-level
     chapter_title/chapter_author is surfaced as "Cited part title" (Citation section) — renders
     Chicago "Author, “Part,” in Work (…), 372." Bib/MLA fall back to the volume's authors when no
     part author. Short form quotes the part title; export treats each part as its own source.
     "Cite as part title" button converts an old chapter locator. shortTitle() no longer ends on a
     function word ("Discourse of Delight"). Short forms use the real surname (lastName()).
  5. People: first_name/middle_name/last_name columns; name + sort_name are DERIVED on save
     (composeName) so all existing code keeps working. splitName() handles "Last, First",
     particles (Van Engen), Jr., single names. Work modal shows editable First/Middle/Last for any
     new person before save; Crossref authors arrive pre-split. Person modal edits parts with a live
     "cited as / filed under" preview. Library health: "Review & split" backfills existing people
     (every proposal editable before save).
  6. Details panel: order Citation, Tags, Locators, Scripture, Purpose; every section collapsible
     (UI.open, persisted). Collapsed Purpose shows only filled fields. +/✎ opens, scrolls into
     view, focuses the input. renderDetPanel() re-renders just the panel.
  7. Autocomplete: no list on bare focus (the "Acceptable" bug); prefix matches first; picking a
     suggestion commits it; closeAllAC() on every modal/view re-render (the orphaned author list
     after saving a work); boxes follow panel scroll. Work modal restores focus after re-render.
  8. Search terms highlighted in the quote/notes panes via CSS Custom Highlight API (no DOM change,
     so nothing is saved into the note).
  9. Cleanup rules: a typed space matches any space-like char (nbsp, thin, narrow nbsp…), ";" also
     matches U+037E; formatting-preserving mode edits text nodes only; toast reports the number of
     replacements (or "No matches"); rule dialog shows a live match count and plain-English option
     help; line-break mode auto-selected when \n/\t are used.
  10. Panel toggles: "☰ Results" / "Details ☰" buttons in the toolbar; "‹ Hide" / "Hide ›" labels.
  Also fixed: saving any existing work while a note was open reassigned that note to the work (and
  never saved it). Now only a NEW work created from the note editor attaches, and it's saved.
  Tested against an in-memory fake Supabase (harness) incl. the pre-migration path; live Crossref
  and Open Library calls verified. iPhone layout deliberately deferred to its own effort.

- v2.6.1 (2026-10-16): five items reported after v2.6 went live. No DB migration.
  1. "al, et" author: "et al." had been saved as a person. isNotAName() now rejects it at every
     entry point (typed chip, commit-on-blur/save, lookup/parse authors, Kindle import). Library
     health lists any existing one under "Not a person" with Remove (drops its work links, then the
     record; real co-authors untouched). Person modal now lists that person's works with Open.
  2. Duplicate-author/work flags can be dismissed: "Not duplicates" stores the exact group key in
     settings.health_ignore (a new member makes it a new group, shown again).
  3. Work type "Thesis / dissertation" (pub.degree, pub.institution, year). Chicago: Author,
     "Title" (PhD diss., Inst, Year), pp.; bib/MLA/short forms; degreeLabel() maps PhD -> "PhD
     diss.", ThM/MA -> "… thesis". Parse recognises the Chicago dissertation form. Crossref
     dissertations included (date from "approved"; institution isn't a valid search select, so it's
     fetched from /works/{doi} for thesis hits). matchExistingPerson() reuses a library author when
     a lookup gives a shortened name ("Hyeong Rae Jo" -> existing "Sam Hyeong Rae Jo").
  4. Clicking the backdrop no longer discards an edited work/person dialog: snapModal() snapshots
     on open; backdropClose() confirms if anything changed. Explicit Cancel still closes.
  5. Results pane ballooning (seen filtered to a Charnock volume): a flex item's min-width:auto is
     its longest unbreakable word, so a long URL in a note preview widened .listcol (330 -> 580px in
     the harness) and pushed Details off-screen. .listcol min/max-width + overflow-wrap:anywhere on
     previews, group bars, citation and panes.

- v2.7 (2026-10-30): four items. No DB migration.
  1. Paragraph indent: ⇥ / ⇤ toolbar buttons and Tab / Shift+Tab in both panes (execCommand
     indent/outdent -> <blockquote>, styled as a 2em left indent). Paste keeps source indents:
     <blockquote>, or a P/DIV with margin/padding-left >= ~20px.
  2. Pasted footnotes renumbering from 1: sanitizePaste turned <ol start="4"> into a bare <ol>.
     Numbered lists now paste as plain paragraphs carrying their original numbers (start and
     li value respected). The 1.≡ button still makes real numbered lists. Already-saved notes
     can't recover lost numbers.
  3. 🧹 cleanup. (a) iPad: tapping the button cleared the selection before its mousedown fired.
     Selection is now tracked on selectionchange (LAST_SEL) and captured on pointerdown, stored as
     text offsets, and rebuilt + verified (same text) when an option runs. Modal opens on click,
     not mousedown. (b) Whole pane: "Join broken lines" only joined within a paragraph, but
     PDF/web pastes often make every line a paragraph, so a whole-note run changed nothing. It now
     joins paragraphs ending mid-sentence (lower-case/comma/semicolon/hyphen), removing a hyphen
     at the break. (c) Toast reports "Nothing to clean here" when the pane didn't change, instead
     of "Cleaned".
  4. Page sort: key is [start, end], so "109" sorts before "109-110"; abbreviated range ends are
     expanded ("109-10" = 109–110).
