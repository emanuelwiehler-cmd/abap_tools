# Dynamische RRI (Berichts-Berichts-Schnittstelle)

Dynamischer Absprung aus BW-Queries auf Quellsysteme, entweder auf eine **Transaktion im SAP GUI for HTML** (WebGUI) oder auf eine **Fiori-App im Launchpad**. Die Sprungziele werden nicht einzeln in der RSBBS gepflegt, sondern über Steuertabellen: pro InfoProvider wird ein RRI-Set zugeordnet, das pro InfoObjekt festlegt, wohin gesprungen wird und welche Werte als Parameter übergeben werden.

Technisch ist es eine Implementierung des BAdIs `RS_BBS_BADI_DYNAMIC` (Enhancement-Spot `RS_BBS_DYNAMIC_ENHS`).

## Ablauf zur Laufzeit

1. `GET_TYPES`: Ist der InfoProvider der Query in `ZRRI_12` einem RRI-Set zugeordnet, meldet sich der Handler `ZCL_RRI_DYN_IMPL` an.
2. `GET_TARGETS`: Für das InfoObjekt, auf dem der Benutzer den Absprung startet, liest die Klasse alle Einträge aus `ZRRI_10`, deren RRI-Set dem Provider zugeordnet ist. Jeder Eintrag erscheint als Sprungziel mit seinem Langtext. Der Objekt-Key (ONAM) ist `Besitzer&Set&InfoObjekt&Nummer`.
3. `CALL_URL`: `ZCL_RRI_DYN_SRV` liest Kopf (`ZRRI_10`), System-URL (`ZRRI_00`) und Parameter-Mapping (`ZRRI_11`) und baut die URL:
   - **RRI-Typ T (Transaktion):** `<URL>/sap/bc/gui/sap/its/webgui?sap-language=<LA>&sap-client=<MANDT>&~transaction=<TCODE> <Feld>=<Wert>;…DYNP_OKCODE=SHOW&~OKCODE=<OK-Code>#`
   - **RRI-Typ U (Fiori):** `<URL>/sap/bc/ui2/flp?sap-client=<MANDT>&sap-language=<LA>#<SemObjekt>-<Aktion>?<Param>=<Wert>&…`

   Ein Parameter bekommt entweder die gepflegte Konstante oder den ersten Einzelwert des zugeordneten InfoObjekts aus der Query.

## Objekte

| Typ | Objekt | Beschreibung | im Original (BIT) |
|---|---|---|---|
| Paket | `<Root>_RRI_DYN` | Dynamischer Absprung auf Quellsysteme (TX od. FIORI) | /BVCCSAP/C1_01_BWTOOLS_RRI_DYN |
| Tabelle | `ZRRI_00` | RRI System und URL | /BVCCSAP/C1_RR00 |
| Tabelle | `ZRRI_10` | RRI-Sets | /BVCCSAP/C1_RR10 |
| Tabelle | `ZRRI_11` | RRI-Parameter-Mapping | /BVCCSAP/C1_RR11 |
| Tabelle | `ZRRI_12` | RRI-Zuordnung | /BVCCSAP/C1_RR12 |
| Pflegeview | `ZRRI_80` | Pflege RRI-Sets | /BVCCSAP/C1_RR80 |
| Pflegeview | `ZRRI_81` | Pflege RRI Parameter-Mapping | /BVCCSAP/C1_RR81 |
| Pflegeview | `ZRRI_82` | Pflege RRI-Zuordnung | /BVCCSAP/C1_RR82 |
| Datenelement / Domäne | `ZRRI_DE_*` / `ZRRI_DOM_*` | OKCODE, PARAM, RRITYP, TCODE, URL, URLPARAM | /BVCCSAP/C1_DE_* / C1_DOM_* |
| Datenelement / Domäne | `ZRRI_DE_BESID` / `ZRRI_DOM_BESID` | Besitzer-ID (CHAR 10) | /BIC/OIC1CBESID (BW-InfoObjekt) |
| Datenelement / Domäne | `ZRRI_DE_SETID` / `ZRRI_DOM_SETID` | RRI-Set (CHAR 10) | /BIC/OIC1CRRISET (BW-InfoObjekt) |
| Klasse | `ZCL_RRI_DYN_IMPL` | BAdI-Implementierungsklasse | /BVCCSAP/CL_C1_RR_DYN_IMPL |
| Klasse | `ZCL_RRI_DYN_SRV` | Service-Klasse (URL-Aufbau) | /BVCCSAP/CL_C1_RR_DYN_SRV |
| Erweiterungsimpl. | `ZRRI_EI_RSBBS_DYN` mit BAdI-Impl. `ZRRI_BI_RSBBS_DYN` | Dynamische RSBBS | /BVCCSAP/C1_EI_RSBBS_DYN |
| *nachträglich generieren* | Funktionsgruppe(n), Transportobjekte | Tabellenpflegedialoge | /BVCCSAP/C1_RR00/80/81/82 |
| *nachträglich anlegen* | Viewcluster `ZRRI_VC` | Pflege dynamische RRI | Viewcluster zu RR80/81/82 |

