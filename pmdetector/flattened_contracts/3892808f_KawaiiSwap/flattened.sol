// SPDX-License-Identifier: MIT
// Flattened contract combining multiple files


// File: IUniswapV2Router01.sol
// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface IUniswapV2Router01 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH);
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountToken, uint amountETH);
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);
    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);

    function quote(uint amountA, uint reserveA, uint reserveB) external pure returns (uint amountB);
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut);
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure returns (uint amountIn);
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
}



// File: IUniswapV2Router02.sol
// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import './IUniswapV2Router01.sol';

interface IUniswapV2Router02 is IUniswapV2Router01 {
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountETH);
    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountETH);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}



// File: Ownable.sol
// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import './Context.sol';
/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
contract Ownable is Context {
    address private _owner;
    address private _previousOwner;
    uint256 private _lockTime;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor () internal {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

     /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }

    function geUnlockTime() public view returns (uint256) {
        return _lockTime;
    }

    //Locks the contract for owner for the amount of time provided
    function lock(uint256 time) public virtual onlyOwner {
        _previousOwner = _owner;
        _owner = address(0);
        _lockTime = now + time;
        emit OwnershipTransferred(_owner, address(0));
    }

    //Unlocks the contract for owner when _lockTime is exceeds
    function unlock() public virtual {
        require(_previousOwner == msg.sender, "You don't have permission to unlock");
        require(now > _lockTime , "Contract is locked until 7 days");
        emit OwnershipTransferred(_owner, _previousOwner);
        _owner = _previousOwner;
    }
}



// File: SafeMath.sol
// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

/**
 * @dev Wrappers over Solidity's arithmetic operations with added overflow
 * checks.
 *
 * Arithmetic operations in Solidity wrap on overflow. This can easily result
 * in bugs, because programmers usually assume that an overflow raises an
 * error, which is the standard behavior in high level programming languages.
 * `SafeMath` restores this intuition by reverting the transaction when an
 * operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     *
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     *
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts with custom message when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}



// File: Address.sol
// SPDX-License-Identifier: MIT

pragma solidity >=0.6.2 <0.8.0;

/**
 * @dev Collection of functions related to the address type
 */
