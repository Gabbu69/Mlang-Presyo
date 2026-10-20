# Project instructions - PresyoGo

## Mission and scope

Build a real Flutter Android application for private shopping lists, dated local price records, and grocery spending. Read `PRODUCT_SPEC.md`, `PLANS.md`, and `ACCEPTANCE_TESTS.md` before implementing features.

Version 1 is local-only and offline-capable. Version 2 community features are a roadmap, NOT authorized implementation scope. Do not add authentication, a backend, AI features, advertising, analytics, payments, maps, scraping, or public posting in Version 1. Do not create a web-only mockup as a substitute for the Android app.

## Working method

Inspect existing files, applicable instructions, Git state, dependencies, and installed tools before edits. Preserve user changes. Do not reinitialize or overwrite an existing project. If `flutter create` is needed, avoid replacing these planning files.

Use the current repository as the source of truth. Select mutually compatible stable dependencies after checking the installed Flutter/Dart SDK. Record versions, commit `pubspec.lock` for the app, and avoid unrelated upgrades. Prefer Flutter/Dart, Drift/SQLite, Riverpod without optional generator complexity, and simple navigation. Add a package only for a real requirement.

Implement one milestone at a time. Keep the app runnable after each milestone. Prefer a thin complete feature over many unfinished screens. Do not add unused abstractions or future cloud scaffolding. Record assumptions in `docs/DECISIONS.md`; maintain actual status and evidence in `PLANS.md` and `docs/BUILD_LOG.md`.

Run applicable tests and static checks. Never replace failing assertions with weaker tests merely to make them pass. Add a regression test for every calculation or persistence bug fixed. If a command cannot run, explicitly report NOT RUN and its blocker; do not claim it passed.

## Non-negotiable domain rules

- Store money as integer centavos. No binary floating-point money calculations.
- Store quantities as integer grams, milliliters, or pieces. Convert decimal kilograms/liters exactly from strings. No mass-to-volume conversion.
- Compare only the same product variant and quantity kind. Package size may differ; brand, variety, and grade must not be silently merged.
- Use the newest eligible record per matching store/offer group, not an obsolete cheaper record.
- Compare unit-price fractions before rounding. Round a displayed value or line estimate only at the specified boundary.
- Whole packages cannot be purchased fractionally in estimates. Distinguish unit value from the amount payable for the desired quantity.
- Always display the observed date and original package/quantity. Never claim 'cheapest in M'lang', live availability, or guaranteed savings.
- Missing estimates are null, not zero. Estimates never become actual spending automatically.
- Recording a bought list item and its purchase ledger entry must be one transaction and idempotent. A double tap must not create two expenses.
- Preserve historical purchase snapshots. Editing a product or price must not rewrite the amount previously spent.
- Evaluate calendar dates in Asia/Manila, independent of the phone's current timezone. Inject the clock for tests.
- Keep demo records in a separate database and mark demo mode on every screen. Never seed fictional prices into a real user's records.

## Architecture, safety, and usability

Separate widgets, state/controllers, pure domain logic, and data repositories. Repository writes are the only route to persistence. Enable and test foreign keys; implement and test database migrations rather than silently deleting a database.

No hard-coded credentials, real personal data, signing keys, or exports in Git. No purchases, amounts, or store notes in production logs. No runtime font downloads or analytics SDKs. Review release permissions and Android backup/data-transfer behavior. Do not promise encryption or absolute device-only storage without verifying it.

Exports must be user-initiated. Warn that Version 1 JSON/CSV exports are unencrypted. Restore validates the whole document before any mutation and replaces data only after explicit confirmation, in one transaction. Failed restore must leave existing data intact. CSV text cells must be escaped against spreadsheet formula injection.

Use simple English, accessible contrast, readable type, large touch targets, meaningful screen-reader labels, and visible validation. Test empty states, cancellation, duplicate submissions, keyboard visibility, 200% text scaling, and offline restart. Keep English strings ready for later reviewed translations; do not fake Cebuano or Hiligaynon support.

## Delivery boundaries

Do not publish, enable paid services, create remote infrastructure, change system-wide tool versions, rotate credentials, or distribute builds without the relevant authorization. Routine local implementation within the selected milestone is permitted. Stop only the genuinely blocked action, and explain what can still be completed.

An APK exists only if the build command succeeded AND the output file was inspected. Distinguish development/debug builds from properly release-signed builds. Never expose signing secrets in chat or commit them.

After each milestone report: implemented behavior; files changed; exact checks and results; checks not run; remaining issues; next milestone. Do not present screenshots or an APK as evidence unless they actually exist.
