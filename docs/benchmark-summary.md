### Measured Benchmarks (Apple Silicon (arm64) · Version 26.7.2 (Build 25G332))

- **SHA-256 Incremental Re-Scan:** `8.61 ms` vs `1291.0 ms` initial full extract (**`150x` speedup**)
- **Cross-Document Analyst Synthesis:** **`15.72 ms`** · Multi-page `PDFKit` page citation (**PASS**) · `Vision` OCR receipt (**PASS**) · Auto lowest-quote match (**PASS**)

| Indexed Chunks | SQLite WAL Size | Bytes / Chunk | Hybrid Search p50 | Hybrid Search p95 |
| ---: | ---: | ---: | ---: | ---: |
| 1000 chunks | 1.10 MB | 1151 B | **1.81 ms** | **3.85 ms** |
| 5000 chunks | 5.10 MB | 1070 B | **4.10 ms** | **7.46 ms** |
| 10000 chunks | 10.09 MB | 1058 B | **8.56 ms** | **12.94 ms** |
| 25000 chunks | 25.66 MB | 1076 B | **23.78 ms** | **37.26 ms** |
