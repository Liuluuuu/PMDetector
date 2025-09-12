"""
Constants used by the PMDetector.
This file contains extensible lists that can be easily updated and extended.
"""

# Set of keywords that might indicate a token transfer function
TRANSFER_KEYWORDS = {'transfer', 'send', 'payout', 'withdraw', 'deposit', 'move'}

# Function name indicators for different token operations
TRANSFER_INDICATORS = ['transfer', '_transfer', 'move', 'send', 'transferfrom']
MINT_INDICATORS = ['mint', '_mint', 'create', 'issue']
BURN_INDICATORS = ['burn', '_burn', 'destroy', 'redeem']

# Keywords for identifying balance-related mappings
HIGHEST_SIGNAL_BALANCE_KEYWORDS = ['balance', '_balance', 'credit', 'token', 'amount']
MEDIUM_SIGNAL_BALANCE_KEYWORDS = ['staked', 'locked', 'reward', 'owed', 'share', 'deposit', 'asset']
BALANCE_KEYWORDS = {'balance', 'balances', 'reward', 'rewards', 'deposit', 'deposits', 'stake', 'stakes'}

# Keywords for identifying supply-related parameters
SUPPLY_PARAMETER_KEYWORDS = ['supply', 'cap', 'total', 'amount', 'initial']

# List of functions that are considered price oracle functions
PRICE_ORACLE_FUNCTIONS = {
    # Uniswap V2 and Forks (PancakeSwap, SushiSwap, etc.)
    "getReserves",  # IUniswapV2Pair - returns reserve0, reserve1, blockTimestampLast
    "getAmountsOut",  # IUniswapV2Router02 - returns expected output amounts for a given input
    "getAmountsIn",  # IUniswapV2Router02 - returns required input amount for desired output
    "getAmountOut",  # Single-hop version in some implementations
    "getAmountIn",  # Single-hop version in some implementations
    
    # Uniswap V3
    "slot0",  # IUniswapV3Pool - returns sqrtPriceX96, tick and other data
    "observe",  # IUniswapV3PoolOracle - returns data for TWAP calculation
    "quoteExactInputSingle",  # IQuoter - V3 equivalent of getAmountsOut for single pool
    "quoteExactInput",  # IQuoter - V3 equivalent for multi-pool path
    
    # Curve Finance
    "get_dy",  # ICurvePool - calculates expected output amount
    "get_dy_underlying",  # ICurvePool - for metapools
    "get_virtual_price",  # ICurvePool - returns LP token price relative to underlying
    
    # Chainlink and other oracles
    "latestRoundData",  # Chainlink price feeds
    "consult",  # Various TWAP oracles
    
    # Generic price functions
    "getCurrentPrice",
    "getPrice",
    "getPriceUSD",
    "getSpotPrice",
    "getTWAP",
    
    # Standard Tokens (IERC20)
    "balanceOf",  # IERC20 - returns balance of an account, can be manipulated in malicious tokens
    "totalSupply",  # IERC20 - returns total supply, can be manipulated via flash minting/burning
    
    # Tokenized Vaults (ERC4626)
    "totalAssets",  # IERC4626 - returns total underlying assets in the vault
    "convertToShares",  # IERC4626 - converts asset amount to share amount
    "convertToAssets",  # IERC4626 - converts share amount to asset amount
    "previewDeposit",  # IERC4626 - simulates deposit to show expected shares
    "previewRedeem"  # IERC4626 - simulates redemption to show expected assets
}
