# Facility exchange data dictionary

All facility and observation records in the demonstration are synthetic.

## Facilities

| Field | Type | Meaning |
|---|---|---|
| `facility_id` | character | Unique synthetic facility identifier. |
| `facility_name` | character | Human-readable synthetic label. |
| `longitude`, `latitude` | numeric | WGS84 coordinates in decimal degrees. |
| `facility_type` | character | Record provenance; `simulated` in this workflow. |
| `source_height_m` | numeric | Planned release height above ground in metres. |

## Observations

| Field | Type | Meaning |
|---|---|---|
| `observation_id` | character | Unique monitoring record identifier. |
| `facility_id` | character | Foreign key to facilities. |
| `observation_date` | date string | Observation date in `YYYY-MM-DD` format. |
| `observation_status` | character | One of `positive`, `negative`, or `unknown`; a generic tracer-monitoring state. |

## Directed facility pairs

| Field | Type | Meaning |
|---|---|---|
| `source_id`, `receptor_id` | character | Ordered facility identifiers; reciprocal directions are separate rows. |
| `distance_m`, `distance_km` | numeric | Euclidean distance calculated after local UTM projection. |

## Planned HYSPLIT manifest

Each row defines a planned source/release combination. Identifiers, coordinates, UTC release and simulation bounds, release height, unit emission rate, evaluation radius, tracer half-life, meteorology family, local run directory, and `planned` status are retained. A manifest row is not evidence that a run occurred.

## Simulation truth

`facility_id`, `seeded_source`, and `seed_rank` identify synthetic seeded sources for reproducibility and evaluation. Truth is stored separately from monitoring observations to prevent accidental use as observed evidence.
