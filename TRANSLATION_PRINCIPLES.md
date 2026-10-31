# Translation Principles

How Grace Apps localizations are done — in the app strings, the Watch and
widget targets, and the App Store copy. These principles come from Le's own
statements and corrections across the StitchTally, ReadingClock, and
FastingLady localization work (synthesized 2026-10-31). They are the standard
every translation or review pass is judged against, whoever (or whatever)
does the translating.

The one-line version: **accurate, authentic, and understandable local
translation — never word-for-word.**

## The principles

1. **Meaning over wording.** A translation is correct when a local reader
   gets the same meaning, not when it mirrors the English sentence. If the
   literal rendering and the natural rendering disagree, the natural one
   wins.
2. **Rewrite freely for smoothness.** Restructure sentences, split long
   ones, and remove translated-sounding constructions until the text reads
   as if it were written in that language first. Long paragraphs get the
   most rewriting; labels get the least.
3. **Never lose content.** Smoothness by omission is not allowed. Dropped
   explanations, details, list items, or reasoning are defects, on par with
   mistranslations. (FastingLady ES pass, 2026-10-31: the Spanish had
   quietly dropped the rising-progesterone explanations, the "less
   motivated" symptom, and the "…para la menstruación" ending — all
   restored.)
4. **The founder's voice survives.** First person, warmth, and the humility
   lines ("It may not be perfect yet, but I'll keep improving it") are
   content, not decoration. Flattening them into impersonal copy is a
   translation error. (FastingLady ES Watch release note had lost both
   lines; restored.)
5. **Use the words locals actually use.** The test for a term — above all
   for UI labels — is whether a local user instantly understands it, not
   whether it is the literal equivalent. English "Dashboard" is fine
   because English speakers own that word for software; Chinese 仪表盘
   still means a car's instrument cluster, so the Chinese tab is 数据 and
   prose references are 数据页. Spanish "Panel" is natural and stays.
6. **Align with established local references.** Where the culture already
   has the term, use theirs: the local edition of a cited book (the Spanish
   *Fast Like a Girl* — *Ayunar para sanar* — calls the phases Fase de
   Poder / Manifestación / Cuidado, and the app matches), the platform's
   own local vocabulary (Apple Health's terms, e.g. 月经流量 for menstrual
   flow), and real local book titles rather than translated ones. Research
   citations and author names stay in their original language.
7. **Direct, informal register.** Address the user like a person:
   Simplified Chinese uses 你, never 您; Spanish uses tú, never usted, in a
   single neutral pan-Hispanic voice (no vosotros forms, es-ES and es-MX
   store metadata identical).
8. **One term, everywhere.** Phases, plans, units, and feature names are
   translated identically in the app, the Watch app, the widgets, and the
   store copy — no drift between catalogs. When one string is fixed, every
   catalog that shares it is fixed, and the set is re-scanned for
   divergence.
9. **Mechanics are non-negotiable.** Format placeholders (`%@`, `%lld`,
   positional `%1$@`, …) survive verbatim in every string; each pass
   mechanically scans the full set against the source before delivery. The
   only allowed exception is a placeholder the target language genuinely
   has no form for (e.g. English plural-suffix slots in Chinese), and that
   exception is documented in the commit. App Store character limits are
   respected by tightening wording, never by cutting content the source
   carries.

## Reviewing a translation

A review pass reads every string against these principles and reports in
three buckets: **errors** (wrong meaning, broken placeholders, over-limit
metadata), **authenticity** (calques, literal label choices, register
slips, divergence between catalogs), and **judgment calls** (left for Le).
Long-form strings — daily guidance, FAQs, the founder story, release
notes — are read as prose, not sampled: smoothness and completeness are
only visible at paragraph length.
