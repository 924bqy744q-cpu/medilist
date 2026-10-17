#!/usr/bin/env python3
"""Generates MedList/Resources/Localizable.xcstrings and InfoPlist.xcstrings (English source, Dutch translation).

Edit the tables below, then run: python3 scripts/build_strings.py
Xcode may later add keys itself; keep this file as the reviewed source of truth for wording.
Rules: describe, never instruct. No "stop/take/should/must" (EN) or "stoppen/neem/innemen/moet" (NL).
"""
import json, pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent

NL = {
    "A medication name is needed.": "Een naam van het medicijn is nodig.",
    "A one-page summary to bring to appointments. Check it before sharing.": "Een overzicht van één pagina voor afspraken. Controleer het voordat u het deelt.",
    "About": "Over",
    "Add by hand": "Zelf toevoegen",
    "Add medication": "Medicijn toevoegen",
    "Add this medication": "Dit medicijn toevoegen",
    "Added %@": "Toegevoegd op %@",
    "Amount each time": "Hoeveelheid per keer",
    "Asks for Face ID or the device passcode each time MedList is opened.": "Vraagt om Face ID of de toegangscode van het toestel telkens als MedList wordt geopend.",
    "Care recipient": "Zorgontvanger",
    "Check": "Controleren",
    "Check and correct every detail": "Controleer en verbeter elk gegeven",
    "Check every field against the label. Fields marked Check may have been read incorrectly.": "Vergelijk elk veld met het etiket. Velden met Controleren zijn mogelijk niet goed gelezen.",
    "Choose a photo": "Kies een foto",
    "Confirm details": "Gegevens bevestigen",
    "Consent given": "Toestemming gegeven",
    "Continue": "Verder",
    "Data could not be deleted. Please try again.": "De gegevens konden niet worden gewist. Probeer het opnieuw.",
    "Date of birth": "Geboortedatum",
    "Delete all data": "Alle gegevens wissen",
    "Delete all data?": "Alle gegevens wissen?",
    "Delete everything": "Alles wissen",
    "Discard": "Weggooien",
    "Discard this scan?": "Deze scan weggooien?",
    "Edit medication": "Medicijn bewerken",
    "Entered and checked by the caregiver. Please compare with your own records.": "Ingevoerd en gecontroleerd door de mantelzorger. Vergelijk dit met uw eigen gegevens.",
    "Export": "Exporteren",
    "Export PDF": "PDF exporteren",
    "Form": "Vorm",
    "Generated on %@": "Gemaakt op %@",
    "Has a flag": "Heeft een aandachtspunt",
    "How often": "Hoe vaak",
    "I agree that MedList processes health information about the person I care for, as described above, and I am allowed to do so for them.": "Ik ga ermee akkoord dat MedList gezondheidsgegevens verwerkt van de persoon voor wie ik zorg, zoals hierboven beschreven, en ik mag dit namens die persoon doen.",
    "I understand MedList is an organizer and does not give medical advice.": "Ik begrijp dat MedList een hulpmiddel om te ordenen is en geen medisch advies geeft.",
    "If online reading is turned on in Settings: the text read from a label, with names, dates of birth and ID numbers removed where possible, is sent to the MedList extraction service and processed by an AI provider. It is not stored there.": "Als online lezen aan staat in Instellingen: de tekst van een etiket, waar mogelijk zonder namen, geboortedata en ID-nummers, wordt naar de MedList-uitleesdienst gestuurd en verwerkt door een AI-aanbieder. Daar wordt niets bewaard.",
    "Ingredient lookup": "Werkzame stoffen opzoeken",
    "Interaction check unavailable": "Controle op wisselwerkingen niet beschikbaar",
    "Interaction data": "Gegevens over wisselwerkingen",
    "Interaction data: %@": "Gegevens over wisselwerkingen: %@",
    "Label reading": "Etiket lezen",
    "Labels are read on this device only. Online reading is not set up in this version.": "Etiketten worden alleen op dit toestel gelezen. Online lezen is in deze versie niet ingesteld.",
    "Lock with %@": "Vergrendelen met %@",
    "MedList helps you keep a single, up-to-date list of medications for the person you care for, and bring it to appointments.": "MedList helpt u één actuele medicijnlijst bij te houden voor de persoon voor wie u zorgt, en die bij afspraken bij de hand te hebben.",
    "MedList is locked": "MedList is vergrendeld",
    "Medication": "Medicijn",
    "Medication %lld of %lld": "Medicijn %1$lld van %2$lld",
    "Medication information is health data. Before you continue, please read how MedList handles it.": "Informatie over medicijnen is gezondheidsinformatie. Lees eerst hoe MedList daarmee omgaat.",
    "Medication list": "Medicijnlijst",
    "Medication list – bring to appointment": "Medicijnlijst – voor de afspraak",
    "Medication name": "Naam van het medicijn",
    "Medication names are looked up in RxNorm (US National Library of Medicine) to find active ingredients. No personal details are sent.": "Namen van medicijnen worden opgezocht in RxNorm (Amerikaanse National Library of Medicine) om de werkzame stoffen te vinden. Er worden geen persoonsgegevens verstuurd.",
    "Medications (%lld)": "Medicijnen (%lld)",
    "Name": "Naam",
    "Names not recognized": "Niet herkende namen",
    "No flags found": "Geen aandachtspunten gevonden",
    "No medication details were found. Try a sharper photo, or add the medication by hand.": "Er zijn geen medicijngegevens gevonden. Probeer een scherpere foto, of voeg het medicijn zelf toe.",
    "No medications yet": "Nog geen medicijnen",
    "Nothing from this scan will be saved.": "Niets van deze scan wordt bewaard.",
    "OK": "OK",
    "One accurate medication list": "Eén kloppende medicijnlijst",
    "Online label reading": "Etiket online lezen",
    "Online reading was unavailable, so the text was read on this device only.": "Online lezen was niet beschikbaar, dus de tekst is alleen op dit toestel gelezen.",
    "Photograph a pill bottle label, a pharmacy box, or the medication list from discharge papers. Make sure the text is sharp and well lit.": "Fotografeer het etiket van een potje of doosje, of de medicijnlijst uit de ontslagpapieren. Zorg dat de tekst scherp en goed verlicht is.",
    "Photos. They are read on this device and never stored or uploaded.": "Foto's. Ze worden op dit toestel gelezen en nooit bewaard of geüpload.",
    "Please check this value. It may not have been read correctly.": "Controleer deze waarde. Die is mogelijk niet goed gelezen.",
    "Prescriber": "Voorschrijver",
    "Prescriber: %@": "Voorschrijver: %@",
    "Privacy and consent": "Privacy en toestemming",
    "Purpose": "Waarvoor",
    "Purpose: %@": "Waarvoor: %@",
    "Reading the label…": "Etiket wordt gelezen…",
    "Remove": "Verwijderen",
    "Remove from list": "Van de lijst verwijderen",
    "Remove this medication from the list?": "Dit medicijn van de lijst verwijderen?",
    "Removes the care recipient, every medication, and all settings from this device. This cannot be undone.": "Verwijdert de zorgontvanger, alle medicijnen en alle instellingen van dit toestel. Dit kan niet ongedaan worden gemaakt.",
    "Save": "Bewaar",
    "Save to list": "Op de lijst zetten",
    "Save %lld medications": "%lld medicijnen op de lijst zetten",
    "Scan a pill bottle label or discharge papers, or add a medication by hand.": "Scan een etiket of ontslagpapieren, of voeg een medicijn zelf toe.",
    "Scan label": "Etiket scannen",
    "Scan labels and discharge papers": "Scan etiketten en ontslagpapieren",
    "Security": "Beveiliging",
    "See items to verify with the pharmacist": "Zie wat u met de apotheker kunt controleren",
    "Settings": "Instellingen",
    "Share PDF": "PDF delen",
    "Share a one-page PDF": "Deel een PDF van één pagina",
    "Show recognized text": "Herkende tekst tonen",
    "Shown on the PDF so the doctor knows whose list it is. Stored only on this device.": "Staat op de PDF zodat de arts weet van wie de lijst is. Alleen op dit toestel bewaard.",
    "Shows the flags": "Toont de aandachtspunten",
    "Start": "Beginnen",
    "Strength": "Sterkte",
    "Text is read on this device. Photos are never stored or uploaded.": "Tekst wordt op dit toestel gelezen. Foto's worden nooit bewaard of geüpload.",
    "The PDF could not be created.": "De PDF kon niet worden gemaakt.",
    "The medication list and care recipient will be permanently removed from this device.": "De medicijnlijst en de zorgontvanger worden definitief van dit toestel verwijderd.",
    "The medication list, the name and date of birth. Encrypted by iOS and not included in backups.": "De medicijnlijst, de naam en de geboortedatum. Versleuteld door iOS en niet in back-ups opgenomen.",
    "The photo could not be read. Please try again.": "De foto kon niet worden gelezen. Probeer het opnieuw.",
    "The photo itself is not stored. This text is discarded when you leave this screen.": "De foto zelf wordt niet bewaard. Deze tekst verdwijnt als u dit scherm verlaat.",
    "Turn on the app lock": "De app-vergrendeling aanzetten",
    "Unlock": "Ontgrendelen",
    "Unlock the medication list": "De medicijnlijst ontgrendelen",
    "Use camera": "Camera gebruiken",
    "Use sample label": "Voorbeeldetiket gebruiken",
    "What leaves this device": "Wat dit toestel verlaat",
    "What stays on this device": "Wat op dit toestel blijft",
    "When on, recognized label text (not the photo) is sent to the MedList extraction service for better results. Names, dates of birth and ID numbers are removed first where possible.": "Als dit aan staat, wordt de herkende tekst (niet de foto) naar de MedList-uitleesdienst gestuurd voor betere resultaten. Namen, geboortedata en ID-nummers worden waar mogelijk eerst verwijderd.",
    "Who is this list for?": "Voor wie is deze lijst?",
    "You can delete all data at any time in Settings.": "U kunt alle gegevens altijd wissen in Instellingen.",
    "%@: %@": "%1$@: %2$@",
    "%@, born %@": "%1$@, geboren %2$@",
    "device passcode": "toegangscode",
    "e.g. 1 tablet": "bijv. 1 tablet",
    "e.g. 50 mg": "bijv. 50 mg",
    "e.g. Dr. Jansen": "bijv. Dr. Jansen",
    "e.g. Metoprolol": "bijv. Metoprolol",
    "e.g. blood pressure": "bijv. bloeddruk",
    "e.g. once daily": "bijv. 1 x per dag",
    "e.g. tablet": "bijv. tablet",
}

