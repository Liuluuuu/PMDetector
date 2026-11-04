# PMDetector

PMDetector combines static taint analysis with LLM reasoning to identify candidate
price-manipulation vulnerabilities in DeFi smart contracts. The paper is under
submission. This repository is being synchronized with its major revision.

## Pipeline and scope

1. **Candidate path extraction:** Slither builds an interprocedural control-flow
   graph within a single contract; taint analysis connects potentially manipulable
   price sources to economic endpoints.
2. **Path filtering:** an LLM checks access control, intended economic behavior,
   and explicit mitigations to filter apparently benign paths.
3. **Attack analysis:** an LLM reasons about manipulation and value extraction
   using the remaining source-to-sink paths.
4. **Sanity verification:** heuristic rules check for known defenses and filter
   some warnings.

The implementation targets a **single contract and a single atomic transaction**.
It stops at unresolved external calls and does not model cross-contract execution,
front-running, sandwich attacks, or other multi-transaction strategies. Reports
are candidates for manual review, not validated PoCs or quantitative proofs of
profitability. A retained warning is not automatically an evaluation true positive.

The current sanity checker does **not** fully implement the detailed conditions
in the response letter's Libero example. See the [known gap](docs/REPRODUCIBILITY.md#known-implementation-gap-libero).
Detection rules and experimental prompts are unchanged by this synchronization.

## Installation

Use Python 3.10 or newer for a fresh environment (the package's existing declared
minimum remains Python 3.8). Slither and a compatible Solidity compiler are required;
compiler selection may download a compiler when analyzing a contract.

```bash
git clone https://github.com/Liuluuuu/PMDetector.git
cd PMDetector
python3 -m venv venv
source venv/bin/activate
python -m pip install -r requirements.txt
python -m pip install -e .
```

Run from the repository root using this editable installation. The prototype
writes intermediate paths and reports into the source checkout. `bash install.sh`
performs the same environment setup. This is a runnable installation procedure,
not a lockfile for the historical experiment environment.

## Full detection pipeline

Set `OPENAI_API_KEY` in your environment. The full pipeline uses the OpenAI SDK
and an OpenAI-compatible chat-completions endpoint. An alternate compatible
endpoint can be configured with the SDK's `OPENAI_BASE_URL` environment variable.
Model availability and identifiers depend on that endpoint.

```bash
# Analyze Solidity source; default model is gpt-4o.
python main.py --source-code path/to/contract.sol

# Equivalent installed command, with an explicit model.
pmdetector --source-code path/to/contract.sol --llm-model gpt-4o

# Analyze a contract fetched from a supported chain.
pmdetector --contract-address CONTRACT_ADDRESS --platform ETH --llm-model gpt-4o

pmdetector --help
```

Supported platform arguments are `ETH`, `Base`, `BSC`, `ARB`, and `Polygon`.
Address-based analysis additionally requires access to the corresponding explorer
service. Availability of verified source code and successful compilation affect
whether a contract can be analyzed.

The full CLI explicitly uses **temperature = 0**. Model and temperature are logged
and included in generated LLM JSON reports as `llm_config`. Zero temperature
reduces randomness but does **not** guarantee identical hosted-API outputs.
The CLI default `gpt-4o` is an operational model alias, not a verified historical
snapshot identifier.

Static reports are written under `analysis_results/`; LLM reports use
`*_llm_result.json` and post-sanity-check `*_filtered_llm_result.json` in the
checkout. Successful analyses with no paths may produce only a static report.
Existing API-error fallbacks can contain a false verdict: such failed executions
must be identified from errors/logs and excluded from completed-run evaluation,
not interpreted as safe contracts.

## Auxiliary path narratives

The [LLM module documentation](pmdetector/llm/README.md) describes a separate tool
for grouping pre-extracted text paths and generating narratives. It is **not**
the full detection pipeline and does not replace attack analysis or sanity checks.
The standalone `llm_service.py` OpenAI and Anthropic helpers also use temperature 0
in both their SDK and direct HTTP request implementations.

## Experiments and artifact status

The final manuscript reports GPT-4o precision/recall/F1 of **1.00/0.84/0.91**,
averaged over five runs on **68 analyzable vulnerable contracts and 288 benign
contracts**. The vulnerable collection contains 73 contracts; five failed SlithIR
conversion. Of the benign contracts, 226 contain only ERC20 functionality and 62
contain oracle or DEX taint sources; GPT-4o has FP=0 and TN=62 on the latter subset.

The reported deployment scan covered **more than 8,000 contracts**, flagged
**12 candidates**, validated **nine** through manual review, and obtained developer
confirmation and fixes for **four**. Benchmark precision is not deployment
precision; prevalence and manual review matter.

These are **paper-reported results**, not results recomputed from this checkout.
The expanded five-run results, contract-level verdicts, PoC-path review records,
and exact subset/exclusion manifests are **pending**. The checked-in spreadsheet
and legacy summary are not a complete reproduction package. See
[reproducibility and artifact status](docs/REPRODUCIBILITY.md) for denominators,
model configurations, corrected SDs, limitations, and outstanding evidence.

### Static candidate-path summary

```bash
python -m experiments.analyze_results \
  --dataset experiments/data/dataset/attack_dataset.xlsx \
  --results-dir pmdetector/analysis_results \
  --output build/static_path_summary.csv
```

Choose the actual static-results directory: the dataset processor uses
`pmdetector/analysis_results`, whereas `main.py` uses `analysis_results`.
This command requires the dataset's contract hashes to match the report filenames.
It only counts static paths. The new `has_taint_paths` column replaces the
misleading historical `has_vulnerability` column; both describe whether the static
path count is positive, not a final vulnerability verdict. Historical CSV files
are retained unchanged. Missing/incomplete summaries are skipped with a warning.

## Validation

```bash
python -m unittest discover -s tests -v
```

Tests use mocked LLM responses and synthetic static reports; they do not rerun the
paper's experiments or spend API credits. The [revision checklist](docs/REVISION_SYNC.md)
maps changes to the response letter and records outstanding work.

## Acknowledgments

- [Slither](https://github.com/crytic/slither), the Solidity analysis framework.
- DeFiTainter and public incident/PoC sources used in the paper's evaluation;
  see the manuscript bibliography and reproducibility notes for their roles.
