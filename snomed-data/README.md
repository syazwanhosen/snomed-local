# SNOMED CT Release Files

Place SNOMED CT RF2 release `.zip` files in this directory before running the import script.

## Obtaining release files

SNOMED CT content is **licensed** — you must have a valid SNOMED International license (or be in a member country / affiliate organization) to download and use these files.

Sources:

- **International Edition**: https://www.snomed.org/get-snomed → MLDS portal
- **National extensions** (US, UK, AU, etc.): your country's release center
- **Member organizations**: typically have their own download portals

## Recommended starting file

For most local development, start with the **International Edition Snapshot**:

```
SnomedCT_InternationalRF2_PRODUCTION_<date>T<time>Z.zip
```

The Snapshot release contains the current state only (no history) and is the smallest/fastest to import (~15-30 min on a modern laptop).

## File placement

```
snomed-data/
├── SnomedCT_InternationalRF2_PRODUCTION_20240101T120000Z.zip   <-- here
└── README.md
```

## License & version control

The `.gitignore` excludes all `.zip` files and any `SnomedCT*` files in this folder. **Do not commit release content.**

## Importing

Once the file is in place, run from the project root:

```bash
./scripts/import-snomed.sh snomed-data/<your-file>.zip
```
