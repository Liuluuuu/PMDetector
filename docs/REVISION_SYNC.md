# Major revision synchronization checklist

Baseline: upstream `main` at `11e0035c87ba4da652da04b3ef56b915f221c15d`.
Scope: released parameters, usable entrypoints, documentation, and offline checks.
The manuscript and response-letter LaTeX files are not changed by this code update.

## Mapping to the response letter

| Response | Repository change | Status |
| --- | --- | --- |
| #12: temperature mismatch | Shared zero-temperature setting; all four OpenAI/Anthropic SDK/HTTP branches corrected; explicit full-CLI model selection and configuration metadata | Implemented; mocked requests verified |
| #9: run-to-run variation | Nondeterminism explanation; five independent runs, per-run metrics, sample SD and min–max protocol; corrected DeFiTainter SDs and RQ2 ranges | Documentation aligned; original run data and expanded tables pending |
| #1, #6, #22: benign benchmark | 288 = 226 ERC20-only + 62 price-relevant; GPT-4o FP=0/TN=62; manual-review limitations | Paper-reported values documented; exact membership/review records pending |
| #5: TP criterion | Require manual PoC path agreement; distinguish static paths, retained warnings and evaluation TPs; rename static-summary field to `has_taint_paths` | Summary semantics fixed; manual review records pending |
| #11: analyzable inputs | PMDetector 68/73, DeFiTainter 60/73, GPTScan 68/73; do not assume equal input sets | Documentation aligned; exclusion manifests pending |
| #2, #8, #10, #17, #18: deployment figures | More than 8,000 scanned, 12 flagged, nine manually validated, four confirmed/fixed; case categories and deployment-precision limitation | Paper-reported values documented; no new disclosures or reproduced scan claimed |
| #19: headline results | GPT-4o P/R/F1 = 1.00/0.84/0.91; Claude = 0.90/0.88/0.90 | Documentation aligned |
| #7, #13: scope and modeling | Qualitative candidate reasoning, single-contract ICFG, single atomic transaction; no quantitative profit/PoC guarantee | Documentation aligned; algorithm unchanged |
| #14: benign filtering | Explain access control, economic intent and explicit mitigations | Documentation aligned; prompts unchanged |
| #15: Libero example | Document the stronger conditions missing from the existing fee-on-transfer heuristic | Open; no rule modification or claim of full alignment |
| #4, #20: related tools | PriceSleuth comparison remains methodological; no reproduced implementation/four-case evaluation claimed | Documentation aligned; no new baseline experiments |
| #21: training-data contamination | Retain the public-case contamination limitation | Documentation aligned; no independently verified cutoff analysis claimed |
| #3, #16: oracle-market context and prose correction | Manuscript-only context/wording; no new detector behavior required | No code change required |

## Changed interfaces and files

- `pmdetector/llm/config.py`: shared paper temperature constant.
- `pmdetector/llm/llm_service.py`: zero temperature in all four request paths;
  model/temperature logging. Token limits and legacy model defaults are retained.
- `pmdetector/llm/multi_agents.py`: shared zero default and request-setting logging.
- `pmdetector/llm/narrative_generator.py`: shared zero default, configuration logging,
  corrected determinism comment. Prompt bodies are unchanged.
- `main.py`: `--llm-model` (default `gpt-4o`), explicit temperature 0, additive
  `llm_config` object in generated LLM result JSON.
- `pmdetector/llm/analyze_taint_paths.py`: align the advertised provider with the
  OpenAI-compatible narrative backend; pass CLI API keys to its authorization
  setting. Unsupported `--llm-service anthropic` now reports a usage error instead
  of silently using the other backend. Standalone Anthropic helpers remain available.
- `experiments/analyze_results.py`: explicit dataset/results/output CLI; replace
  `has_vulnerability` with `has_taint_paths`; skip incomplete summaries, write CSV
  headers for empty summaries, and default to a new build output. Historical CSVs
  keep their old schema and contents; downstream new-output consumers must migrate
  the column name. This is still a static path summary, not a metric evaluator.
- `setup.py`, `install.sh`: repair the console entrypoint and install instructions;
  include the top-level modules and dependencies imported by the command.
- `README.md`, `pmdetector/llm/README.md`, `docs/REPRODUCIBILITY.md`: usage, scope,
  paper-reported figures, experimental protocol and pending evidence.
- `tests/test_revision_sync.py`: offline regression checks.
- This checklist: reviewer-facing mapping, validation and remaining work.

## Validation performed

- Fresh Python 3.12 environment: `python -m pip install -e .` succeeded, installing
  the declared entrypoint dependencies without relying on another project.
- `python -m unittest discover -s tests -v`: **12 tests passed**. Coverage includes
  all four service request branches, multi-agent and narrative request temperatures,
  model selection and recorded metadata, narrative key propagation/provider validation,
  installed/module help, dataset argument validation, and static-summary semantics.
- Prompt-generation functions were compared structurally against the baseline;
  all are unchanged. The attack-model text, detector/sanity-checker implementation,
  dataset spreadsheet and historical summary have no source changes.
- These checks use mocks/synthetic reports. No paid LLM calls, on-chain scans,
  compiler-driven detection reruns or historical metric reconstructions were performed.

The agreed outstanding work is listed in
[REPRODUCIBILITY.md](REPRODUCIBILITY.md#pending-artifact-checklist).
