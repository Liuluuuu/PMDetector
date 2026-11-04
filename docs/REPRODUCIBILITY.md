# Major revision: reproducibility and artifact status

## Evidence status

This document transcribes the final major revision manuscript/response letter.
Numbers labeled **paper-reported** have not been recomputed in this repository
update. Parameter/entrypoint tests validate code behavior, not historical metrics.
The letter states that its experiments used temperature 0 and that correcting
`llm_service.py` does not change those results; this update aligns the released
settings but cannot independently verify historical execution without raw logs.

The repository contains implementation, prompts, a dataset spreadsheet, and
legacy outputs. It does **not yet** contain the complete five-run artifact promised
in the response letter. In particular, an expanded table with mean, sample SD,
minimum–maximum, and per-run metrics cannot be reconstructed from rounded paper
summaries. No such observations are synthesized here.

## Dataset and denominators

| Item | Paper-reported scope |
| --- | --- |
| Vulnerable collection | 73 contracts |
| PMDetector, RQ1–RQ4 | 68 analyzable vulnerable contracts; five SlithIR conversion failures excluded |
| DeFiTainter, RQ2 | 60 analyzable vulnerable contracts; 13 Gigahorse compilation failures |
| GPTScan, RQ2 | 68 analyzable vulnerable contracts; five projects could not be flattened |
| Benign collection | 288 sampled from 1,195 DeFiTainter contracts; all 288 manually reviewed |
| Benign composition | 226 with only ERC20 functionality; 62 with oracle or DEX taint sources |
| GPT-4o on the 62 price-relevant benign contracts | FP=0, TN=62; also no false positives on the other 226 |

Counts are at the **contract** level. Each tool's actual supported input set must
be retained in its manifest. Equal counts do not establish equal contract sets.
Do not use 68 as DeFiTainter's denominator or silently count conversion failures
as completed experimental negatives. Subset identities and exclusion details
still require the final manifests.

A true positive requires that the reported source-to-sink path agree with the
corresponding PoC attack path, checked manually. Matching only a vulnerable label,
finding a taint path, or retaining a warning after sanity checks is insufficient.
The current sanity checker's `Verified True Positive` status is an internal
heuristic label, not that manual evaluation judgment. The static summary command
is not a paper-metric evaluator. Failure/placeholder responses must not be counted
as successful benign verdicts.

For future metric reconstruction, preserve each run's final post-sanity-check
verdict, successful-execution status, and manual path-agreement record separately.
If manual agreement or the exact scoring treatment of an unmatched positive is
missing, leave the metric unresolved rather than guessing it from aggregate counts.

## Models and five-run protocol

| Experiment | Paper-reported configuration |
| --- | --- |
| RQ1 effectiveness | GPT-4o, Claude Sonnet 4, Qwen3-235B-A22B, Kimi-K2, DeepSeek-R1 |
| RQ2 comparison | GPT-4o for PMDetector, GPTScan, OnlyLLM, SinglePrompt; DeFiTainter is static |
| RQ3 ablations | Claude Sonnet 4 |
| RQ4 efficiency | The five evaluated model configurations; reported time/cost are prototype model-call measures |

All paper LLM experiments use **temperature = 0**. Historical provider endpoints,
exact model snapshot identifiers, dependency versions and execution logs are
pending verification; model family names or current aliases must not be presented
as verified historical snapshot IDs. Listing a paper model here does not imply
that the full CLI has a native adapter for every provider.

For each configuration:

1. Execute **five independent runs** over its fixed eligible contract set. Retain
   run IDs and contract IDs. API retries are not additional experimental runs;
   reusing cached responses is not an independent run.
2. Compute precision, recall, and F1 separately for every completed run using the
   manual PoC path criterion. Do not compute the final mean metric solely from
   pooled or rounded mean TP/FP/FN counts.
3. Summarize each metric with its arithmetic mean, **sample SD (`ddof=1`)**, and
   observed minimum and maximum. Report these on the 0–1 scale used in the paper.
4. Count each contract once if its final binary verdict is positive in at least
   one run and negative in at least one other run. Require all five completed
   observations; missing records or errors do not constitute verdict changes.
5. Keep raw outputs, run settings and review records separate from summaries.
   A discrepancy with the paper must be investigated, not fixed by editing raw data.

Zero temperature reduces but does not eliminate API nondeterminism.

## Paper-reported results

GPT-4o precision/recall/F1 are **1.00 / 0.84 / 0.91**, averaged over five runs on
68 analyzable vulnerable and 288 benign contracts. Claude Sonnet 4 reports
**0.90 / 0.88 / 0.90**. These numbers do not assert all 73 vulnerable contracts
were successfully analyzed.

| Stability summary | Precision SD range | Recall SD range | F1 SD range |
| --- | --- | --- | --- |
| RQ1, five model configurations | 0.000–0.025 | 0.010–0.023 | 0.006–0.024 |
| RQ2, five tool configurations including DeFiTainter | 0.000–0.010 | 0.000–0.012 | 0.000–0.021 |

For DeFiTainter, all three SDs are **0.000** across the five runs. These are
reported observations, not values that a future aggregation script should force.
The paper reports **two** contracts with changing verdicts for PMDetector and
**four each** for GPTScan, OnlyLLM and SinglePrompt. Individual configurations'
per-run metrics and minimum–maximum ranges remain pending; the SD ranges above
are ranges **across configurations**, not per-run metric ranges.

The deployment scan covered **more than 8,000** Ethereum/BSC contracts:
**12 candidates → nine manually validated → four developer-confirmed and fixed**.
The four confirmed cases comprise two token-swap spot-price cases, one vault
mint/burn spot-price case, and one reserve-price case. Public details must follow
the existing disclosure status. Benchmark precision, measured on a population
with roughly four benign contracts per vulnerable contract, must not be treated
as deployment precision, where vulnerability prevalence differs.

PriceSleuth is discussed methodologically. Its implementation was not reproduced,
and PMDetector was not evaluated on its four published cases. No new empirical
comparison is claimed. Public incident/PoC cases may have appeared in LLM training
data; manual review of benign contracts supports the price-manipulation labels
but does not establish safety against every vulnerability class.

## Known implementation gap: Libero

The response letter's illustrative Libero explanation describes balance updates
before a router call, an identified router, and a transfer amount determined by
fee logic rather than a manipulable quote. The released
`SanityChecker._check_fee_on_transfer_pattern` instead checks whether `_transfer`
or `_transferFrom` internally reaches a DEX interaction. It does **not** establish
all those stronger conditions.

Per the agreed revision scope, detection rules and prompts remain unchanged.
This gap stays open: documentation synchronization must not imply these checks
have been implemented or verified. Aligning the rule would require a separate
change with behavioral validation and potentially rerunning experiments. The
current single-contract/single-transaction scope also remains unchanged; the tool
does not validate quantitative profit, generated PoCs, or multi-transaction attacks.

## Pending artifact checklist

- [ ] Five original executions per configuration, including raw outputs and errors.
- [ ] Contract-level final verdicts and manual source-to-sink/PoC agreement records.
- [ ] Exact vulnerable, benign, price-relevant and per-tool supported-input manifests.
- [ ] Identities and observed reasons for excluded contracts; no inferred labels.
- [ ] Expanded results with per-run metrics, means, sample SDs and min–max ranges.
- [ ] Historical model identifiers, endpoints, timestamps and environment provenance.
- [ ] Resolution and validation of the Libero implementation/documentation difference.

The existing spreadsheet and historical CSV remain untouched by this update.
Other local experiments or reimplementations are not substituted for the final
paper data without verifying their provenance.
