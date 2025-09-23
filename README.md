# PMDetector

PMDetector is a hybrid analysis tool for smart contracts that combines taint analysis with LLM-based reasoning to detect price manipulation vulnerabilities by tracking the flow of tainted data from external sources to sensitive operations.

The research paper for PMDetector is currently under submission.

## Installation

### Prerequisites

- Python 3.8 or higher
- [Slither](https://github.com/crytic/slither) 0.9.0 or higher
- OpenAI API key (for LLM-based analysis)

### Install from Source

```bash
git clone git@github.com:Liuluuuu/PMDetector.git
cd PMDetector
pip install -e .
```

## Usage

### Command Line Interface

```bash
# Analyze a contract by Ethereum address
python main.py --contract-address 0x123456789abcdef... --platform ETH

# Analyze a contract on a different blockchain
python main.py --contract-address 0x123456789abcdef... --platform BSC

# Analyze a Solidity source file
python main.py --source-code path/to/contract.sol
```

Supported platforms include:
- ETH (Ethereum)
- Base
- BSC (Binance Smart Chain)
- ARB (Arbitrum)
- Polygon

### Project Structure

```
PMDetector/
├── main.py                           # Main entry point
├── cleanup_flattened_contracts.py    # Helper for cleaning contract files
├── setup.py                          # Package setup
├── requirements.txt                  # Dependencies
├── pmdetector/
│   ├── __init__.py
│   ├── core/
│   │   ├── __init__.py
│   │   ├── detector.py               # Taint analysis detector
│   │   ├── taint_source.py           # Taint source definitions
│   │   ├── taint_sink.py             # Taint sink definitions
│   │   ├── taint_result.py           # Taint analysis results
│   │   ├── constants.py              # Constants and configurations
│   │   └── sanity_checker.py         # Rule-based sanity checker
│   ├── llm/
│   │   ├── __init__.py
│   │   ├── multi_agents.py           # Multi-agent LLM analyzer
│   │   ├── path_abstraction.py       # Converts taint paths to text
│   │   ├── path_analyzer.py          # Analyzes individual paths
│   │   ├── path_grouping.py          # Groups related paths
│   │   ├── path_parser.py            # Parses taint path information
│   │   ├── llm_analyzer.py           # Base LLM analyzer
│   │   ├── llm_service.py            # LLM API service
│   │   └── narrative_generator.py    # Generates vulnerability narratives
│   ├── utils/
│   │   ├── __init__.py
│   │   ├── blockchain.py             # Blockchain interaction utilities
│   │   ├── ethereum.py               # Ethereum-specific utilities
│   │   └── symbolic_analysis_utils.py # Symbolic analysis helpers
│   └── experiments/
│       ├── __init__.py
│       ├── process_dataset.py        # Dataset processing utilities
│       └── analyze_results.py        # Results analysis utilities
├── analysis_results/                 # Taint analysis results
├── flattened_contracts/              # Flattened contract source code
└── taint_paths_with_source/          # Taint paths with source context
```

## Acknowledgments

- [Slither](https://github.com/crytic/slither) - The Solidity source code analyzer
