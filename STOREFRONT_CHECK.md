# Storefront Check

A per-release, per-app checklist for verifying what the App Store actually
shows — because the live storefront, not the source doc, is what users see.
Run it every release, after any metadata paste into App Store Connect, and
after any price or IAP change. Record the snapshot (section 9) so the next
check can tell what changed.

## 0. Sources: what each one can and cannot show

- **iTunes Lookup API (public, no sign-in).** Per storefront: live version
  and release date, title, description, price (app price only, not IAP),
  seller, genre, age rating, minimum OS, declared languages, ratings
  (count + average), screenshot counts, release notes. Command template
  (replace the ID and country):
  `curl -s "https://itunes.apple.com/lookup?id=<APPLE_ID>&country=US"`
- **App Store Connect only (the API never shows these).** Subtitle,
  keywords, IAP prices, privacy nutrition label details, screenshot
  content (the API gives counts, not a visual check), territory
  availability, phased-release percentage.
- **RevenueCat dashboard only.** Whether each offering / entitlement
  actually exists, whether it is one-time or a subscription, intro
  offers and trials.
- **Reference for what the app SHOULD say.** The app's own source of
  truth (e.g. its `App_INFO.md` or store-copy doc) at a recorded commit,
  plus the app itself. Never compare live copy against an uncommitted
  draft, and never assume a paste happened — verify it landed.

## 1. Storefront set

Check every storefront that matters for the app, not just US:

- US, GB, CA, AU for English-language apps.
- Every locale the app localizes metadata into (e.g. CN, JP).
- Every territory where the app has meaningful ratings or sales, even
  if it shares a language with another territory — localizations do
  not automatically carry over to related territories.
- Note the fallback: the other ~170 territories show the English copy.
  A storefront showing English is only a problem if a localization was
  supposed to exist there.

## 2. Prices

- **App price, per storefront.** Free apps must show Free everywhere.
  Paid apps: the tier must be the intended one in every storefront, not
  just US.
- **Any price that breaks the pattern is the flag.** Compare
  storefronts against each other, not against a single reference:
  a price that looks weird next to the other storefronts, or
  different from what the app itself says, is the anomaly — whichever
  storefront it is in. This includes a free app showing a price in
  one storefront while Free everywhere else, and tier conversions
  that produce odd local values.
- **IAP prices, per storefront, in App Store Connect.** Every product:
  price and currency in each storefront, not just US. Watch for a
  product priced in one storefront and missing or mis-tiered in another.
- **Price vs. copy.** The price on the paywall, in the description, in
  promo text, and in screenshots must all match the live IAP price.
  A sale price (e.g. a holiday discount) must have the right start and
  end dates, and an expired sale price must not still be showing.
- **Territory availability.** An app or IAP that is unavailable in a
  territory where its metadata exists is a silent revenue hole.

## 3. App info accuracy: live copy vs. source doc vs. app reality

- **Title, subtitle, keywords.** Live title vs. source doc — a
  difference is an ASO decision, not just a paste delay; note it as
  one. Subtitle and keywords are ASC-only: verify them there, since
  the Lookup API never returns them.
- **Promo text.** At most 170 characters, current for this version,
  and consistent with the description. It is changeable without a new
  build, so it goes stale easily — check it every release.
- **Description claims audit.** Read every feature claim in the live
  description and check it against the app itself:
  - Visuals / illustrations: does the app actually have them?
  - Example sentences vs. example words: the two are different claims.
  - Audio: recorded / native audio vs. text-to-speech — say which.
  - Learning claims: spaced repetition, scheduling, difficulty levels,
    "constantly expanding library" — only if the app really does it.
  - Statistics and percentages: only with a source; drop unsourced
    numbers rather than shipping them.
  - Testimonials and quotes: real, and still accurate.
  - Terminology: the same product terms in the title and the body
    (e.g. a title using one product term while its description opens
    with a different, retired term).
- **What's New / release notes.** Current for this version, localized
  wherever the description is localized, and not months stale.
- **Category, seller, declared languages, minimum OS.** Identical and
  correct across storefronts; declared languages must match the
  localizations that actually exist.

## 4. IAP accuracy

- **Product names and descriptions** in Connect match the paywall copy
  the user sees.
- **Lifetime wording.** "Permanently", "one-time", "forever" may only
  appear if the entitlement really is a one-time purchase. If there is
  no subscription offering, the copy must not imply one exists, and
  Connect must not contain a stray subscription product.
