# Post-Quantum TLS 1.3 vs QUIC Session Resumption — Batch Séparés Experiment

This repository contains the **exact** raw data and scripts used for the Batch Séparés resumption benchmark (the standard methodology from the literature: rTLS, rustls-bench, etc.).

**Goal of this repo**: full reproducibility of the paper results with zero path guessing.

## Directory Structure (identical to the original measurement environment)

```
mldsa-mlkem-tls-quic-resumption/
├── Launcherv3_resumption_batch.sh          ← launcher for one pair
├── run_resumption_batch_matrix.sh          ← full matrix (8 runs)
├── analyse_resumption_batch.py             ← analysis + figures
├── 0-docker/
│   └── scripts/
│       └── perftestClientResumptionBatch.sh   ← the actual client used
├── results/
│   ├── tls_none_l0_d0_20260522_071321/     ← raw data (CSV + metadata)
│   ├── tls_simple_l2_d35_20260522_071837/
│   ├── tls_simple_l10_d200_20260522_073108/
│   ├── tls_stable_l0_d0_20260522_082000/
│   ├── quic_none_l0_d0_20260522_084426/
│   ├── quic_simple_l2_d35_20260522_085246/
│   ├── quic_simple_l10_d200_20260522_090758/
│   ├── quic_stable_l0_d0_20260522_100337/
│   └── analysis_batch/                     ← generated CSV + PDFs
└── README.md
```

## How to Reproduce (copy-paste)

1. Clone this repo
2. Make sure you have the Docker image `uma-tls-quic-pq-34` (same image used for the measurements)

### Run the full matrix again (optional – will overwrite results/)
```bash
./run_resumption_batch_matrix.sh
```

### Re-analyze the existing data (recommended – fast)
```bash
python3 analyse_resumption_batch.py results/ --plots --output results/analysis_batch
```

This will regenerate:
- `results/analysis_batch/comparison_resumption_batch.csv`
- All publication figures (PDF/SVG/PNG)

## Pairs and Scenarios

- **Pairs**: ML-DSA65 + ML-KEM768 and ML-DSA87 + HQC256
- **Protocols**: TLS 1.3 and QUIC
- **Network conditions**: Ideal (0 ms / 0 %), 35 ms / 2 %, 200 ms / 10 %, GE Stable

Each run directory contains two CSVs with 1000 lines each (500 full + 500 resumed).

## Main Scientific Result

QUIC resumption succeeds at 100 % even under heavy degradation (200 ms + 10 % loss).

TLS 1.3 resumption completely fails (0 % success) as soon as the network is degraded — the session ticket is never reliably created or persisted when the initial full handshake suffers loss or delay.

## Reproducibility Guarantee

All raw CSVs are included. Anyone can:
- Re-run the exact analysis script
- Verify every number in the paper
- Extend the experiment

No hidden data, no missing scripts, no path guessing.

## License

MIT – reuse freely for research or industry.
