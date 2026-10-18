# Design Token Rules（完整版）

> 从 `CLAUDE.md` 迁出的完整版，含规则 4/5 的理由与遗留债务数字（2026-08-27 快照）。`CLAUDE.md` 的「Design Token Rules」只保留结论。


1. Name tokens by PURPOSE, not appearance, using a consistent format
   `category-purpose-level` (e.g. color-text-primary, space-padding-card).
   Never use arbitrary names like color1, myGray, bg2.

2. Reuse before creating. Before introducing a value, check existing tokens
   and reuse if one fits. Never define the same value under multiple names.

3. Define ALL tokens centrally in one theme/tokens file — never inline in
   components or pages. Use two layers: primitive (raw values) and semantic
   (purpose-named, referencing primitives). Components reference only the
   semantic layer. This lets you re-skin by editing primitives and fine-tune
   by editing semantics.

4. **Semantic tokens must reference a primitive — with one narrow exception.**

   A semantic token may hold a raw value directly *only* when the value is
   **component-private**: it serves exactly one component, is not reusable, and
   does not sit on a design scale.

   The test: **"would this value still mean anything on a different component?"**
   - Yes → it belongs in the primitive layer (e.g. `20` page margin: Tab1, Tab2
     and Onboarding all want the same one).
   - No → keep it in the semantic layer (e.g. `progressBarHeight = 2.5`,
     `settingsIconStroke = 1.6`, `emptyStateCardBackRotation = -7` — these were
     tuned for one control and mean nothing anywhere else).

   Why the exception exists: the primitive layer is a **scale** — a clean ruler
   you pick from (4/8/12/16/20/24…, and the primary colour ramp). Promoting
   one-off internal metrics into it turns that ruler into a junk drawer: someone
   choosing a spacing would see `2.5` sitting next to `20` with no way to tell
   which is a real design step. Polluting the scale is worse than leaving the
   value where it is used.

   This is an exception, not a licence. Anything reusable — spacing, radii,
   brand colours, type sizes — still goes through a primitive. When unsure,
   promote it.

   **"Reusable" means consumed by two *independent* components or two distinct
   semantic purposes** — not merely appearing twice. The same value used twice
   inside one component is still component-private; the same value shared by
   Tab1 and Onboarding is not.

5. **The primitive layer is a palette, not a to-do list.** Unconsumed steps in a
   ramp (e.g. `primary300`–`primary900` currently having no consumer) are
   normal and must NOT be deleted: a scale has to stay contiguous so the
   semantic layer can pick from it, and removing a middle step leaves a
   `700 → 900` gap that is harder to maintain than an idle value.

   The "delete tokens nobody references" rule applies to the **semantic layer
   only** — there, one token is one live design decision, so no consumer means
   the decision was retired. Delete those.

   **Scope and legacy debt.** As of 2026-08-27 roughly 16 of ~213 semantic
   tokens have no consumer (`accentBuddy`, `growthStatus`, `keyPhrase`,
   several `onboarding*Glyph`, …). They are **pre-existing debt, not a licence
   to add more**, and they are not a blocker for unrelated work:

   - Applies to tokens **your slice orphaned** — if you removed the last
     consumer, remove the token in the same commit. That is the rule.
   - Pre-existing orphans get cleaned up during token-hygiene passes
     (see Working Method), not opportunistically mid-feature.
   - How to check: grep for `AppTheme.<Namespace>.<name>` across
     `AIEnglishApp/`. Beware false positives — tokens reached through
     aliases or factory functions (e.g. `AppTheme.Font.categoryLabel(isHot:)`)
     will not show up as a direct reference. **Confirm by reading before
     deleting**; a naive grep is a starting point, not a verdict.