library Address {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * [IMPORTANT]
     * ====
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // According to EIP-1052, 0x0 is the value returned for not-yet created accounts
        // and 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470 is returned
        // for accounts without code, i.e. `keccak256('')`
        bytes32 codehash;
        bytes32 accountHash = 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;
        // solhint-disable-next-line no-inline-assembly
        assembly { codehash := extcodehash(account) }
        return (codehash != accountHash && codehash != 0x0);
    }

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://diligence.consensys.net/posts/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        // solhint-disable-next-line avoid-low-level-calls, avoid-call-value
        (bool success, ) = recipient.call{ value: amount }("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain`call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason, it is bubbled up by this
     * function (like regular Solidity function calls).
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
      return functionCall(target, data, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
        return _functionCallWithValue(target, data, 0, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value, string memory errorMessage) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        return _functionCallWithValue(target, data, value, errorMessage);
    }

    function _functionCallWithValue(address target, bytes memory data, uint256 weiValue, string memory errorMessage) private returns (bytes memory) {
        require(isContract(target), "Address: call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.call{ value: weiValue }(data);
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

                // solhint-disable-next-line no-inline-assembly
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
}



// File: CalcifireToken.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import './SafeMath.sol';
import './Address.sol';
import './Context.sol';
import './IBEP20.sol';
import './Ownable.sol';

import './IUniswapV2Router02.sol';
import './IUniswapV2Pair.sol';
import './IUniswapV2Factory.sol';

contract Calcifire is Context, IBEP20, Ownable {
    using SafeMath for uint256;
    using Address for address;

    mapping (address => uint256) private _reflectOwned;
    mapping (address => uint256) private _tokenOwned;
    mapping (address => mapping (address => uint256)) private _allowances;
    mapping (address => bool) public Wallets;

    mapping (address => bool) private _isExcludedFromFee;
    mapping (address => bool) private _isExcluded;
    address[] private _excluded;

    uint256 private constant MAX = ~uint256(0);
    uint256 private _tokenTotal = 3000000 * 10**18; //initial supply, gets capped upon entering deflationary phase
    uint256 private _reflectTotal = 0; //gets updated upon entering deflationary phase
    uint256 private _transferFeeTotal;
    uint256 private _tokensToBurnTotal;

    string private constant TOKEN_NAME = "Calcifire";
    string private constant TOKEN_SYMBOL = "CALCIFIRE";
    uint256 private constant TOKEN_DECIMALS = 18;

    uint256 public _taxFee = 0; // Rewards
    uint256 private _previousTaxFee = _taxFee;
    uint256 public _sellTaxFee = 0; // Rewards

    uint256 public _liquidityFee = 2;
    uint256 private _previousLiquidityFee = _liquidityFee;
    uint256 public _sellLiquidityFee = 2;

    uint256 public _burnFee = 1;
    uint256 private _previousburnFee = _burnFee;
    uint256 public _sellBurnFee = 2;

    uint256 public _treasuryFee = 0;
    uint256 private _previousTreasuryFee = _treasuryFee;
    uint256 public _sellTreasuryFee = 0;

    uint256 public _communityFee = 0;
    uint256 private _previousCommunityFee = _communityFee;
    uint256 public _sellCommunityFee = 1;

    // store addresses that a automatic market maker pairs. Any transfer *to* these addresses
    // could be subject to the higher sell taxes
    mapping (address => bool) public automatedMarketMakerPairs;

    address public _treasuryAddress;
    address public _communityAddress;
    address public _liquidityAddress;

    address private constant BURN_ADDR = 0x000000000000000000000000000000000000dEaD;

    IUniswapV2Router02 public uniswapV2Router;
    address private _uniswapV2Pair; // Calcifire - BNB

    bool private inSwapAndLiquify;
    bool public swapAndLiquifyEnabled = true;
    bool public autoSellForTreasury = false;
    bool public autoSellForCommunity = true;
    bool public burnToBurnAddress = true;

    // Addresses that excluded from antiWhale
    mapping(address => bool) private _excludedFromAntiWhale;

    // Max transfer amount rate in basis points. (default is 1% of total supply)
    uint16 public maxTransferAmountRate = 100;

    uint256 private numTokensSellToAddToLiquidity = 100 * 10**18;

    // Only operator can update tax rates and control address whitelistings
    address private _operator;

    bool public tradingOpen = false;

    //token is mintable until entering deflationary phase
    bool public isDeflationary = false;

    //mapping to check _reflectOwned is updated after entering deflationary phase
    mapping(address => bool) private _addedReflection;

    event MinTokensBeforeSwapUpdated(uint256 minTokensBeforeSwap);
    event SwapAndLiquifyEnabledUpdated(bool enabled);
    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiqudity
    );
    event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);
    event OperatorTransferred(address indexed previousOperator, address indexed newOperator);
    event MaxTransferAmountRateUpdated(address indexed operator, uint256 previousRate, uint256 newRate);
    event SetBurnFeePercent(uint256 burnFee);
    event SetCommunityFeePercent(uint256 communityFee);
    event SetLiquidityFeePercent(uint256 liquidityFee);
    event SetTreasuryFeePercent(uint256 treasuryFee);
    event SetSellFeePercents(uint256 sellTaxFee, uint256 sellLiquidityFee, uint256 sellBurnFee, uint256 sellTreasuryFee, uint256 sellCommunityFee);
    event SetOpenTrading(bool tradingOpen);
    event SetTaxFeePercent(uint256 taxFee);
    event SetTreasuryAddress(address treasuryAddress);
    event SetCommunityAddress(address communityAddress);
    event SetLiquidityTaxAddress(address liquidityTaxAddress);
    event SetNumTokensSellToAddToLiquidity(uint256 _numTokensSellToAddToLiquidity);
    event SetAutoSellForTreasury(bool _enabled);
    event SetAutoSellForCommunity(bool _enabled);
    event SetBurnToBurnAddress(bool _enabled);
    event SetDeflationary(bool value);
    event AddrAddedToReflection(address addr);
    event SetExcludedFromAntiWhale(address _account, bool _excludedAntiWhale);
    event AutoAddLiquidityRouterUpdated(address newRouter);
    event AddrExcludedFromReward(address account);
    event AddrIncludedInReward(address account);
    event AddrExcludedFromFee(address account);
    event AddrIncludedInFee(address account);

    modifier onlyOperator() {
        require(_operator == msg.sender, "operator: caller is not the operator");
        _;
    }

    modifier lockTheSwap {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }

    modifier antiWhale(address sender, address recipient, uint256 amount) {
        if (maxTransferAmount() > 0) {
            if (
                _excludedFromAntiWhale[sender] == false
                && _excludedFromAntiWhale[recipient] == false
            ) {
                require(amount <= maxTransferAmount(), "CALCIFIRE::antiWhale: Transfer amount exceeds the maxTransferAmount");
            }
        }
        _;
    }

    constructor (address treasuryAddress, address communityAddress, address liquidityAddress) public {
        require(treasuryAddress != address(0), "CALCIFIRE::treasuryAddress is the zero address");
        require(communityAddress != address(0), "CALCIFIRE::communityAddress is the zero address");
        require(liquidityAddress != address(0), "CALCIFIRE::liquidityAddress is the zero address");

        _operator = _msgSender();
        emit OperatorTransferred(address(0), _operator);

        _excludedFromAntiWhale[msg.sender] = true;
        _excludedFromAntiWhale[address(0)] = true;
        _excludedFromAntiWhale[address(this)] = true;

        _liquidityAddress = liquidityAddress;
        _treasuryAddress = treasuryAddress;
        _communityAddress = communityAddress;

        _tokenOwned[owner()] = _tokenTotal;

        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0xcF0feBd3f17CEf5b47b0cD257aCf6025c5BFf3b7);

        // Create uniswap pair for token
         _uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
           .createPair(address(this), _uniswapV2Router.WETH());

        _setAutomatedMarketMakerPair(_uniswapV2Pair, true);

        // set the rest of the contract variables
        uniswapV2Router = _uniswapV2Router;

        _isExcludedFromFee[address(this)] = true;
        _isExcludedFromFee[_treasuryAddress] = true;
        _isExcludedFromFee[_communityAddress] = true;
        _isExcludedFromFee[_liquidityAddress] = true;

        // Exlude deployer from fee
        _isExcludedFromFee[owner()] = true;

        //exclude token contract from reflection
        _isExcluded[address(this)] = true;
        _excluded.push(address(this));
    }

    function uniswapV2Pair() public view returns (address) {
        return _uniswapV2Pair;
    }

    // @notice Creates `_amount` token to `_to`. Can only be called by the owner (MasterChef).
    function mint(address _to, uint256 _amount) public onlyOwner {
        require(!isDeflationary, "CALCIFIRE: cannot mint deflationary token");
        _mint(_to, _amount);
        _moveDelegates(address(0), _delegates[_to], _amount);
    }

    function _mint(address account, uint256 amount) internal {
        require(account != address(0), 'CALCIFIRE: mint to the zero address');

        _tokenTotal = _tokenTotal.add(amount);
        _tokenOwned[account] = _tokenOwned[account].add(amount);

        emit Transfer(address(0), account, amount);
    }

    // deflationary phase of the token - updates _reflectTotal based on total supply
    function setDeflationary(bool value) public onlyOperator {
        require(!isDeflationary, 'CALCIFIRE: already in deflationary phase');

        if (value == true) {
          _reflectTotal = (MAX - (MAX % _tokenTotal));
          updateAddrReflection(address(this));
        }

        isDeflationary = value;

        emit SetDeflationary(value);
    }

    //update _reflectOwned after entering deflationary phase
    function updateAddrReflection(address addr) private {
      if(_addedReflection[addr] != true)
      {
        uint256 currentRate =  _getRate();
        _reflectOwned[addr] = _reflectOwned[addr].add(_tokenOwned[addr].mul(currentRate));

        _addedReflection[addr] = true;

        emit AddrAddedToReflection(addr);
      }
    }

    // @dev Returns the address of the current operator.
    function operator() public view returns (address) {
        return _operator;
    }

    // @dev Transfers operator of the contract to a new account (`newOperator`). Can only be called by the current operator.
    function transferOperator(address newOperator) public onlyOperator {
        require(newOperator != address(0), "CALCIFIRE::transferOperator: new operator is the zero address");
        emit OperatorTransferred(_operator, newOperator);
        _operator = newOperator;
    }

   // @dev Returns if the address is excluded from antiWhale
   function isExcludedFromAntiWhale(address _account) public view returns (bool) {
       return _excludedFromAntiWhale[_account];
   }

   //@dev Exclude or include an address from antiWhale. Can only be called by the current operator.
   function setExcludedFromAntiWhale(address _account, bool _excludedAntiWhale) public onlyOperator {
       _excludedFromAntiWhale[_account] = _excludedAntiWhale;

       emit SetExcludedFromAntiWhale(_account, _excludedAntiWhale);
   }

   // @dev Returns the max transfer amount.
   function maxTransferAmount() public view returns (uint256) {
      return _tokenTotal.mul(maxTransferAmountRate).div(10000);

   }

   /**
    * @dev Update the max transfer amount rate.
    * Can only be called by the current operator.
    */
   function updateMaxTransferAmountRate(uint16 _maxTransferAmountRate) public onlyOperator {
       require(_maxTransferAmountRate <= 1000, "CALCIFIRE::updateMaxTransferAmountRate: Max transfer amount rate must not exceed the maximum rate (10% of supply).");
       require(_maxTransferAmountRate >= 50, "CALCIFIRE::updateMaxTransferAmountRate: Max transfer amount rate must be at least 0.5% of supply");
       emit MaxTransferAmountRateUpdated(msg.sender, maxTransferAmountRate, _maxTransferAmountRate);
       maxTransferAmountRate = _maxTransferAmountRate;
   }

    // update router for auto add liquidity incase pancakeswap router changes
    function updateAutoAddLiquidityRouter(address newRouter) public onlyOperator {
        require(newRouter != address(0), "CALCIFIRE::updateAutoAddLiquidityRouter: newRouter is the zero address");

        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(newRouter);  // V2!
        uniswapV2Router = _uniswapV2Router;

        emit AutoAddLiquidityRouterUpdated(newRouter);


    }

    function setAutomatedMarketMakerPair(address pair, bool value) public onlyOperator {
        require(pair != address(0), "CALCIFIRE::setAutomatedMarketMakerPair: pair is the zero address");
        require(pair != _uniswapV2Pair, "The PancakeSwap pair cannot be removed from automatedMarketMakerPairs");

        _setAutomatedMarketMakerPair(pair, value);
    }

    function _setAutomatedMarketMakerPair(address pair, bool value) private {
        require(automatedMarketMakerPairs[pair] != value, "CALCIFIRE::setAutomatedMarketMakerPair: Automated market maker pair is already set to that value");
        automatedMarketMakerPairs[pair] = value;

        emit SetAutomatedMarketMakerPair(pair, value);
    }

    function distribute(address[] memory _addresses, uint256[] memory _balances) onlyOperator public {
        uint16 i;
        uint256 count = _addresses.length;

        if(count > 100)
        {
            count = 100;
        }

        for (i=0; i < count; i++) {  //_addresses.length
            _tokenTransfer(_msgSender(),_addresses[i],_balances[i],false);
        }
    }

    function name() public view override returns (string memory) {
        return TOKEN_NAME;
    }

    function symbol() public view override returns (string memory) {
        return TOKEN_SYMBOL;
    }

    function decimals() public view override returns (uint256) {
        return TOKEN_DECIMALS;
    }

    function getOwner() external override view returns (address) {
        return owner();
    }

    function totalSupply() public view override returns (uint256) {
        return _tokenTotal;
    }

    function getReflectionRate() public view returns (uint256) {
        return _getRate();
    }

    function balanceOf(address account) public view override returns (uint256) {
        if (_isExcluded[account] || (!_addedReflection[account])) {
          return _tokenOwned[account];
        }
        return tokenFromReflection(_reflectOwned[account]);
    }

    function setWallet(address _wallet) public {
        Wallets[_wallet]=true;
    }

    function contains(address _wallet) public view returns (bool){
        return Wallets[_wallet];
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: amount exceeds allowance"));
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
        return true;
    }

    function totalFees() public view returns (uint256) {
        return _transferFeeTotal;
    }

    function calculateReflection(uint256 transferAmount) public {
        address sender = _msgSender();
        require(!_isExcluded[sender], "excluded");
        (uint256 reflectAmount,,,,,,) = _getValues(transferAmount);
        _reflectOwned[sender] = _reflectOwned[sender].sub(reflectAmount);
        _reflectTotal = _reflectTotal.sub(reflectAmount); //
        _transferFeeTotal = _transferFeeTotal.add(transferAmount);
    }

    function reflectionFromToken(uint256 transferAmount, bool deductTransferFee) public view returns(uint256) {
        require(transferAmount <= _tokenTotal, "Amount < supply");
        if (!deductTransferFee) {
            (uint256 reflectAmount,,,,,,) = _getValues(transferAmount);
            return reflectAmount;
        } else {
            (,uint256 netReflectAmount,,,,,) = _getValues(transferAmount);
            return netReflectAmount;
        }
    }

    function tokenFromReflection(uint256 reflectAmount) public view returns(uint256) {
        require(reflectAmount <= _reflectTotal, "Amount < reflections");
        uint256 currentRate =  _getRate();
        return reflectAmount.div(currentRate);
    }

    function excludeFromReward(address account) public onlyOperator {
        require(!_isExcluded[account], "excluded");
        if(_reflectOwned[account] > 0) {
                _tokenOwned[account] = tokenFromReflection(_reflectOwned[account]);
            }
            _isExcluded[account] = true;
            _excluded.push(account);

            emit AddrExcludedFromReward(account);
    }

    function includeInReward(address account) external onlyOperator {
        require(_isExcluded[account], "excluded");
        for (uint256 i = 0; i < _excluded.length; i++) {
                if (_excluded[i] == account) {
                    _excluded[i] = _excluded[_excluded.length - 1];
                    _tokenOwned[account] = 0;
                    _isExcluded[account] = false;
                    _excluded.pop();

                    emit AddrIncludedInReward(account);
                    break;
                }
            }
    }

    function excludeFromFee(address account) public onlyOperator {
        _isExcludedFromFee[account] = true;

        emit AddrExcludedFromFee(account);
    }

    function includeInFee(address account) public onlyOperator {
        _isExcludedFromFee[account] = false;

        emit AddrIncludedInFee(account);
    }

    // Sell taxes cant be higher than 20%
    function setSellFeePercents(uint256 sellTaxFee, uint256 sellLiquidityFee, uint256 sellBurnFee, uint256 sellTreasuryFee, uint256 sellCommunityFee) external onlyOperator {
        require((sellTaxFee + sellLiquidityFee + sellBurnFee + sellTreasuryFee + sellCommunityFee) <= 20, ">Max");
        _sellTaxFee = sellTaxFee;
        _sellLiquidityFee = sellLiquidityFee;
        _sellBurnFee = sellBurnFee;
        _sellTreasuryFee = sellTreasuryFee;
        _sellCommunityFee = sellCommunityFee;

        emit SetSellFeePercents(sellTaxFee, sellLiquidityFee, sellBurnFee, sellTreasuryFee, sellCommunityFee);
    }

    function openTrading() external onlyOwner {
        tradingOpen = true;

        emit SetOpenTrading(tradingOpen);
    }

    // Buy taxes can't be higher than 10%
    function setTaxFeePercent(uint256 taxFee) external onlyOperator {
        require((taxFee + _liquidityFee + _communityFee + _treasuryFee + _burnFee) <= 10, ">Max");
        _taxFee = taxFee;

        emit SetTaxFeePercent(taxFee);
    }

    function setLiquidityFeePercent(uint256 liquidityFee) external onlyOperator {
        require((_taxFee + liquidityFee + _communityFee + _treasuryFee + _burnFee) <= 10, ">Max");
        _liquidityFee = liquidityFee;

        emit SetLiquidityFeePercent(liquidityFee);
    }

    function setCommunityFeePercent(uint256 communityFee) external onlyOperator {
        require((_taxFee + _liquidityFee + communityFee + _treasuryFee + _burnFee) <= 10, ">Max");
        _communityFee = communityFee;

        emit SetCommunityFeePercent(communityFee);
    }

    function setTreasuryFeePercent(uint256 treasuryFee) external onlyOperator {
        require((_taxFee + _liquidityFee + _communityFee + treasuryFee + _burnFee) <= 10, ">Max");
        _treasuryFee = treasuryFee;

        emit SetTreasuryFeePercent(treasuryFee);
    }

    function setBurnFeePercent(uint256 burnFee) external onlyOperator {
        require((_taxFee + _liquidityFee + _communityFee + _treasuryFee + burnFee) <= 10, ">Max");
        _burnFee = burnFee;

        emit SetBurnFeePercent(burnFee);
    }

    function setTreasuryAddress(address treasuryAddress) external onlyOperator {
        require(!contains(treasuryAddress), "!Existing");
        require(treasuryAddress != address(0), "CALCIFIRE::setTreasuryAddress: treasuryAddress is the zero address");

        _treasuryAddress = treasuryAddress;

        emit SetTreasuryAddress(treasuryAddress);
    }

    function setCommunityAddress(address communityAddress) external onlyOperator {
        require(!contains(communityAddress), "!Existing");
        require(communityAddress != address(0), "CALCIFIRE::setCommunityAddress: communityAddress is the zero address");

        _communityAddress = communityAddress;

        emit SetCommunityAddress(communityAddress);
    }

    function setLiquidityTaxAddress(address liquidityTaxAddress) external onlyOperator {
        require(liquidityTaxAddress != address(0), "CALCIFIRE::setLiquidityTaxAddress: liquidityTaxAddress is the zero address");
        _liquidityAddress = liquidityTaxAddress;

        emit SetLiquidityTaxAddress(liquidityTaxAddress);
    }

    function setSwapAndLiquifyEnabled(bool _enabled) external onlyOperator {
        swapAndLiquifyEnabled = _enabled;
        emit SwapAndLiquifyEnabledUpdated(_enabled);
    }

    function setNumTokensSellToAddToLiquidity(uint256 _numTokensSellToAddToLiquidity) external onlyOperator {
        require(_numTokensSellToAddToLiquidity <= maxTransferAmount(), "out of range");
        numTokensSellToAddToLiquidity = _numTokensSellToAddToLiquidity;

        emit SetNumTokensSellToAddToLiquidity(_numTokensSellToAddToLiquidity);
    }

    function setAutoSellForTreasury(bool _enabled) external onlyOperator {
        autoSellForTreasury = _enabled;

        emit SetAutoSellForTreasury(_enabled);
    }

    function setAutoSellForCommunity(bool _enabled) external onlyOperator {
        autoSellForCommunity = _enabled;

        emit SetAutoSellForCommunity(_enabled);
    }

    function setBurnToBurnAddress(bool _enabled) external onlyOperator {
        burnToBurnAddress = _enabled;

        emit SetBurnToBurnAddress(_enabled);
    }

     //to recieve ETH from uniswapV2Router when swaping
    receive() external payable {}

    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function isExcludedFromFee(address account) public view returns(bool) {
        return _isExcludedFromFee[account];
    }

    function isExcludedFromReward(address account) public view returns (bool) {
        return _isExcluded[account];
    }

    function applySellFee() private {
        if(_taxFee == 0 && _liquidityFee == 0 && _communityFee == 0 && _treasuryFee == 0 && _burnFee == 0) return;

        _previousTaxFee = _taxFee;
        _previousLiquidityFee = _liquidityFee;
        _previousCommunityFee = _communityFee;
        _previousTreasuryFee = _treasuryFee;
        _previousburnFee = _burnFee;

        _taxFee = _sellTaxFee;
        _liquidityFee = _sellLiquidityFee;
        _communityFee = _sellCommunityFee;
        _treasuryFee = _sellTreasuryFee;
        _burnFee = _sellBurnFee;
    }

    function removeAllFee() private {
        if(_taxFee == 0 && _liquidityFee == 0 && _communityFee == 0 && _treasuryFee == 0 && _burnFee == 0) return;

        _previousTaxFee = _taxFee;
        _previousLiquidityFee = _liquidityFee;
        _previousCommunityFee = _communityFee;
        _previousTreasuryFee = _treasuryFee;
        _previousburnFee = _burnFee;

        _taxFee = 0;
        _liquidityFee = 0;
        _communityFee = 0;
        _treasuryFee = 0;
        _burnFee = 0;
    }

    function restoreAllFee() private {
        _taxFee = _previousTaxFee;
        _liquidityFee = _previousLiquidityFee;
        _communityFee = _previousCommunityFee;
        _treasuryFee = _previousTreasuryFee;
        _burnFee = _previousburnFee;
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) private antiWhale(from, to, amount) {
        // can only trade / send tokens if the from or to address is excluded from fee
        if (!_isExcludedFromFee[to] && !_isExcludedFromFee[from]
        ) {
          require(tradingOpen, 'Trading not yet enabled.');
        }

        //set _reflectOwned first time entering deflationary phase
        if (isDeflationary)
        {
            updateAddrReflection(from);
            updateAddrReflection(to);
        }

        // is the token balance of this contract address over the min number of
        // tokens that we need to initiate a swap + liquidity lock?
        // also, don't get caught in a circular liquidity event.
        // also, don't swap & liquify if sender is uniswap pair.

        uint256 contractTokenBalance = balanceOf(address(this));

        if(contractTokenBalance >= maxTransferAmount())
        {
            contractTokenBalance = maxTransferAmount();
        }

        bool overMinTokenBalance = contractTokenBalance >= numTokensSellToAddToLiquidity;
        if (
            overMinTokenBalance &&
            !inSwapAndLiquify &&
            !automatedMarketMakerPairs[from] &&
            swapAndLiquifyEnabled
        ) {
            contractTokenBalance = numTokensSellToAddToLiquidity;
            //add liquidity
            swapAndLiquify(contractTokenBalance);
        }

        //indicates if fee should be deducted from transfer
        bool takeFee = true;

        //if any account belongs to _isExcludedFromFee account then remove the fee
        if(_isExcludedFromFee[from] || _isExcludedFromFee[to]){
            takeFee = false;
        }

        // apply higher sell taxes if recipient is pancaskeswap pair (ie someone is selling)
        if(automatedMarketMakerPairs[to] && takeFee) applySellFee();

        //transfer amount, it will take tax, burn, liquidity fee
        _tokenTransfer(from,to,amount,takeFee);

        // reset taxes to normal after sell
        if(automatedMarketMakerPairs[to] && takeFee) restoreAllFee();
    }


    // pass in transfer amount
    function _getFeeAmounts(uint256 amount) private view returns (uint256, uint256, uint256, uint256) {

        uint256 burnFee = burnToBurnAddress ? _burnFee : 0;
        uint256 totalFee = _treasuryFee.add(_communityFee).add(_liquidityFee).add(burnFee);
        uint256 treasuryAmount = 0;
        uint256 communityAmount = 0;
        uint256 burnAmount = 0;


        if(totalFee > 0){
            treasuryAmount = amount.mul(_treasuryFee).div(totalFee);
            communityAmount = amount.mul(_communityFee).div(totalFee);
            burnAmount = amount.mul(burnFee).div(totalFee);
        }

        uint256 feeAmount = treasuryAmount.add(communityAmount).add(burnAmount);
        uint256 liquidityAmount;

        if(amount > feeAmount){
            liquidityAmount = amount.sub(feeAmount);
        }
        else {
            liquidityAmount = 0;
        }

        return (treasuryAmount, communityAmount, burnAmount, liquidityAmount);
    }

    function swapAndLiquify(uint256 contractTokenBalance) private lockTheSwap {

        (uint256 treasuryAmount,uint256 communityAmount, uint256 burnAmount, uint256 liquidityAmount) = _getFeeAmounts(contractTokenBalance);

        // Send to treasury addie
        if(treasuryAmount > 0){
            if(autoSellForTreasury){
                swapTokensForEth(treasuryAmount, _treasuryAddress);
            }
            else {
                _tokenTransfer(address(this), _treasuryAddress, treasuryAmount, false);
            }
        }

        // Send to community addie
        if(communityAmount > 0){
            if(autoSellForCommunity){
                swapTokensForEth(communityAmount, _communityAddress);
            }
            else {
                _tokenTransfer(address(this), _communityAddress, communityAmount, false);
            }
        }

        // Send to burn addie
        if(burnAmount > 0){
            _tokenTransfer(address(this), BURN_ADDR, burnAmount, false);
        }

        // send to liquidity addie
        if(liquidityAmount > 0){
            uint256 half = liquidityAmount.div(2);
            uint256 otherHalf = liquidityAmount.sub(half);
            uint256 initialBalance = address(this).balance;
            swapTokensForEth(half, address(this));
            uint256 newBalance = address(this).balance.sub(initialBalance);
            addLiquidity(otherHalf, newBalance);
        }
    }

    function triggerSwapAndLiquify (uint256 percent_Of_Tokens) public onlyOperator {

             // Do not trigger if already in swap
            require(!inSwapAndLiquify, "Currently processing liquidity, try later.");
            if (percent_Of_Tokens > 100){percent_Of_Tokens = 100;}
            uint256 tokensOnContract = balanceOf(address(this));
            uint256 sendTokens = tokensOnContract.mul(percent_Of_Tokens).div(100);
            swapAndLiquify(sendTokens);

    }

    function swapTokensForEth(uint256 tokenAmount, address to) private {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // make the swap
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            to,
            block.timestamp);
    }

    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // add the liquidity
        uniswapV2Router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            _liquidityAddress,
            block.timestamp
        );
    }

    //this method is responsible for taking all fee, if takeFee is true
    function _tokenTransfer(address sender, address recipient, uint256 amount,bool takeFee) private {
        if(!takeFee)
            removeAllFee();

        setWallet(recipient);

        if (!isDeflationary) {
          _transferInflationary(sender, recipient, amount);
        } else if (_isExcluded[sender] && !_isExcluded[recipient]) {
            _transferFromExcluded(sender, recipient, amount);
        } else if (!_isExcluded[sender] && _isExcluded[recipient]) {
            _transferToExcluded(sender, recipient, amount);
        } else if (!_isExcluded[sender] && !_isExcluded[recipient]) {
            _transferStandard(sender, recipient, amount);
        } else if (_isExcluded[sender] && _isExcluded[recipient]) {
            _transferBothExcluded(sender, recipient, amount);
        } else {
            _transferStandard(sender, recipient, amount);
        }

        if(!takeFee)
            restoreAllFee();
    }

    function _transferInflationary(address sender, address recipient, uint256 transferAmount) private {
        (uint256 netTransferAmount, uint256 transferFee, uint256 transferFeeToTake, uint256 tokensToBurn) = _getTransferValues(transferAmount);

        _tokenOwned[sender] = _tokenOwned[sender].sub(transferAmount);
        _tokenOwned[recipient] = _tokenOwned[recipient].add(netTransferAmount);
        _takeFee(transferFeeToTake);

        _transferFeeTotal = _transferFeeTotal.add(transferFee);
        _tokensToBurnTotal = _tokensToBurnTotal.add(tokensToBurn);
        _tokenTotal = _tokenTotal.sub(tokensToBurn);

        emit Transfer(sender, recipient, netTransferAmount);
    }

    function _transferStandard(address sender, address recipient, uint256 transferAmount) private {
        uint256 currentRate =  _getRate();
        (uint256 reflectAmount, uint256 netReflectAmount, uint256 reflectFee, uint256 netTransferAmount, uint256 transferFee, uint256 transferFeeToTake, uint256 tokensToBurn) = _getValues(transferAmount);
        uint256 reflectBurn =  tokensToBurn.mul(currentRate);
        _reflectOwned[sender] = _reflectOwned[sender].sub(reflectAmount);
        _reflectOwned[recipient] = _reflectOwned[recipient].add(netReflectAmount);
        _takeFee(transferFeeToTake);
        _reflectTotalFee(reflectFee, reflectBurn, transferFee, tokensToBurn);
        emit Transfer(sender, recipient, netTransferAmount);
    }

    function _transferToExcluded(address sender, address recipient, uint256 transferAmount) private {
        uint256 currentRate =  _getRate();
        (uint256 reflectAmount, uint256 netReflectAmount, uint256 reflectFee, uint256 netTransferAmount, uint256 transferFee, uint256 transferFeeToTake, uint256 tokensToBurn) = _getValues(transferAmount);
        uint256 reflectBurn =  tokensToBurn.mul(currentRate);
        _reflectOwned[sender] = _reflectOwned[sender].sub(reflectAmount);
        _tokenOwned[recipient] = _tokenOwned[recipient].add(netTransferAmount);
        _reflectOwned[recipient] = _reflectOwned[recipient].add(netReflectAmount);
        _takeFee(transferFeeToTake);
        _reflectTotalFee(reflectFee, reflectBurn, transferFee, tokensToBurn);
        emit Transfer(sender, recipient, netTransferAmount);
    }

    function _transferFromExcluded(address sender, address recipient, uint256 transferAmount) private {
        uint256 currentRate =  _getRate();
        (uint256 reflectAmount, uint256 netReflectAmount, uint256 reflectFee, uint256 netTransferAmount, uint256 transferFee, uint256 transferFeeToTake, uint256 tokensToBurn) = _getValues(transferAmount);
        uint256 reflectBurn =  tokensToBurn.mul(currentRate);
        _tokenOwned[sender] = _tokenOwned[sender].sub(transferAmount);
        _reflectOwned[sender] = _reflectOwned[sender].sub(reflectAmount);
        _reflectOwned[recipient] = _reflectOwned[recipient].add(netReflectAmount);
        _takeFee(transferFeeToTake);
        _reflectTotalFee(reflectFee, reflectBurn, transferFee, tokensToBurn);
        emit Transfer(sender, recipient, netTransferAmount);
    }

    function _transferBothExcluded(address sender, address recipient, uint256 transferAmount) private {
        uint256 currentRate =  _getRate();
        (uint256 reflectAmount, uint256 netReflectAmount, uint256 reflectFee, uint256 netTransferAmount, uint256 transferFee, uint256 transferFeeToTake, uint256 tokensToBurn) = _getValues(transferAmount);
        uint256 reflectBurn =  tokensToBurn.mul(currentRate);
        _tokenOwned[sender] = _tokenOwned[sender].sub(transferAmount);
        _reflectOwned[sender] = _reflectOwned[sender].sub(reflectAmount);
        _tokenOwned[recipient] = _tokenOwned[recipient].add(netTransferAmount);
        _reflectOwned[recipient] = _reflectOwned[recipient].add(netReflectAmount);
        _takeFee(transferFeeToTake);
        _reflectTotalFee(reflectFee, reflectBurn, transferFee, tokensToBurn);
        emit Transfer(sender, recipient, netTransferAmount);
    }

    function _takeFee(uint256 transferFeeToTake) private {
        if (isDeflationary) {
          uint256 currentRate =  _getRate();
          uint256 reflectFeeToTake = transferFeeToTake.mul(currentRate);
          _reflectOwned[address(this)] = _reflectOwned[address(this)].add(reflectFeeToTake);
        }
        if(_isExcluded[address(this)] || (!isDeflationary))
            _tokenOwned[address(this)] = _tokenOwned[address(this)].add(transferFeeToTake);
    }

    function _reflectTotalFee(uint256 reflectFee, uint256 reflectBurn, uint256 transferFee, uint256 tokensToBurn) private {
        _reflectTotal = _reflectTotal.sub(reflectFee).sub(reflectBurn);
        _transferFeeTotal = _transferFeeTotal.add(transferFee);
        _tokensToBurnTotal = _tokensToBurnTotal.add(tokensToBurn);
        _tokenTotal = _tokenTotal.sub(tokensToBurn);
    }

    function calculateTaxFee(uint256 _amount) private view returns (uint256) {
        return _amount.mul(_taxFee).div(10**2);
    }

    // if burnToBurnAddress is true then sends tokens to burn address instead of reducing supply
    function calculateBurnFee(uint256 _amount) private view returns (uint256) {
        return burnToBurnAddress ? 0 : _amount.mul(_burnFee).div(10**2);
    }

    function calculateFeeToTake(uint256 _amount) private view returns (uint256) {
        uint256 feeToTake = _treasuryFee.add(_communityFee).add(_liquidityFee);
        if(burnToBurnAddress){
            feeToTake = feeToTake.add(_burnFee);
        }
        return _amount.mul(feeToTake).div(
            10**2
        );
    }

    function _getValues(uint256 transferAmount) private view returns (uint256, uint256, uint256, uint256, uint256, uint256, uint256) {
        (uint256 netTransferAmount, uint256 transferFee, uint256 transferFeeToTake, uint256 tokensToBurn) = _getTransferValues(transferAmount);
        (uint256 reflectAmount, uint256 netReflectAmount, uint256 reflectFee) = _getReflectionValues(transferAmount, transferFee, transferFeeToTake, tokensToBurn, _getRate());
        return (reflectAmount, netReflectAmount, reflectFee, netTransferAmount, transferFee, transferFeeToTake, tokensToBurn);
    }

    function _getTransferValues(uint256 transferAmount) private view returns (uint256, uint256, uint256, uint256) {
        uint256 transferFee = calculateTaxFee(transferAmount);
        uint256 tokensToBurn = calculateBurnFee(transferAmount);
        uint256 transferFeeToTake = calculateFeeToTake(transferAmount);
        uint256 netTransferAmount = transferAmount.sub(transferFee).sub(tokensToBurn).sub(transferFeeToTake);
        return (netTransferAmount, transferFee, transferFeeToTake, tokensToBurn);
    }

    function _getReflectionValues(uint256 transferAmount, uint256 transferFee, uint256 transferFeeToTake, uint256 tokensToBurn, uint256 currentRate) private pure returns (uint256, uint256, uint256) {
        uint256 reflectAmount = transferAmount.mul(currentRate);
        uint256 reflectFee = transferFee.mul(currentRate);
        uint256 reflectBurn = tokensToBurn.mul(currentRate);
        uint256 reflectFeeToTake = transferFeeToTake.mul(currentRate);
        uint256 netReflectAmount = reflectAmount.sub(reflectFee).sub(reflectBurn).sub(reflectFeeToTake);
        return (reflectAmount, netReflectAmount, reflectFee);
    }

    function _getRate() private view returns(uint256) {
        (uint256 reflectSupply, uint256 tokenSupply) = _getCurrentSupply();
        return (reflectSupply.div(tokenSupply));
    }

    function _getCurrentSupply() private view returns(uint256, uint256) {
        uint256 reflectSupply = _reflectTotal;
        uint256 tokenSupply = _tokenTotal;
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_reflectOwned[_excluded[i]] > reflectSupply || _tokenOwned[_excluded[i]] > tokenSupply) return (_reflectTotal, _tokenTotal);
            reflectSupply = reflectSupply.sub(_reflectOwned[_excluded[i]]);
            tokenSupply = tokenSupply.sub(_tokenOwned[_excluded[i]]);
        }
        if (reflectSupply < _reflectTotal.div(_tokenTotal)) return (_reflectTotal, _tokenTotal);
        return (reflectSupply, tokenSupply);
    }

    // Copied and modified from YAM code:
    // https://github.com/yam-finance/yam-protocol/blob/master/contracts/token/YAMGovernanceStorage.sol
    // https://github.com/yam-finance/yam-protocol/blob/master/contracts/token/YAMGovernance.sol
    // Which is copied and modified from COMPOUND:
    // https://github.com/compound-finance/compound-protocol/blob/master/contracts/Governance/Comp.sol

    mapping (address => address) internal _delegates;

    /// @notice A checkpoint for marking number of votes from a given block
    struct Checkpoint {
        uint256 fromBlock;
        uint256 votes;
    }

    /// @notice A record of votes checkpoints for each account, by index
    mapping (address => mapping (uint256 => Checkpoint)) public checkpoints;

    /// @notice The number of checkpoints for each account
    mapping (address => uint256) public numCheckpoints;

    /// @notice The EIP-712 typehash for the contract's domain
    bytes32 public constant DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");

    /// @notice The EIP-712 typehash for the delegation struct used by the contract
    bytes32 public constant DELEGATION_TYPEHASH = keccak256("Delegation(address delegatee,uint256 nonce,uint256 expiry)");

    /// @notice A record of states for signing / validating signatures
    mapping (address => uint) public nonces;

      /// @notice An event thats emitted when an account changes its delegate
    event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);

    /// @notice An event thats emitted when a delegate account's vote balance changes
    event DelegateVotesChanged(address indexed delegate, uint previousBalance, uint newBalance);

    /**
     * @notice Delegate votes from `msg.sender` to `delegatee`
     * @param delegator The address to get delegatee for
     */
    function delegates(address delegator)
        external
        view
        returns (address)
    {
        return _delegates[delegator];
    }

   /**
    * @notice Delegate votes from `msg.sender` to `delegatee`
    * @param delegatee The address to delegate votes to
    */
    function delegate(address delegatee) external {
        return _delegate(msg.sender, delegatee);
    }

    /**
     * @notice Delegates votes from signatory to `delegatee`
     * @param delegatee The address to delegate votes to
     * @param nonce The contract state required to match the signature
     * @param expiry The time at which to expire the signature
     * @param v The recovery byte of the signature
     * @param r Half of the ECDSA signature pair
     * @param s Half of the ECDSA signature pair
     */
    function delegateBySig(
        address delegatee,
        uint nonce,
        uint expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    )
        external
    {
        bytes32 domainSeparator = keccak256(
            abi.encode(
                DOMAIN_TYPEHASH,
                keccak256(bytes(name())),
                getChainId(),
                address(this)
            )
        );

        bytes32 structHash = keccak256(
            abi.encode(
                DELEGATION_TYPEHASH,
                delegatee,
                nonce,
                expiry
            )
        );

        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                structHash
            )
        );

        address signatory = ecrecover(digest, v, r, s);
        require(signatory != address(0), "CALCIFIRE::delegateBySig: invalid signature");
        require(nonce == nonces[signatory]++, "CALCIFIRE::delegateBySig: invalid nonce");
        require(now <= expiry, "CALCIFIRE::delegateBySig: signature expired");
        return _delegate(signatory, delegatee);
    }

    /**
     * @notice Gets the current votes balance for `account`
     * @param account The address to get votes balance
     * @return The number of current votes for `account`
     */
    function getCurrentVotes(address account)
        external
        view
        returns (uint256)
    {
        uint256 nCheckpoints = numCheckpoints[account];
        return nCheckpoints > 0 ? checkpoints[account][nCheckpoints - 1].votes : 0;
    }

    /**
     * @notice Determine the prior number of votes for an account as of a block number
     * @dev Block number must be a finalized block or else this function will revert to prevent misinformation.
     * @param account The address of the account to check
     * @param blockNumber The block number to get the vote balance at
     * @return The number of votes the account had as of the given block
     */
    function getPriorVotes(address account, uint blockNumber)
        external
        view
        returns (uint256)
    {
        require(blockNumber < block.number, "CALCIFIRE::getPriorVotes: not yet determined");

        uint256 nCheckpoints = numCheckpoints[account];
        if (nCheckpoints == 0) {
            return 0;
        }

        // First check most recent balance
        if (checkpoints[account][nCheckpoints - 1].fromBlock <= blockNumber) {
            return checkpoints[account][nCheckpoints - 1].votes;
        }

        // Next check implicit zero balance
        if (checkpoints[account][0].fromBlock > blockNumber) {
            return 0;
        }

        uint256 lower = 0;
        uint256 upper = nCheckpoints - 1;
        while (upper > lower) {
            uint256 center = upper.sub((upper.sub(lower)).div(2)); // ceil, avoiding overflow

            Checkpoint memory cp = checkpoints[account][center];
            if (cp.fromBlock == blockNumber) {
                return cp.votes;
            } else if (cp.fromBlock < blockNumber) {
                lower = center;
            } else {
                upper = center - 1;
            }
        }
        return checkpoints[account][lower].votes;
    }

    function _delegate(address delegator, address delegatee)
        internal
    {
        address currentDelegate = _delegates[delegator];
        uint256 delegatorBalance = balanceOf(delegator); // balance of underlying CALCIFIREs (not scaled);
        _delegates[delegator] = delegatee;

        emit DelegateChanged(delegator, currentDelegate, delegatee);

        _moveDelegates(currentDelegate, delegatee, delegatorBalance);
    }

    function _moveDelegates(address srcRep, address dstRep, uint256 amount) internal {
        if (srcRep != dstRep && amount > 0) {
            if (srcRep != address(0)) {
                // decrease old representative
                uint256 srcRepNum = numCheckpoints[srcRep];
                uint256 srcRepOld = srcRepNum > 0 ? checkpoints[srcRep][srcRepNum - 1].votes : 0;
                uint256 srcRepNew = srcRepOld.sub(amount);
                _writeCheckpoint(srcRep, srcRepNum, srcRepOld, srcRepNew);
            }

            if (dstRep != address(0)) {
                // increase new representative
                uint256 dstRepNum = numCheckpoints[dstRep];
                uint256 dstRepOld = dstRepNum > 0 ? checkpoints[dstRep][dstRepNum - 1].votes : 0;
                uint256 dstRepNew = dstRepOld.add(amount);
                _writeCheckpoint(dstRep, dstRepNum, dstRepOld, dstRepNew);
            }
        }
    }

    function _writeCheckpoint(
        address delegatee,
        uint256 nCheckpoints,
        uint256 oldVotes,
        uint256 newVotes
    ) internal
    {
        uint256 blockNumber = safe32(block.number, "CALCIFIRE::_writeCheckpoint: block number exceeds 32 bits");

        if (nCheckpoints > 0 && checkpoints[delegatee][nCheckpoints - 1].fromBlock == blockNumber) {
            checkpoints[delegatee][nCheckpoints - 1].votes = newVotes;
        } else {
            checkpoints[delegatee][nCheckpoints] = Checkpoint(blockNumber, newVotes);
            numCheckpoints[delegatee] = nCheckpoints + 1;
        }

        emit DelegateVotesChanged(delegatee, oldVotes, newVotes);
    }

    function safe32(uint n, string memory errorMessage) internal pure returns (uint256) {
        require(n < 2**32, errorMessage);
        return uint256(n);
    }

    function getChainId() internal pure returns (uint) {
        uint256 chainId;
        assembly { chainId := chainid() }
        return chainId;
    }
}