Pflegedialoge (Funktionsgruppen mit Dynpros), Transportobjektdefinitionen und der Viewcluster sind generierte Objekte. Sie liegen bewusst nicht im Repo, weil sie im Zielsystem in wenigen Minuten erzeugt sind und generierte Dynpros zwischen Releases nicht sauber portierbar sind. Die Schritte stehen unten.

## Änderungen gegenüber dem Original

- **Namensraum:** `/BVCCSAP/C1_…` wird zu `ZRRI_…` bzw. `ZCL_RRI_…`. Mit `tools/rename_namespace.py` (oder `.ps1`) lässt sich alles in einem Schritt auf `Y` oder einen Kundennamensraum `/XYZ/` umstellen.
- **Keine BW-InfoObjekte als Datentyp:** Besitzer-ID und RRI-Set hatten die generierten Datenelemente `/BIC/OIC1CBESID` und `/BIC/OIC1CRRISET`. Die gibt es bei anderen Kunden nicht, deshalb jetzt eigene Domänen (CHAR 10). Wer die Werte als InfoObjekte im BW braucht, kann die Domänen auf dieselbe Länge setzen.
- **Besitzer-ID ohne Namenskonvention:** Das Original las die Besitzer-ID aus Stelle 2–3 des InfoProvider-Namens (`i_infoprov+1(2)`). Jetzt steht sie im Objekt-Key des Sprungziels und kommt aus der Zuordnung `ZRRI_12`. Damit funktioniert es mit jeder Provider-Namenskonvention.
- **Mandant und Sprache pro System:** `ZRRI_00` hat die neuen Felder `SAPCLIENT` und `SAPLANGU`. Das Original leitete den Mandanten aus Stelle 5–7 des logischen Systemnamens ab (`A01_100`) und hatte `sap-language=DE` fest im Code. Leere Felder bedeuten: Standardmandant des Zielsystems bzw. Anmeldesprache des Benutzers (Transaktion) oder Benutzervorgabe (Fiori).
- **Parameter-Mapping je Nummer:** Das Mapping wird jetzt auch nach `NUMB` gefiltert. Im Original wurden bei mehreren Nummern pro InfoObjekt die Parameter aller Nummern gemischt.
- **Fiori-URL:** `sap-client` steht jetzt vor dem `#` (Standard-Form des Launchpads), Parameterwerte werden URL-kodiert.
- **Fremdschlüssel** `ZRRI_11-NUMB` → `ZRRI_10`: Damit schlägt SE54 die Feldabhängigkeiten im Viewcluster automatisch vor.
- **Nicht übernommen:** `/BVCCSAP/CL_C1_SUM_DELTA` (lag im ZIP, gehört aber nicht zur RRI) und das Unterpaket `_DYO` (alte Bausteine).

## Installation

### 1. Optional: Namensraum umstellen

