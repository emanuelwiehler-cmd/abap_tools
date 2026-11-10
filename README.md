# ABAP-Tools

Wiederverwendbare ABAP-/BW-Bausteine im Z-Namensraum, als abapGit-Repository. Jedes Tool liegt als Unterpaket unter `src/` und kann bei einem Kunden in dessen Namensraum installiert werden.

| Tool | Ordner | Beschreibung | Doku |
|---|---|---|---|
| Dynamische RRI | `src/rri_dyn` | Dynamischer Absprung aus BW-Queries auf Transaktionen (WebGUI) oder Fiori-Apps im Quellsystem, gesteuert über Pflegetabellen statt RSBBS-Einzelpflege | [docs/rri_dyn.md](docs/rri_dyn.md) |

## Installation mit abapGit

1. Root-Paket anlegen, z. B. `ZBW_TOOLS` (im Kundennamensraum z. B. `/XYZ/BW_TOOLS`).
2. Repo in abapGit als Online- oder Offline-Repo (ZIP) mit diesem Paket verbinden, Ordnerlogik *Prefix*.
3. Pull. Die Unterpakete heissen dann `<Root>_<ORDNER>`, z. B. `ZBW_TOOLS_RRI_DYN`.
4. Nacharbeiten des jeweiligen Tools laut Doku (z. B. Pflegedialoge generieren).

## Anderer Namensraum

Die Objekte heissen `Z<KÜRZEL>_…` bzw. `ZCL_<KÜRZEL>_…`. Vor dem Import umbenennen:

```
python tools/rename_namespace.py --ns /XYZ/              # Standard: Kürzel RRI, Ordner src/rri_dyn
.\tools\rename_namespace.ps1 -Ns /XYZ/                   # dasselbe in PowerShell
```

Die Skripte ersetzen Dateinamen und Inhalte und prüfen die SAP-Namenslängen.
