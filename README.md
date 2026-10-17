# MedList

An iOS app that helps a family caregiver keep **one accurate medication list** for a parent. The caregiver photographs pill bottle labels or discharge papers; the app reads them on the device, proposes the details, and the caregiver confirms or fixes every field. The app keeps a master list, flags duplicate active ingredients and known interactions ("Verify with your pharmacist"), and exports a one-page PDF to bring to appointments.

MedList is an organizer. **It does not give medical advice.**

## Setup

Requirements: Xcode 16 or later (the project uses folder-synchronized groups), iOS 17+. No third-party dependencies in the app.

```bash
open MedList.xcodeproj        # pick an iPhone simulator, Run (⌘R) / Test (⌘U)
scripts/test-core.sh          # MedListCore unit tests (swift test; falls back to Docker on Linux)
Eval/run_eval.sh              # extraction accuracy on Eval/samples
cd backend && npm test        # extraction proxy tests
```

To run on a device, set your team under *Signing & Capabilities*. The Data Protection entitlement needs a paid developer account; for a free account, remove `CODE_SIGN_ENTITLEMENTS` (files are still protected in code, see below).

**Simulator tips.** The simulator has no camera. In Debug builds, the launch argument `-uitest-reset` shows a **Use sample label** button on the Scan screen. `-uitest-seed` loads a fictional recipient and four medications, and `-uitest-open flags|confirm|export|settings` jumps to a screen. CI uses these to take screenshots. All of them are ignored in Release builds.

## Architecture

```
MedListCore/          Swift package, Foundation only, so it is tested on Linux and macOS
  Extraction/         ExtractionService protocol, MockExtractionService (on-device LabelTextParser, EN+NL),
                      RemoteExtractionService (OCR text → your proxy), TextRecognizer (Vision OCR, Apple only)
  Privacy/            OCRRedactor: strips the recipient's name, date of birth, phone and ID numbers before text leaves the device
  Normalization/      RxNormClient (NLM REST), LocalAliasTable (NL brands), IngredientKey, IngredientNormalizer
  Flags/              DuplicateDetector, InteractionProvider + SampleInteractionProvider, FlagEngine, FlagCopy (all flag wording)
  Report/             ReportLayout: the rules that keep the PDF to exactly one A4 page
  Eval/               EvalScoring: per-field accuracy and "errors caught by the highlight"
  medlist-eval        CLI used by Eval/run_eval.sh
MedList/              SwiftUI app (iOS 17, SwiftData)
  App/                entry point, AppEnvironment (service wiring, AppConfig), AppLock (Face ID), PrivacyLog
  Data/               @Model CareRecipient, Medication; MedicationDraft (unsaved); DataStore (protection, delete-all)
  Features/           Onboarding, MedList (+ flag banner, manual add/edit), Scan (+ Confirm), Flags, Export, Settings
  Resources/          Localizable.xcstrings + InfoPlist.xcstrings (en, nl), assets with high-contrast variants
MedListTests/         PDF is one A4 page, file protection, drafts, delete-all
MedListUITests/       onboarding → scan → confirm → save → add brand → duplicate flag → export → share sheet
backend/              reference extraction proxy (Node, Claude API with structured outputs); the only place an API key lives
Eval/                 labelled samples + run_eval.sh
scripts/              build_strings.py (String Catalog source), test-core.sh, ci-screenshots.sh
.github/workflows/    core tests on Linux and macOS; build, unit and UI tests on an iPhone simulator; screenshots
```

**Scan pipeline.** VisionKit document camera or photo picker → `UIImage` held in memory only → Vision `VNRecognizeTextRequest` (accurate, nl-NL + en-US, language correction off so drug names aren't "corrected") → `OCRRedactor` → `ExtractionService` → **Confirm** screen. Every field is editable. Fields with confidence below 0.7, or missing, are highlighted with an icon and the word *Check* (never colour alone) and get a VoiceOver hint. Nothing is written until *Save*. Then the drug name is resolved to active ingredients (local alias table, then RxNorm, then the cleaned name itself), and the medication is stored.

**Flags.** Recomputed whenever the list changes. Duplicates: two or more medications share an ingredient key, so brand + generic, different salts, and combination products are all caught. Interactions: an ingredient pair is in the `InteractionProvider` data and belongs to two *different* medications. Each flag ends with "Verify with your pharmacist." If the interaction source fails, the app says so instead of implying "no interactions". "No flag does not mean there is no problem" appears on the Flags screen and in the PDF.

**Wording safety.** `WordingSafetyTests` fails the build if any flag text, sample interaction description, or any key or translation in the String Catalog contains instruction words (stop, take, should, must, "dose should be", and the Dutch stoppen, neem, innemen, moet, …). Text read from a label ("Take 1 tablet daily") is the user's own data, so it is shown but never generated.

## Privacy and security

- **On device:** SwiftData store in Application Support with `NSFileProtectionComplete` (also the app-wide default via the entitlement), excluded from backups, no iCloud sync. Photos are never written to disk. OCR text is discarded when the Confirm screen closes. Exported PDFs are written to a protected temp folder and deleted when the share sheet closes.
- **Leaves the device:** drug names → RxNorm (NLM). If the user turns on *Online label reading*, redacted OCR text → your proxy → Claude API. Both are stated on the consent screen.
- **Delete all data** (Settings) deletes every record, clears preferences and temporary exports, and removes the store files on the next launch.
- Optional **Face ID / passcode lock**, plus a privacy cover in the app switcher.
- **No analytics SDKs.** `PrivacyLog` logs event names and counts only, never medication content or names.

## What is real and what is mocked

| Piece | Status |
|---|---|
| Camera capture, Vision OCR, Confirm flow, SwiftData list, flags UI, PDF + share sheet, Face ID lock, delete-all, EN/NL | **Real** |
| `MockExtractionService` | Real on-device heuristic parser (`LabelTextParser`). The default extractor, and the fallback when online reading fails. |
| `RemoteExtractionService` + `backend/` | **Real code, not deployed.** The app ships with `AppConfig.extractionEndpoint = nil`, so the toggle is disabled. The proxy's tests use a fake client; it has never been called against the live API from this repo. |
| RxNorm lookup | Real client, **tested against recorded-shape fixtures only**. The live API is skipped in UI tests and was not reachable from the build environment. Verify on device. |
| Brand → ingredient for NL | **Sample** table of ~40 brands (`ingredient_aliases.json`) |
| Interaction data | **Sample**: 9 pairs, not clinically validated (`sample_interactions.json`). Needs a licensed source, see TODO.md. |
| Eval set | 5 **fictional** placeholders. Add your own 50. |

## Tests

- `MedListCore`: 49 tests covering the parser (EN/NL labels, discharge lists, liquids, OCR noise), the extraction JSON contract, redaction, RxNorm normalization, duplicates, interactions, wording safety (including the String Catalog), the one-page layout, and eval scoring.
- App unit tests: the PDF is exactly one A4 page, file protection, drafts, delete-all, model mapping.
- UI tests: the full scan → confirm → save → flag → export flow, plus discarding a scan.
- CI (`.github/workflows/ios.yml`) runs all of these on every push and uploads simulator screenshots in English, Dutch, and at a large text size as an artifact.

See **TODO.md** for what has to happen before a pilot.