Für den Z-Namensraum ist nichts zu tun. Für einen anderen Namensraum vor dem Import in einem eigenen Branch oder einer Kopie:

```
python tools/rename_namespace.py --ns /XYZ/ --dry-run   # anzeigen
python tools/rename_namespace.py --ns /XYZ/             # umbenennen
```

Unter Windows ohne Python: `.\tools\rename_namespace.ps1 -Ns /XYZ/`. Das Skript prüft die Namenslängen (Tabellen/Views max. 16 Zeichen). Namensräume bis 8 Zeichen (`/XXXXXXXX/`) passen.

### 2. Import mit abapGit

1. Root-Paket anlegen, z. B. `ZBW_TOOLS` (bzw. `/XYZ/BW_TOOLS`).
2. abapGit: *New Online* (Repo-URL) oder *New Offline* (ZIP des Repos), Paket = Root-Paket, Ordnerlogik bleibt *Prefix*.
3. *Pull*. abapGit legt das Unterpaket `<Root>_RRI_DYN` an und importiert alle Objekte. Die Domänen, Datenelemente, Tabellen, Views und Klassen werden aktiviert, danach die BAdI-Implementierung.
4. Im Aktivierungsprotokoll prüfen, dass alles aktiv ist (SE80 → Paket → *Inaktive Objekte*).

### 3. Tabellenpflegedialoge generieren (SE54 / SE11 → Tabellenpflegegenerator)

Für `ZRRI_00`, `ZRRI_80`, `ZRRI_81` und `ZRRI_82` jeweils:

| Feld | Wert |
|---|---|
| Berechtigungsgruppe | `&NC&` (oder kundeneigene) |
| Funktionsgruppe | `ZRRI_MAINT` (eine für alle) oder je eine wie im Original (`ZRRI_00`, `ZRRI_80` …) |
| Pflegetyp | einstufig |
| Übersichtsbild | *Bildnummer(n) suchen* → vorschlagen lassen |
| Aufzeichnungsroutine | Standardaufzeichnungsroutine |

Die Besitzer-ID ist in den drei Pflegeviews als **Teilmengenfeld** (Pflegeattribut `S`) definiert. Dadurch fragt die Pflege beim Einstieg nach der Besitzer-ID und zeigt sie im Kopf über der Tabelle an, wie im Original.

Erwartetes Layout:

- **ZRRI_80 Pflege RRI-Sets:** Kopf *Besitzer-ID*; Spalten RRI-Set, InfoObject, Nummer, RRI-Typ (Dropdown *Absprung auf Transaktion* / *Absprung auf FIORI-URL*), T-Code/sem.Obj., OK-Code/Action, Logisches System, Beschreibung lang.
- **ZRRI_81 Pflege RRI Parameter-Mapping:** Kopf Besitzer-ID, RRI-Set, InfoObject, Nummer (kommen aus dem markierten RRI-Set); Spalten Parameter, InfoObject, URL-Parameter (Konstante).
- **ZRRI_82 Pflege RRI-Zuordnung:** Kopf Besitzer-ID; Spalten InfoProvider, RRI-Set.

Wenn das RRI-Typ-Feld als Eingabefeld statt als Dropdown erscheint: Im Pflegedialog (SE80 → Funktionsgruppe → Dynpro des Übersichtsbilds) beim Feld `ZRRI_80-RRITYP` *Dropdown = Listbox* setzen. Wenn Spaltenüberschriften als `+` erscheinen, ist die Spalte zu schmal für den Überschrift-Text: im Dynpro die Spaltenbreite vergrössern oder den Überschriftstext im Datenelement kürzen.

### 4. Viewcluster ZRRI_VC anlegen (SE54 → *Viewcluster bearbeiten*)

**Kopfeintrag:** Bezeichnung *Pflege dynamische RRI*.

**Objektstruktur:**

