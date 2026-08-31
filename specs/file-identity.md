# Document UUID Injection

Source: `docs/blueprint-v2.md` §1.1, §1.3. Build order: `docs/build-plan.md` Stage 2.
Architecture: DECISIONS.md A4 (locked).

## Intent

Every document gets a stable v4 UUID injected into its YAML frontmatter on first
load or save, so renames don't break links and every document has a permanent
identity independent of its file path.

## Scores

Per `build-plan.md` §4.1 (Value × Verifiability ÷ (Blast radius × Dependency depth)).

| Axis | Score | Justification |
|---|---|---|
| Value | 4 | Foundation for wiki-links and citations; no daily friction reduction until they exist. |
| Verifiability | 5 | Pure `String -> String`. Golden fixtures fully determine correctness — T1 under §4.3. |
| Blast radius | 3 | Only ever adds content; never deletes, never rewrites existing lines. Wrong UUID format is immediately visible. |
| Dependency depth | 1 | Nothing must exist first. |

**Priority = 4 × 5 ÷ (3 × 1) = 6.67.** Blast radius < 4 ⇒ no rollback plan required.

## Acceptance criteria

Each is independently testable.

1. **Missing ID gets one injected.** A document with frontmatter but no `id` key
   receives `id: <UUIDv4>` inserted into the frontmatter block.
2. **No frontmatter at all.** A document with no `---`…`---` block at the top
   gets one created containing `id: <UUIDv4>` and any existing first-line content
   is preserved below it.
3. **Existing ID is left untouched.** A document that already has a valid
   `id: <UUID>` in its frontmatter is returned byte-identical.
4. **Idempotence.** `injectID(injectID(doc)) == injectID(doc)` — running twice
   produces the same output as running once.
5. **Non-UUID left alone.** A document with `id: some-human-readable-slug` is NOT
   overwritten — the existing value is preserved. Only a missing `id` key
   triggers injection.
6. **UUID format.** Generated IDs are RFC 9562 UUIDv4, lowercase hex, stored as
   `id: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx`.
7. **Determinism of the transform itself.** `injectID` is a pure function of its
   input — same document, same UUID call omitted only if `id` already present.
   (Note: UUID generation is random by definition; this criterion means the
   *decision* to inject is deterministic, and once injected, repeated calls
   return the same output — criterion 4.)
8. **Rest of frontmatter preserved.** Keys other than `id` are left exactly as
   written — no reformatting, no reordering, no whitespace changes.

## Out of scope

- **Block-level UUIDs** — need an AST (swift-markdown, RED-parked at PARKED.md).
- **Wiki-link resolution** (`[[...]]` → UUID → path) — needs the link index
  (separate task, same stage).
- **Any UI integration** — no paste hook, no save hook, no menu item. This is
  the pure transform only.
- **YAML parsing library** — the existing key:value line split in
  ExporterCore.swift (lines 50–75) is the pattern. No new dependency.
- **UUID regeneration** — once assigned, a UUID is permanent. No mechanism to
  change or remove it.

## Test plan

- **Unit / golden fixtures:** a corpus at `Tests/Fixtures/uuid-injection/` with
  input/expected pairs covering all acceptance criteria:
  - `no-frontmatter.md` → frontmatter block created with `id`
  - `frontmatter-no-id.md` → `id` injected into existing frontmatter
  - `has-uuid.md` → byte-identical output
  - `has-non-uuid-id.md` → byte-identical output (criterion 5)
  - `frontmatter-with-other-keys.md` → other keys preserved, `id` added
  - `empty-file.md` → frontmatter block with `id` only
  - `no-frontmatter-leading-content.md` → frontmatter prepended, content preserved
- **Idempotence:** every fixture run through `injectID` twice, output compared.
- **Determinism:** script asserts that `injectID` injects exactly once per fixture
  and repeated calls are identity.
- **Validator rules:** `scripts/validate.sh` extended to check UUID format
  (lowercase hex, correct version/variant nibbles) and that every golden document
  either has a valid `id` or is annotated as intentionally ID-free.

## Failure modes

1. **Double injection.** A document grows two `id:` lines because the first
   wasn't detected. Obvious on inspection but corrupts the YAML.
2. **Overwriting a deliberate slug.** The author wrote `id: project-x-design`
   and the injector replaces it with a UUID. Criterion 5 prevents this.
3. **Damaging the frontmatter fence.** Injection inserts `id: ...` outside the
   `---`…`---` block, breaking the YAML parse.
4. **Reformatting everything.** The injector decides to "clean up" frontmatter
   whitespace or reorder keys. A writer's carefully formatted frontmatter is
   scrambled.
5. **UUID collision** — vanishingly unlikely for v4 but testable: a fixture
   corpus of 10,000 generated UUIDs with no duplicates.

## Named entities

- `DocumentIdentity` — the namespace. Entry point
  `DocumentIdentity.injectID(_ raw: String) -> String`.
- Location: `Sources/Core/DocumentIdentity/`. Tests: `Tests/KitibTests/DocumentIdentity/`.
- Uses `Foundation.UUID` — no new dependency.
