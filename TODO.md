# Before a pilot

MedList v1 is a working MVP, not a pilot-ready product. The items below are yours to decide or do. Ordered roughly by how badly they block a pilot.

## 1. Licensed interaction data (blocker)
- [ ] The current `SampleInteractionProvider` has **9 hand-picked pairs and is not clinically validated**. Users would read "no flag" as "checked", even though the app says otherwise.
- [ ] Choose a licensed source. For a Dutch pilot the natural choice is the **G-Standaard (Z-Index)**, which also covers Dutch brand → ingredient mapping (see item 2). Alternatives: First Databank, Medi-Span, DrugBank. The free RxNav interaction API was discontinued in January 2024.
- [ ] Implement `InteractionProvider` against it (`MedListCore/Sources/MedListCore/Flags/Interactions.swift`) and swap it in at `AppEnvironment.init`. Decide whether it runs on-device (licensed data bundle) or through your backend (sends ingredient names, which are still health data).
- [ ] Decide with a pharmacist which severity levels to show at all. Showing every minor interaction trains people to ignore flags.

## 2. Ingredient normalization for NL
- [ ] RxNorm is US-only, so Dutch brands (Selokeen, Pantozol, Ascal…) don't resolve there. `ingredient_aliases.json` is a ~40-entry **sample** fallback. Replace it with the G-Standaard (HPK/PRK → ingredient), or extend it with pharmacist review.
- [ ] Have a pharmacist review the salt-stripping and spelling rules in `IngredientKey.swift`. Example: Ascal (carbasalate calcium) is deliberately matched to aspirin.
- [ ] Note that RxNorm lookups send drug names (no personal data) to the NLM in the US. Mention this in the privacy notice. It already appears on the consent screen.

## 3. Legal and medical wording review (blocker)
- [ ] Have a lawyer and a pharmacist review every user-facing string. The safety-critical copy lives in two files: `MedListCore/Sources/MedListCore/Flags/FlagCopy.swift` (flags, disclaimer) and `scripts/build_strings.py` (UI, consent; it generates the String Catalogs).
- [ ] Confirm the regulatory position. An organizer that flags duplicates and interactions may count as a **medical device under EU MDR (Rule 11)** once it "provides information used to take decisions". Get a written opinion before the pilot.
- [ ] Consent text: confirm it is valid explicit consent under GDPR Art. 9(2)(a). A caregiver consents on behalf of someone else, so check the legal basis and whether the care recipient must also be informed or consent.
- [ ] The wording tests (`WordingSafetyTests`) ban instruction words. Extend the list with whatever legal adds.

## 4. Backend deployment (needed for online extraction)
- [ ] Deploy `backend/` in the EU with TLS. Set `ANTHROPIC_API_KEY`, `MEDLIST_CLIENT_TOKEN`, and the rate limit. Disable request-body logging at every layer.
- [ ] Sign Anthropic's DPA and request **zero data retention**. Confirm the chosen model is available under ZDR.
- [ ] Replace the static client token with **App Attest** (DeviceCheck) verification. Add per-device quotas.
- [ ] Set `AppConfig.extractionEndpoint` in `MedList/App/AppEnvironment.swift`.
- [ ] Run the eval (item 6) against the proxy and pick the model and effort with data. The default is `claude-opus-5-5` at low effort. A cheaper model may be good enough for transcription.
- [ ] Record the processing in your register of processing activities, and list Anthropic (and your host) as sub-processors.

## 5. App Store and privacy
- [ ] **App Privacy labels:** "Health & Fitness → Health" and "Other user content" (label text), both *not linked to identity* and *not used for tracking*, collected only when online reading is on. No analytics, no tracking.
- [ ] Add a **privacy manifest** (`PrivacyInfo.xcprivacy`). The app uses `UserDefaults` (required-reason API `CA92.1`).
- [ ] Write a privacy policy URL and support URL, and make the medical disclaimer visible in the store listing.
- [ ] Set your `DEVELOPMENT_TEAM` and bundle ID (`app.medlist.MedList` is a placeholder). The Data Protection entitlement needs a paid developer account.
- [ ] App icon (`Assets.xcassets/AppIcon` is empty).
- [ ] Decide whether excluding the store from backups is right for your users. It's the privacy-maximal default, but losing a phone loses the list (the PDF is the only copy).
- [ ] Do a DPIA (data protection impact assessment). Large-scale special-category processing almost certainly requires one.

## 6. Extraction quality
- [ ] Drop your 50 labelled photos into `Eval/private/` and run `Eval/run_eval.sh Eval/private`, once for the on-device parser and once for the proxy (`--endpoint`).
- [ ] Look at **errors caught** first. A confident wrong field is the dangerous one. Tune `ConfidencePolicy.lowThreshold` (0.7) on the data.
- [ ] Decide which extractor is the default. On-device-only means no processor and no DPA, but worse accuracy.

## 7. Product gaps found while building
- [ ] Multi-page discharge papers: the camera captures several pages, but medications that span a page break may be split.
- [ ] A "stopped / no longer used" state instead of deletion, so the history survives. This was out of scope for v1.
- [ ] Edit history: the list doesn't record who changed what or when (only created and updated dates).
- [ ] The PDF is limited to one page. With more than ~40 medications it truncates and says so. Decide whether a second page is acceptable.
- [ ] Accessibility audit with real users. Dynamic Type, VoiceOver labels and high-contrast colors are implemented, and CI takes one screenshot at an accessibility text size. Nobody has tested it with VoiceOver users or older caregivers yet.
- [ ] Dutch copy review by a native writer for tone (formal "u" is used throughout).
