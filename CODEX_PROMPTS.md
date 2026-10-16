# Ready-to-paste Codex prompts

Use these after putting the kit in the actual project folder/repository Codex can read. Do not paste every prompt at once.

## Start the project

```text
You are implementing Presyo M'lang, a real Flutter Android shopping companion for my personal use and later community use in M'lang, North Cotabato.

Read AGENTS.md, PRODUCT_SPEC.md, PLANS.md, and ACCEPTANCE_TESTS.md. Treat Version 1 as the current scope and the community edition as future work only.

First inspect the existing repository and installed development tools. Preserve existing work and planning files. Record the environment and any blockers. Do not assume Flutter, Java, Android SDK, or a connected phone is already installed.

Implement M0 and M1 from PLANS.md. Establish the Android app foundation, theme, four-tab navigation, local database, repositories, and tested money/quantity/date helpers. No backend, login, public sharing, AI feature, or fake live price feed.

Use exact centavo arithmetic and canonical quantities. Keep actual spending separate from estimates. Do not silently convert the project into a website when Android tooling is missing.

Run the checks available in the actual environment and report PASS, FAIL, or NOT RUN with reasons. Update PLANS.md, docs/DECISIONS.md, and docs/BUILD_LOG.md from actual evidence. Stop after M1 and summarize the next milestone. Do not claim an APK or successful test exists unless verified.
```

## Continue

```text
Read the project instructions, PRODUCT_SPEC.md, PLANS.md, ACCEPTANCE_TESTS.md, and the latest build log. Inspect actual code and test results rather than trusting an old progress summary.

Implement the next incomplete Version 1 milestone only. Fix any blocking earlier regression first. Keep the existing app runnable, preserve user work, add relevant tests, and do not expand into the community edition.

Run available checks. Update the roadmap and build log with observed results, disclose all unrun checks and environment blockers, and summarize changed files, working behavior, remaining issues, and the next milestone.
```

## Review before adding more features

```text
Review the current implementation against PRODUCT_SPEC.md and ACCEPTANCE_TESTS.md. Focus on exact money and quantity calculations, package rounding, latest-price selection, stale labels, duplicate spending, offline persistence, database migrations, restore rollback, and private-data leakage.

Identify reproducible issues first. Add regression tests and fix issues in severity order. Do not introduce unrelated features or rewrite working architecture merely for style. Report concrete test evidence and remaining risks.
```

## Prepare an internal Android build

```text
Inspect the real Flutter/Android toolchain and project configuration. Run the applicable format, analysis, unit/widget, and integration checks. Verify permissions and backup behavior. Build an internal development APK only when the environment supports it, then inspect the output path and label the build accurately.

Do not publish, upload, spend money, or configure paid infrastructure. Do not expose signing secrets. A public release must use an owner-approved application ID and proper release signing, not debug signing. Report missing requirements precisely and never fabricate a successful APK build or on-device test.
```
