# Snowstorm Local

Self-contained local instance of [Snowstorm](https://github.com/IHTSDO/snowstorm), the SNOMED CT terminology server, with Elasticsearch backend and the official browser UI. Runs entirely in Docker.

## What's in here

| Service | Port | Purpose |
|---|---|---|
| Snowstorm | `8080` | REST + FHIR terminology server |
| Browser UI | `80` | Web UI for exploring concepts |
| Elasticsearch | `9200` (loopback) | Storage backend |

## Prerequisites

- **Docker** + **Docker Compose** (v2)
- **~8 GB free RAM** (4 GB minimum, 8 GB recommended for full International Edition)
- **~10 GB free disk** (for Elasticsearch indexes after import)
- A SNOMED CT RF2 release file (see [snomed-data/README.md](snomed-data/README.md) for sourcing)

## Quick start

```bash
cd snowstorm-local
cp .env.example .env

# Start the stack
docker compose up -d

# Wait ~60s for everything to come up, then check
./scripts/check-status.sh
```

You should see all three services reporting OK. The browser UI at http://localhost:80 will load but show no content until SNOMED CT data is imported.

## Loading SNOMED CT data

1. Obtain an RF2 release zip (see [snomed-data/README.md](snomed-data/README.md))
2. Place it in `snomed-data/`
3. Run the import:

   ```bash
   ./scripts/import-snomed.sh snomed-data/SnomedCT_InternationalRF2_PRODUCTION_*.zip
   ```

The script uploads the file to Snowstorm and polls until import completes. Expect **15-45 minutes** for the International Edition Snapshot, depending on hardware and JVM heap.

While imports are running you can `Ctrl-C` the script — the import continues server-side. Re-poll status with:

```bash
curl -s http://localhost:8080/imports/<import-id> | jq
```

## Endpoints

Once running:

- **REST API**: http://localhost:8080
- **Swagger UI**: http://localhost:8080/swagger-ui.html
- **FHIR base**: http://localhost:8080/fhir
- **Browser UI**: http://localhost:80
- **Elasticsearch**: http://localhost:9200 (loopback only)

### Useful API checks

```bash
# Version
curl -s http://localhost:8080/version | jq

# List branches (will show MAIN after first import)
curl -s http://localhost:8080/branches | jq

# Search concepts (after import)
curl -s 'http://localhost:8080/MAIN/concepts?term=heart&limit=5' | jq

# FHIR CodeSystem lookup (after import)
curl -s 'http://localhost:8080/fhir/CodeSystem/$lookup?system=http://snomed.info/sct&code=80891009' | jq
```

## Pointing existing projects at the local server

The other SNOMED projects in this workspace currently use the public IHTSDO server. Switch them to local:

| Project | Find | Replace with |
|---|---|---|
| `snomed-ct-api` | `https://snowstorm.ihtsdotools.org/snowstorm/snomed-ct` | `http://localhost:8080` |
| `snomed-explorer` | `https://snowstorm.ihtsdotools.org/fhir` | `http://localhost:8080/fhir` |
| `Snomed-In-5-Minutes` | `http://browser.ihtsdotools.org/api/snomed/` | `http://localhost:8080` |

CORS is configured permissive (`*`) so frontends on any port can hit the API.

## Tuning memory

Edit `.env` to adjust JVM heap:

```
ES_HEAP=4g                # raise if importing full edition + plenty of RAM
SNOWSTORM_HEAP_MAX=6g     # raise during heavy imports / large exports
```

Restart after changing: `docker compose down && docker compose up -d`

## Common operations

```bash
# Logs
docker compose logs -f snowstorm
docker compose logs -f elasticsearch

# Stop (preserves data)
docker compose down

# Stop AND wipe Elasticsearch data (irreversible)
docker compose down -v

# Restart just one service
docker compose restart snowstorm
```

## Troubleshooting

**Snowstorm container exits with `bootstrap_check_exception` from Elasticsearch (Linux):**
Set vm.max_map_count:
```bash
sudo sysctl -w vm.max_map_count=262144
```
Make permanent by adding `vm.max_map_count=262144` to `/etc/sysctl.conf`.

**Out-of-memory during import:**
Increase `SNOWSTORM_HEAP_MAX` and `ES_HEAP` in `.env`, then restart. Or import the Snapshot release instead of Full.

**Port 80 already in use (often: another web server, Skype, or AirPlay Receiver on macOS):**
Change the browser port in `docker-compose.yml`:
```yaml
  browser:
    ports:
      - "8081:80"     # then visit http://localhost:8081
```

**Apple Silicon: browser image fails to start:**
The `snomedinternational/snomedct-browser` image may not have an `arm64` build. Try forcing platform in `docker-compose.yml`:
```yaml
  browser:
    platform: linux/amd64
    image: snomedinternational/snomedct-browser:latest
```
Or omit the browser service entirely and rely on the Swagger UI for API exploration.

**Import hangs / no progress in logs:**
Imports do most of their work in batched commits — log output is sparse. Check actual progress:
```bash
curl -s http://localhost:8080/imports/<import-id> | jq
```

## File layout

```
snowstorm-local/
├── docker-compose.yml          # Stack definition
├── .env.example                # Tunable env vars
├── .gitignore
├── README.md                   # this file
├── config/
│   └── application-local.properties   # Snowstorm runtime overrides
├── snomed-data/
│   ├── README.md               # Where to put RF2 zips
│   └── (your .zip releases here, gitignored)
└── scripts/
    ├── import-snomed.sh        # Import RF2 via API
    └── check-status.sh         # Health checks
```

## License notes

- **Snowstorm**: Apache 2.0 — see https://github.com/IHTSDO/snowstorm
- **SNOMED CT content** (the RF2 files): licensed; requires SNOMED International affiliate agreement or member country / national release center access. Do not redistribute.