| Objekt | Kurztext | Vorgänger | Abh. | Pos. | Start |
|---|---|---|---|---|---|
| `ZRRI_80` | Pflege RRI-Sets | `ZRRI_80` | R | 01 | X |
| `ZRRI_81` | Pflege RRI Parameter-Mapping | `ZRRI_80` | S | 02 | |
| `ZRRI_82` | Pflege RRI-Zuordnung | `ZRRI_82` | R | 03 | |

Pflegedialog-Typ jeweils *Tabellenpflegedialog*.

**Feldabhängigkeiten** (für `ZRRI_81`): Objekt markieren → *Feldabhängigkeiten* → Vorschlag aus dem Fremdschlüssel übernehmen. Ergebnis: `MANDT`, `BESID`, `SETID`, `SOURCEIOBJ`, `NUMB` von `ZRRI_80`.

Dann prüfen und aktivieren. Die Dialogstruktur in SM34 sieht so aus:

```
Pflege RRI-Sets
  └ Pflege RRI Parameter-Mapping
Pflege RRI-Zuordnung
```

Optional eine Parametertransaktion in SE93 (z. B. `ZRRI`): Transaktion `SM34`, Bild überspringen, Vorschlagswerte `VIEWCLUSTER-NAME = ZRRI_VC`, `UPDATE = X`.

### 5. BAdI-Implementierung prüfen

SE19 → Erweiterungsimplementierung `ZRRI_EI_RSBBS_DYN` → BAdI-Implementierung `ZRRI_BI_RSBBS_DYN` muss *aktiv* sein, implementierende Klasse `ZCL_RRI_DYN_IMPL`.

## Pflege (Customizing)

1. **SM30 `ZRRI_00`:** pro logischem System die Basis-URL des Zielsystems ohne Pfad, z. B. `https://s4host.example.ch:44300`, dazu Mandant und optional Sprache (ISO, z. B. `DE`).
2. **SM34 `ZRRI_VC`**, Besitzer-ID eingeben (frei wählbar, z. B. Kürzel der Fachabteilung):
   - *Pflege RRI-Sets:* pro InfoObjekt, auf dem gesprungen werden soll, eine Zeile. Beispiel Transaktion: RRI-Set `X01`, InfoObject `0AC_DOC_NO`, Nummer `0000`, Typ T, T-Code `FB03`, OK-Code `WEITE`, Logisches System des Quellsystems, Text *Buchhaltungsbeleg anzeigen*. Beispiel Fiori: Typ U, T-Code/sem.Obj. = semantisches Objekt (z. B. `PurchaseOrder`), OK-Code/Action = Aktion (z. B. `displayFactSheet`).
   - *Pflege RRI Parameter-Mapping* (Zeile oben markieren): Parameter = Dynpro-Feld (Transaktion, z. B. `RF05L-BELNR`) bzw. URL-Parameter (Fiori), InfoObject = Quelle des Werts in der Query, oder URL-Parameter = Konstante.
   - *Pflege RRI-Zuordnung:* InfoProvider (z. B. der CompositeProvider der Query) dem RRI-Set zuordnen.
3. Query ausführen, Kontextmenü auf dem InfoObjekt → *Springen*: die gepflegten Ziele erscheinen mit ihrem Langtext.

Mehrere Ziele für dasselbe InfoObjekt im gleichen Set werden über die Nummer unterschieden.

## Voraussetzungen

- SAP BW 7.4 SP08 oder höher bzw. BW/4HANA (Inline-Deklarationen, neue Open-SQL-Syntax).
- Interface `IF_RS_BBS_BADI_DYNAMIC_INA` muss vorhanden sein. Auf älteren Releases ohne dieses Interface die Zeile `INTERFACES if_rs_bbs_badi_dynamic_ina.` und die zwei zugehörigen Methoden aus `ZCL_RRI_DYN_IMPL` entfernen.
- Das Quellsystem muss WebGUI (`/sap/bc/gui/sap/its/webgui`) bzw. das Fiori Launchpad (`/sap/bc/ui2/flp`) per Browser erreichbar machen. Die Pfade stehen als Konstanten in `ZCL_RRI_DYN_SRV`.