- **Entitlement mapping.** The product the paywall sells must grant
  the entitlement the app checks (verify in RevenueCat, not just in
  the app's code).
- **Free vs. Pro feature list.** Every feature the copy says is Pro
  must actually be gated, and every feature it says is free must
  actually be free — including in the free build's ads behavior.

## 5. Screenshots and previews

- **Current UI.** Screenshots must show the shipped version's UI, not
  a previous release's (check the live version date, not just the
  images). Old tile colors, old tab names, and removed screens are
  the usual giveaway.
- **Counts per device per storefront.** iPhone and iPad counts must
  be consistent across storefronts; a storefront with extra or missing
  shots (e.g. 6 iPad shots in one storefront vs. 4 everywhere else)
  means something was pasted unevenly — reconcile it in Connect.
- **Order tells the story.** First shot = the main benefit; the set
  must walk through the flagship feature, a second feature, proof of
  progress, and a differentiator (see `Skills/SCREENSHOTS.md`).
- **Captions match the shots.** Every tagline must describe what its
  shot actually shows, in every locale. Hero and quote lines are the
  only lines that carry over unchanged between sets.
- **No stale content inside shots.** No placeholder text, no demo
  data in the wrong locale, no prices or feature claims the current
  build contradicts.
- **App previews (video), if any.** Same currency check as
  screenshots — video goes stale just as fast.

## 6. Privacy, age rating, links

- **Privacy nutrition label vs. reality.** The label must reflect
  every SDK that collects data (ads, purchases, analytics). An app
  shipping an ads SDK and a purchase SDK cannot carry a
  "Data Not Collected" label. Verify in Connect; the API does not
  expose it.
- **Privacy policy and support URLs.** Both live, correct, and
  matching the app's actual practices — no 404s, no staging links,
  no policy written for a different app.
- **Age rating vs. content.** Re-check the rating questionnaire
  whenever features change. Note the awkward cases even when they are
  not violations: a 4+ app serving interstitial ads to a young
  audience, for example, deserves a deliberate Pro-messaging decision.

## 7. Localization coverage

- **Complete or explicitly partial.** For every locale with translated
  metadata, the title, description, release notes, and screenshots
  should all be translated. A locale with a translated title but an
  English description (or vice versa) is a half-finished job.

- **Terminology and register, per locale.** The same standardized
  terms everywhere (not a retired term surviving in one locale), and
  the register the audience expects (e.g. informal vs. formal
  address where the app strings already made that call).
- **Screenshot locale.** Captions and any in-shot text must be in
  the storefront's language, with demo data (names, dates, currency)
  that fits that locale.

## 8. Ratings, reviews, version hygiene

- **Ratings per storefront.** Record count and average per
  storefront, not just US. Zero ratings in a storefront is a
  discovery problem, not a copy problem — but it is still a finding.
- **Do not quote sums as US figures.** A cross-storefront total is
  not the US count; keep the two separate in every report.
- **Recent reviews.** Read the newest reviews per storefront for
  bug signals that only appear there: price complaints, "charged but
  no Pro", locale-specific breakage. Note whether they have replies.
- **Version and release date identical across storefronts.** A
  storefront lagging on an old version means propagation trouble or
  a territory hold, not a copy issue.
- **Phased release.** If a release is phased, record the rollout
  percentage; a storefront check mid-rollout will otherwise look
  like a stale storefront.

## 9. Snapshot template

Record this at the top of every check so the next one can diff it:

- App, Apple ID, date/time of the check, data source.
- Reference doc and commit for what the app SHOULD say.
- Live version + release date, per storefront.
- Per storefront: title, description language + length, screenshot
  counts (iPhone / iPad), ratings (count + average), price.
- Problems found, prioritized (P1 = false claim or broken purchase,
  P2 = stale / incomplete / inconsistent, P3 = polish).
- Items the public API cannot show, listed as unchecked (keywords,
  subtitle, IAP prices, privacy details, screenshot content) with
  where to verify them.

## 10. Real catches this checklist is built from

- A live description claiming "engaging visuals" for an app with no
  illustrations, in all three localized descriptions.
- A Japanese description claiming example sentences for an app with
  example words only.
- A title and description contradicting each other on the product's
  own name (retired term in the body, current term in the title).
- Screenshot counts differing by storefront (6 iPad shots in one
  storefront, 4 everywhere else) from an uneven paste.
- Zero ratings in 6 of 9 checked storefronts while the repo's ASO
  notes quoted the cross-storefront sum as if it were the US count.
- A free app's price in one storefront showing a non-zero value
  while Free everywhere else.
- Storefronts showing full English copy for an app with translated
  copy available for a closely related locale.
