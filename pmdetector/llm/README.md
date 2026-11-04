# LLM execution paths

## Full detection pipeline

Run `python main.py --source-code path/to/contract.sol --llm-model gpt-4o`
from the repository root (or use the installed `pmdetector` command).
`main.py` invokes `MultiAgentAnalyzer` for benign-path filtering and attack
analysis, then the rule-based sanity checker. It uses `OPENAI_API_KEY`, defaults
to `gpt-4o`, and explicitly passes temperature 0. The model identifier and
temperature are logged and saved as `llm_config` in LLM JSON reports.

Prompts in `multi_agents.py`, the narrative prompt, and the attack-model text
are preserved. See [reproducibility notes](../../docs/REPRODUCIBILITY.md) for the
paper's model configurations and the distinction between candidates and verified
true positives. No native Anthropic full-pipeline adapter is claimed: that pipeline
currently uses the OpenAI SDK and requires a compatible endpoint.

## Auxiliary narrative tool

This tool parses existing **text** taint paths, groups them, generates short
narratives and extracts code evidence. It does not run the complete detector.

```bash
# Configure an OpenAI-compatible HTTP endpoint explicitly.
export LLM_API_HOST=api.openai.com
export LLM_API_ENDPOINT=/v1/chat/completions
export LLM_MODEL=gpt-4o
# Set LLM_KEY to the complete Authorization header value, e.g. "Bearer <key>".

python -m pmdetector.llm.analyze_taint_paths \
  --input-dir path/to/text/taint/paths \
  --output-dir build/narratives \
  --llm-model gpt-4o

# Restrict the same invocation to one file: NAME.txt.
python -m pmdetector.llm.analyze_taint_paths \
  --input-dir path/to/text/taint/paths \
  --output-dir build/narratives \
  --contract NAME --llm-model gpt-4o
```

The optional `--llm-api-key` argument accepts a raw key and supplies the Bearer
header; environment configuration avoids putting a key in shell history.
`--llm-service` accepts only `openai`, meaning the OpenAI-compatible HTTP protocol.
Previously it advertised an Anthropic switch that this execution path did not
actually use; unsupported service names now fail argument validation.

The legacy default HTTP host remains `api.gpt.ge`; set `LLM_API_HOST` explicitly
for the endpoint you intend to use. `--llm-model` sets `LLM_MODEL`; without either,
the grouping helper retains its legacy `gpt-4.1-mini` default. The older single
prompt helper retains `qwen3-32b`. These defaults are not the paper's configurations;
the examples explicitly select GPT-4o. Model and temperature are logged.
Both helpers default to temperature 0. Direct Python constructors retain their
existing configurable-temperature API; use 0 for the paper protocol.

The Python functions `analyze_contract(input_file, output_dir)` and
`analyze_all_contracts(input_dir, output_dir)` remain available in `path_analyzer`.
Outputs are `<name>_analysis.json` and `<name>_report.txt`, with path groups,
source-to-sink descriptions, represented-path counts, narratives, and code
locations. They are not contract-level evaluation metrics or PoC validations.

## Standalone service adapters

`llm_service.py` provides `OpenAIService`, `AnthropicService`, and
`get_llm_service`. These are separate helpers, not the narrative CLI backend.
They support SDK and direct HTTP requests. All four branches now send
**temperature 0**; other parameters, including token limits, are unchanged.
Their legacy model defaults remain `gpt-4` and `claude-3-opus-20240229`; pass an
explicit model for a particular experiment. The Anthropic SDK is optional:
without it, the helper uses `requests`.

These helpers can return placeholder text when credentials are absent or requests
fail. Placeholder/error responses are not experimental observations. Temperature 0
reduces randomness but does not guarantee determinism, so the paper protocol uses
five independent executions rather than repeated reads from a cached response.

## Modules

- `multi_agents.py`: full-pipeline filtering and attack reasoning.
- `config.py`: shared paper temperature constant.
- `path_grouping.py` / `path_parser.py`: parsing and grouping.
- `narrative_generator.py`: auxiliary narratives over an OpenAI-compatible endpoint.
- `path_analyzer.py` / `analyze_taint_paths.py`: narrative reports and CLI.
- `llm_service.py`: standalone OpenAI / Anthropic service adapters.
