TRANSFER_KEYWORDS = {'transfer', 'send', 'payout', 'withdraw', 'deposit', 'move'}

TRANSFER_INDICATORS = ['transfer', '_transfer', 'move', 'send', 'transferfrom']
MINT_INDICATORS = ['mint', '_mint', 'create', 'issue']
BURN_INDICATORS = ['burn', '_burn', 'destroy', 'redeem']

HIGHEST_SIGNAL_BALANCE_KEYWORDS = ['balance', '_balance', 'credit', 'token', 'amount']
MEDIUM_SIGNAL_BALANCE_KEYWORDS = ['staked', 'locked', 'reward', 'owed', 'share', 'deposit', 'asset']
BALANCE_KEYWORDS = {'balance', 'balances', 'reward', 'rewards', 'deposit', 'deposits', 'stake', 'stakes'}

SUPPLY_PARAMETER_KEYWORDS = ['supply', 'cap', 'total', 'amount', 'initial']

# List of functions that are considered price oracle functions
PRICE_ORACLE_FUNCTIONS = {
    # Uniswap V2 and Forks (PancakeSwap, SushiSwap, etc.)
    "getReserves",  
    "getAmountsOut",  
    "getAmountsIn",  
    "getAmountOut", 
    "getAmountIn",  
    
    # Uniswap V3
    "slot0",  
    "observe",  
    "quoteExactInputSingle",  
    "quoteExactInput",  
    
    # Curve Finance
    "get_dy", 
    "get_dy_underlying", 
    "get_virtual_price",  
    
    # Chainlink and other oracles
    "latestRoundData",  
    "consult",  
    
    # Generic price functions
    "getCurrentPrice",
    "getPrice",
    "getPriceUSD",
    "getSpotPrice",
    "getTWAP",
    
    # Standard Tokens (IERC20)
    "balanceOf",  
    "totalSupply",  
    
    # Tokenized Vaults (ERC4626)
    "totalAssets",  
    "convertToShares",  
    "convertToAssets",  
    "previewDeposit", 
    "previewRedeem"  
}
