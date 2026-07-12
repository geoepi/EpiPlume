# Multi-run facility connectivity

This workflow discovers portable parsed plume objects and reuses the single-run receptor extractor. It aggregates modeled atmospheric-tracer contacts; it does not execute HYSPLIT, download meteorology, infer infection, or estimate transmission.

Discovery preserves every manifest row. Directory presence alone is not success: `missing` has no usable metadata, `dry_run`, `failed`, and `completed` come from run metadata, `parsed` requires a portable parsed object or parsing metadata, `receptor_extracted` requires an exchange product, and unreadable metadata is `invalid`. Only portable parsed objects are eligible for processing. Individual errors are recorded and processing continues by default.

Combined exchange rows remain one run × source × receptor and retain non-intercepts, distance-screened rows, unavailable metrics, release calendar fields, and directed `source_id__receptor_id` identifiers. Candidate denominators default to `within_evaluation_distance == TRUE`; outside-distance rows remain in the combined table but not denominators.

Release, daily, ISO-week, and monthly summaries distinguish zero-intercept periods and explicitly count runs, sources, receptors, candidates, and intercepts. Source summaries distinguish unique intercepted receptors from repeated events. Receptor summaries preserve evaluated never-intercepted receptors and multi-source contacts. Dyads are directed and retain zero-frequency evaluated pairs.

Matrices are square in deterministic facility order. Zero means an evaluated dyad with no intercept; `NA` means unevaluated, unavailable, or diagonal. Outputs include inventories, processing logs, combined exchange, all summaries, supported matrices, checksums, package versions, commit provenance, and RDS/JSON assembly metadata.

Current limitations are portable parsed-object discovery by repository convention, one scenario per assembly, sequential processing, and no job control, source attribution, epidemiological probabilities, or statistical network model.
