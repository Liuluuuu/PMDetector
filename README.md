# PMDetector

PMDetector is a taint analysis tool for smart contracts that detects price manipulation vulnerabilities by tracking the flow of tainted data from external sources to sensitive operations.

## Overview

PMDetector analyzes smart contracts to identify vulnerable paths where externally supplied data (taint sources) can influence critical operations (taint sinks) such as asset transfers. This helps identify potential price manipulation vulnerabilities and other security issues in DeFi protocols.

### Key Features

- Analyzes smart contracts from source code, bytecode, or Ethereum addresses
- Identifies taint sources from external contract calls
- Detects taint sinks where assets are transferred
- Tracks taint propagation through data flow and control flow
- Generates detailed reports of vulnerable paths

## Installation

### Prerequisites

- Python 3.8 or higher
- [Slither](https://github.com/crytic/slither) 0.9.0 or higher

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
pmdetector -a 0x123456789abcdef...

# Analyze a Solidity source file
pmdetector -f path/to/contract.sol

# Analyze contract bytecode
pmdetector -b 0x608060405234801...

# Save results to a file
pmdetector -f path/to/contract.sol -o results.json

# Enable verbose output
pmdetector -f path/to/contract.sol --verbose
```

### Python API

```python
from pmdetector.core.detector import TaintDetector

# Create a detector instance
detector = TaintDetector(verbose=True)

# Analyze a contract
result = detector.analyze_file("path/to/contract.sol")

# Check for vulnerabilities
if result.has_vulnerabilities():
    print("Vulnerabilities found!")
    print(result.to_text())
```

## Taint Analysis Methodology

PMDetector implements a taint analysis approach with the following key components:

### Taint Sources

1. Return values from external calls: the return value of a specific, low-level CALL or STATICCALL operation within a transaction that retrieves state from external input.
2. Function Parameters: arguments of non-private functions.

### Taint Sinks

A **Taint Sink** is a state-changing operation that transfers valuable assets (e.g., ETH, ERC-20 tokens) to an address controlled by the attacker, where either:

1. The **amount** of the assets being transferred is a tainted value.
2. The **execution** of the transfer depends on a tainted value (i.e., it occurs within a control flow path determined by a tainted conditional check).

### Propagation Rules

1. **Source Introduction Rule**: Return values from external calls are marked as tainted.
2. **Data Flow Propagation Rule**: Taint propagates through data operations (arithmetic, assignments, etc.).
3. **Persistent State Poisoning Rule**: Taint propagates when tainted values are stored in contract state.
4. **Persistent State Propagation Rule**: Taint propagates when reading from tainted storage slots.
5. **Control Flow Dependency Rule**: Operations in code paths dependent on tainted conditions are considered tainted.
   - The detector tracks control dependencies between nodes in the Control Flow Graph (CFG)
   - When a conditional node (if/require/assert) uses a tainted variable, all nodes that are control-dependent on it are marked as tainted
   - This ensures detection of vulnerabilities where the conditional check and the vulnerable operation are in different CFG nodes

### Price Manipulation Detection

PMDetector is specifically designed to detect price manipulation vulnerabilities in DeFi protocols. These vulnerabilities occur when:

1. A contract relies on an external price feed (oracle) to make critical financial decisions.
2. The price feed can be manipulated by an attacker.
3. The manipulated price affects control flow decisions (e.g., liquidation conditions).
4. The attacker can profit from the resulting state changes.

For example, in a lending protocol, an attacker might:
1. Manipulate the price feed to artificially lower the value of collateral.
2. Trigger liquidations based on the manipulated price.
3. Purchase the liquidated collateral at a discount.
4. Restore the price to its original value and profit from the difference.

PMDetector identifies these vulnerabilities by tracking the flow of tainted data from external price feeds to critical financial operations like liquidations.

## Development

### Project Structure

```
PMDetector/
├── pmdetector/
│   ├── __init__.py
│   ├── main.py
│   ├── core/
│   │   ├── __init__.py
│   │   ├── detector.py
│   │   ├── taint_source.py
│   │   ├── taint_sink.py
│   │   └── taint_result.py
│   ├── utils/
│   │   ├── __init__.py
│   │   └── ethereum.py
│   └── tests/
│       ├── __init__.py
│       └── test_detector.py
└── setup.py
```

### Running Tests

```bash
python -m unittest discover -s pmdetector/tests
```

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- [Slither](https://github.com/crytic/slither) - The Solidity source code analyzer
