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

## Acknowledgments

- [Slither](https://github.com/crytic/slither) - The Solidity source code analyzer