# Keys with plural forms: key -> (en one, en other, nl one, nl other)
PLURALS = {
    "%lld flags to review": ("%lld flag to review", "%lld flags to review",
                             "%lld aandachtspunt om te bekijken", "%lld aandachtspunten om te bekijken"),
    "%lld more flags are shown in the app.": ("%lld more flag is shown in the app.", "%lld more flags are shown in the app.",
                                              "Nog %lld aandachtspunt staat in de app.", "Nog %lld aandachtspunten staan in de app."),
    "List continues: %lld more medications are not shown. See the app.": (
        "List continues: %lld more medication is not shown. See the app.",
        "List continues: %lld more medications are not shown. See the app.",
        "De lijst gaat verder: nog %lld medicijn staat niet op deze pagina. Zie de app.",
        "De lijst gaat verder: nog %lld medicijnen staan niet op deze pagina. Zie de app."),
    "Preview of the PDF with %lld medications": ("Preview of the PDF with %lld medication", "Preview of the PDF with %lld medications",
                                                 "Voorbeeld van de PDF met %lld medicijn", "Voorbeeld van de PDF met %lld medicijnen"),
}

INFOPLIST_NL = {
    "CFBundleDisplayName": ("MedList", "MedList"),
    "NSCameraUsageDescription": ("MedList uses the camera to read medication labels. Photos stay on this device.",
                                 "MedList gebruikt de camera om etiketten van medicijnen te lezen. Foto's blijven op dit toestel."),
    "NSFaceIDUsageDescription": ("MedList can use Face ID to keep the medication list private.",
                                 "MedList kan Face ID gebruiken om de medicijnlijst privé te houden."),
}


def unit(value):
    return {"stringUnit": {"state": "translated", "value": value}}


def plural(one, other):
    return {"variations": {"plural": {"one": unit(one), "other": unit(other)}}}


def main():
    strings = {key: {"localizations": {"nl": unit(nl)}} for key, nl in NL.items()}
    for key, (en1, en2, nl1, nl2) in PLURALS.items():
        strings[key] = {"localizations": {"en": plural(en1, en2), "nl": plural(nl1, nl2)}}
    catalog = {"sourceLanguage": "en", "strings": dict(sorted(strings.items())), "version": "1.0"}
    out = ROOT / "MedList/Resources/Localizable.xcstrings"
    out.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + "\n")

    info = {"sourceLanguage": "en", "version": "1.0", "strings": {
        key: {"extractionState": "manual", "localizations": {"en": unit(en), "nl": unit(nl)}}
        for key, (en, nl) in INFOPLIST_NL.items()}}
    (ROOT / "MedList/Resources/InfoPlist.xcstrings").write_text(json.dumps(info, ensure_ascii=False, indent=2) + "\n")
    print(f"wrote {len(strings)} strings")


if __name__ == "__main__":
    main()
