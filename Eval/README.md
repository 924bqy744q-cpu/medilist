# Extraction eval

Measures per-field extraction accuracy, and whether the Confirm screen's **Check** highlight catches the mistakes.

## Add your samples

Put each labelled sample in `Eval/samples/` (or any folder) as a pair:

| File | Content |
|---|---|
| `0006.jpg` / `.jpeg` / `.png` / `.heic` | Photo of a label or discharge page. OCR'd with Vision, the same engine the app uses (**macOS only**). |
| `0006.txt` | Or OCR text, if you already have it (works everywhere, including Linux). |
| `0006.expected.json` | What is truly printed, typed by a person. |

```json
{ "medications": [
  { "drug_name": "Omeprazol", "strength": "20 mg", "form": "capsule", "dose": "1 capsule",
    "frequency": "1 x per dag", "prescriber": "Dr. P. de Boer", "purpose": null }
] }
```

- Use `null` (or leave a key out) when the field is **not printed**. A value predicted for a `null` field counts as *hallucinated*.
- Discharge papers: one entry per medication. Predicted and expected medications are paired by drug name.
- Comparison ignores case, accents, spacing, "20mg" vs "20 mg" and punctuation. Anything else counts as wrong.
- Write the values as printed, in the label's language ("1 x per dag", not "once daily").
- **Real labels are health data.** Remove or black out names, dates of birth, addresses and barcodes before adding a photo. Keep the real set out of git: `Eval/private/` is a good place, and that path is in `.gitignore`.

The five files in `samples/` are fictional placeholders that show the format. I wrote them while building the parser, so their score doesn't tell you anything. Replace them with your 50.

## Run

```bash
Eval/run_eval.sh                                    # on-device parser (what the app uses offline)
Eval/run_eval.sh Eval/private --verbose             # your own set
Eval/run_eval.sh Eval/private --endpoint https://<your-proxy>/extract --token <client-token> \
                 --json Eval/results/remote.json    # the Claude-backed proxy
```

Options: `--language nl|en` (hint sent to the extractor, default `nl`), `--json <file>` (machine-readable report), `--verbose` (lists which fields were wrong per sample, by field name only).

## Read the result

```
field       accuracy  wrong  missed  halluc.  errors caught  false alarms
drug_name    85.7%    1      0       0        100.0%           0.0%
```

- **accuracy**: share of fields that are exactly right, including correctly empty ones.
- **errors caught**: the share of wrong, missed or hallucinated fields that the Confirm screen highlighted (confidence below 0.7). This is the safety number. A wrong field that is *not* highlighted is the dangerous case, because the caregiver is least likely to look at it. Aim for close to 100% here before you optimise accuracy.
- **false alarms**: the share of correct values that were highlighted anyway. Too many and caregivers learn to ignore the highlight.

Suggested pilot gate (your call): drug_name and strength accuracy ≥ 95% and errors caught ≥ 95% on the 50-sample set, for the extractor you ship.