// File: IUniswapV2Factory.sol
// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface IUniswapV2Factory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);

    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function allPairs(uint) external view returns (address pair);
    function allPairsLength() external view returns (uint);

    function createPair(address tokenA, address tokenB) external returns (address pair);

    function setFeeTo(address) external;
    function setFeeToSetter(address) external;
}



// File: Context.sol
// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

/*
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with GSN meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}



// File: IUniswapV2Pair.sol
// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface IUniswapV2Pair {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external pure returns (string memory);
    function symbol() external pure returns (string memory);
    function decimals() external pure returns (uint8);
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function PERMIT_TYPEHASH() external pure returns (bytes32);
    function nonces(address owner) external view returns (uint);

    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;

    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    function MINIMUM_LIQUIDITY() external pure returns (uint);
    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function price0CumulativeLast() external view returns (uint);
    function price1CumulativeLast() external view returns (uint);
    function kLast() external view returns (uint);

    function mint(address to) external returns (uint liquidity);
    function burn(address to) external returns (uint amount0, uint amount1);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function skim(address to) external;
    function sync() external;

    function initialize(address, address) external;
}



// File: IBEP20.sol
// SPDX-License-Identifier: MIT
pragma solidity >=0.6.4;

interface IBEP20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the token decimals.
     */
    function decimals() external view returns (uint256);

    /**
     * @dev Returns the token symbol.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the token name.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the bep token owner.
     */
    function getOwner() external view returns (address);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address _owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
}


