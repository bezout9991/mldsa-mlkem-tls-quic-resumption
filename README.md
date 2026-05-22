# Post-Quantum TLS 1.3 vs QUIC Session Resumption — Batch Séparés Experiment

This repository contains the raw data and analysis scripts for the **Batch Séparés** (separated batches) session resumption benchmark, following the standard methodology used in the literature (rTLS, rustls-bench, etc.).

## Experiment Design (Batch Séparés)

**Approach** (the most common in the literature):
- **Phase 1**: 500 consecutive full handshakes (each establishes a new TLS/QUIC session)
- **Phase 2**: 500 consecutive resumed handshakes (reusing the session from the last full handshake)

This allows independent statistical analysis of full vs resumed performance (median, p95, p99, success rate).

**Pairs tested**:
- ML-DSA65 + ML-KEM768
- ML-DSA87 + HQC256

**Scenarios** (8 runs total):
- TLS + QUIC
- 4 network conditions: Ideal (0ms/0%), Local YDE (35ms/2%), Degraded (200ms/10%), GE Stable

## Repository Structure

```
.
├── README.md
├── scripts/
│   ├── Launcherv3_resumption_batch.sh      # Main launcher (1 pair)
│   ├── run_resumption_batch_matrix.sh      # Full matrix runner (8 runs)
│   ├── perftestClientResumptionBatch.sh    # Client (Phase 1 + Phase 2)
│   └── analyse_resumption_batch.py         # Analysis script (produces CSV + plots)
├── results/
│   ├── tls_none_l0_d0_20260522_071321/     # Raw data for each run
│   ├── tls_simple_l2_d35_20260522_071837/
│   ├── ... (6 more runs)
│   └── analysis_batch/
│       ├── comparison_resumption_batch.csv
│       └── *.pdf (comparison, distribution, percentiles)
```

## How to Reproduce the Measurements

### Prerequisites
- Docker with the image `uma-tls-quic-pq-34` (contains OpenSSL 3.4 + OQS provider + custom QUIC tools)
- The Docker network `localNet` and volume `cert` are managed automatically by the scripts

### Run a single test
```bash
./scripts/Launcherv3_resumption_batch.sh tls none 0 0
```

### Run the full matrix (8 runs)
```bash
./scripts/run_resumption_batch_matrix.sh
```

Results are written under `results/<run_id>/` with one CSV per pair:
- `resumption_1_mldsa65_mlkem768.csv`
- `resumption_1_mldsa87_hqc256.csv`

Each CSV contains 1000 lines (500 full + 500 resumed) with columns:
`run_id,handshake_type,duration_ms,success`

### Analyze the results
```bash
python3 scripts/analyse_resumption_batch.py results/ --plots --output results/analysis_batch
```

This produces:
- `comparison_resumption_batch.csv` (full table with p50/p95/p99, success rates, speedup)
- Publication-ready PDF figures

## Key Findings (ML-DSA65 + ML-KEM768)

| Protocol | Scenario          | Full P50 (ms) | Resumed P50 (ms) | Speedup | Resumed Success |
|----------|-------------------|---------------|------------------|---------|-----------------|
| QUIC     | Ideal (0/0)       | 7.57          | 7.62             | 0.99×   | 100%            |
| QUIC     | 35ms/2%           | 81.36         | 81.03            | 1.00×   | 100%            |
| QUIC     | 200ms/10%         | 414.25        | 414.86           | 1.00×   | 100%            |
| QUIC     | GE Stable         | 15.80         | 14.03            | 1.13×   | 100%            |
| TLS      | Ideal (0/0)       | 34.00         | 36.00            | 0.94×   | 100%            |
| TLS      | 35ms/2%           | 170.00        | —                | —       | **0%**          |
| TLS      | 200ms/10%         | 928.00        | —                | —       | **0%**          |
| TLS      | GE Stable         | 121.00        | 128.50           | 0.94×   | 100%            |

**Main scientific result**:
- **QUIC** resumption works reliably (100% success) even under heavy degradation (200 ms / 10% loss).
- **TLS 1.3** session resumption completely fails in degraded conditions — the session ticket/file is never successfully created/persisted when the initial full handshake suffers packet loss or high delay.

This demonstrates that the native QUIC resumption mechanism (NewSessionTicket + 0-RTT) is significantly more robust than classical TLS 1.3 session tickets under lossy/high-latency networks when using post-quantum cryptography.

## Reproducibility Notes

All raw CSVs are included so any researcher can:
1. Re-run the exact same analysis script
2. Verify the numbers in the paper
3. Extend the experiment with new pairs or scenarios

The Docker image `uma-tls-quic-pq-34` used for the measurements is the same one used in the broader project (see parent repository for build instructions).

## License

MIT — feel free to reuse the data and scripts for academic or industrial research.
