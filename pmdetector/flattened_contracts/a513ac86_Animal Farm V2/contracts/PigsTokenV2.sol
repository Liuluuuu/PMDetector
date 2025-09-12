// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";

contract PigsTokenV2 is ERC20, Ownable {
	// The operator can only update the transfer tax rate. See functions with `onlyOperator` modifier for more info
	address private _operator;

	address public constant BUSD_ADDRESS = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;

	uint256 public sellingTax = 30; // 3% tax on selling

	mapping(address => bool) public extraFromMap;
	mapping(address => bool) public extraToMap;

	address public pigsBusdSwapPair;
	address public pigsWbnbSwapPair;

	address public liquidityHelperAddress;
	IUniswapV2Router02 public pancakeswapRouter;

	// AB measures
	mapping(address => bool) private blacklistFrom;
	mapping(address => bool) private blacklistTo;
	mapping(address => bool) private _isExcludedFromLimiter;
	bool private blacklistFeatureAllowed = true;

	bool private transfersPaused = true;
	bool private transfersPausedFeatureAllowed = true;

	bool private sellingEnabled = false;
	bool private sellingToggleAllowed = true;

	bool private buySellLimiterEnabled = true;
	bool private buySellLimiterAllowed = true;
	uint256 private buySellLimitThreshold = 250e18;

	// Events
	event Burn(address indexed sender, uint256 amount);
	event TransferOperator(address indexed previousOperator, address indexed newOperator);
	event UpdateFeeMaps(address _contract, bool fromHasExtra, bool toHasExtra);
	event UpdatePancakeswapRouter(address indexed operator, address indexed router);
	event SetAddLiquidityHelper(address indexed liquidityhelper);
	event SetSellTax(uint256 indexed sellTax);

	event LimiterUserUpdated(address account, bool isLimited);
	event BlacklistUpdated(address account, bool blacklisted);
	event TransferStatusUpdate(bool isPaused);
	event TransferPauseFeatureBurn();
	event SellingToggleFeatureBurn();
	event BuySellLimiterUpdate(bool isEnabled, uint256 amount);
	event SellingEnabledToggle(bool enabled);
	event LimiterFeatureBurn();
	event BlacklistingFeatureBurn();

	modifier onlyOperator() {
		require(_operator == msg.sender, "ERROR: caller is not the operator");
		_;
	}

	/**
	 * @notice Constructs the Pigs Token contract.
	 */
	constructor(address _liquidityHelperAddress) ERC20("PIGS Token", "AFP") {
		_operator = msg.sender;
		emit TransferOperator(address(0), _operator);

		// Set liquidity helper
		liquidityHelperAddress = _liquidityHelperAddress;

		pancakeswapRouter = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
		// Create BUSD and WBNB pairs
		pigsBusdSwapPair = IUniswapV2Factory(pancakeswapRouter.factory()).createPair(address(this), BUSD_ADDRESS);
		pigsWbnbSwapPair = IUniswapV2Factory(pancakeswapRouter.factory()).createPair(address(this), pancakeswapRouter.WETH());
		// Update Fee maps
		_updateFeeMaps(address(pigsBusdSwapPair), false, true);
		_updateFeeMaps(address(pigsWbnbSwapPair), false, true);
		// Exclude from limiter
		_isExcludedFromLimiter[msg.sender] = true;
		_isExcludedFromLimiter[liquidityHelperAddress] = true;
	}

	receive() external payable {}

	fallback() external payable {}

	/**
	 * @dev Returns the address of the current operator.
	 */
	function operator() external view returns (address) {
		return _operator;
	}

	/**
	 * @notice Creates `_amount` token to `_to`. Must only be called by the owner (MasterChef).
	 */
	function mint(address _to, uint256 _amount) external onlyOwner {
		_mint(_to, _amount);
	}

	/**
	 * @notice Destroys `amount` tokens from the sender, reducing the total supply.
	 */
	function burn(uint256 _amount) external {
		_burnTokens(msg.sender, _amount);
	}

	/**
	 * @dev Destroys `amount` tokens from the sender, reducing the total supply.
	 */
	function _burnTokens(address sender, uint256 _amount) private {
		_burn(sender, _amount);
		emit Burn(sender, _amount);
	}

	function _transfer(
		address sender,
		address recipient,
		uint256 amount
	) internal virtual override {
		require(!isBlacklistedFrom(sender), "ERROR: Address Blacklisted!");
		require(!isBlacklistedTo(recipient), "ERROR: Address Blacklisted!");

		bool isExcluded = _isExcludedFromLimiter[sender] || _isExcludedFromLimiter[recipient];

		if (transfersPaused) {
			require(isExcluded, "ERROR: Transfer Paused!");
		}

		if (amount == 0) {
			super._transfer(sender, recipient, amount);
			return;
		}

		if (recipient == address(pigsBusdSwapPair) && !isExcluded) {
			require(sellingEnabled, "ERROR: Selling disabled!");
		}
		if (recipient == address(pigsWbnbSwapPair) && !isExcluded) {
			require(sellingEnabled, "ERROR: Selling disabled!");
		}

		if (buySellLimiterEnabled && !isExcluded) {
			if (recipient == address(pigsBusdSwapPair) || sender == address(pigsBusdSwapPair)) {
				require(amount <= buySellLimitThreshold, "ERROR: buy / sell exceeded!");
			}
			if (recipient == address(pigsWbnbSwapPair) || sender == address(pigsWbnbSwapPair)) {
				require(amount <= buySellLimitThreshold, "ERROR: buy / sell exceeded!");
			}
		}

		bool isLiquidityHelper = (sender == liquidityHelperAddress || recipient == liquidityHelperAddress);
		uint256 sendAmount = amount;
		uint256 taxAmount = 0;
		if (!isLiquidityHelper && (extraFromMap[sender] || extraToMap[recipient]) && sellingTax > 0) {
			taxAmount = (amount * sellingTax) / 1000;
			sendAmount = amount - taxAmount;
			_burnTokens(sender, taxAmount);
		}

		super._transfer(sender, recipient, sendAmount);
	}

	/**
	 * @dev Update the pancakeswap router.
	 * Can only be called by the current operator.
	 */
	function updatePancakeswapRouter(address _router) external onlyOperator {
		require(_router != address(0), "updatePancakeswapRouter: router cannot be zero address!");
		require(_router != address(pancakeswapRouter), "updatePancakeswapRouter: router address already exists!");
		pancakeswapRouter = IUniswapV2Router02(_router);

		address _pigsBusdSwapPair = IUniswapV2Factory(pancakeswapRouter.factory()).getPair(address(this), BUSD_ADDRESS);
		if (_pigsBusdSwapPair == address(0)) {
			_pigsBusdSwapPair = IUniswapV2Factory(pancakeswapRouter.factory()).createPair(address(this), BUSD_ADDRESS);
		}

		address _pigsWbnbSwapPair = IUniswapV2Factory(pancakeswapRouter.factory()).getPair(address(this), pancakeswapRouter.WETH());
		if (_pigsWbnbSwapPair == address(0)) {
			_pigsWbnbSwapPair = IUniswapV2Factory(pancakeswapRouter.factory()).createPair(address(this), pancakeswapRouter.WETH());
		}

		pigsBusdSwapPair = _pigsBusdSwapPair;
		pigsWbnbSwapPair = _pigsWbnbSwapPair;

		emit UpdatePancakeswapRouter(msg.sender, address(pancakeswapRouter));
	}

	/**
	 * @dev Transfers operator of the contract to a new account (`newOperator`).
	 * Can only be called by the current operator.
	 */
	function transferOperator(address newOperator) external onlyOperator {
		require(newOperator != address(0), "transferOperator: new operator is the zero address");
		_operator = newOperator;
		emit TransferOperator(_operator, newOperator);
	}

	/**
	 * @dev Update the excludeFromMap
	 * Can only be called by the current operator.
	 */
	function updateFeeMaps(
		address _contract,
		bool fromHasExtra,
		bool toHasExtra
	) external onlyOperator {
		_updateFeeMaps(_contract, fromHasExtra, toHasExtra);
	}

	function _updateFeeMaps(
		address _contract,
		bool fromHasExtra,
		bool toHasExtra
	) private {
		extraFromMap[_contract] = fromHasExtra;
		extraToMap[_contract] = toHasExtra;

		emit UpdateFeeMaps(_contract, fromHasExtra, toHasExtra);
	}

	function setSellTax(uint256 _selltax) external onlyOperator {
		require(_selltax <= 100, "sell tax exceeded");
		sellingTax = _selltax;
		emit SetSellTax(_selltax);
	}

	function setLiquidityHelper(address _liquidityHelperAddress) external onlyOperator {
		require(_liquidityHelperAddress != address(0), "liquidityHelper cannot be the 0 address");
		require(_liquidityHelperAddress != liquidityHelperAddress, "liquidityHelper already exists!");
		_isExcludedFromLimiter[liquidityHelperAddress] = false;
		liquidityHelperAddress = _liquidityHelperAddress;
		// Exclude from limited users
		_isExcludedFromLimiter[liquidityHelperAddress] = true;
		emit SetAddLiquidityHelper(liquidityHelperAddress);
	}

	function inCaseTokensGetStuck(
		address _token,
		uint256 _amount,
		address _to
	) external onlyOperator {
		IERC20(_token).transfer(_to, _amount);
	}

	// AB measures
	function toggleExcludedFromLimiterUser(address account, bool isExcluded) external onlyOperator {
		require(buySellLimiterAllowed, "ERROR: Function burned!");
		_isExcludedFromLimiter[account] = isExcluded;
		emit LimiterUserUpdated(account, isExcluded);
	}

	function toggleBuySellLimiter(bool isEnabled, uint256 amount) external onlyOperator {
		require(buySellLimiterAllowed, "ERROR: Function burned!");
		buySellLimiterEnabled = isEnabled;
		buySellLimitThreshold = amount;
		emit BuySellLimiterUpdate(isEnabled, amount);
	}

	function burnLimiterFeature() external onlyOperator {
		buySellLimiterAllowed = false;
		emit LimiterFeatureBurn();
	}

	function isBlacklistedFrom(address account) public view returns (bool) {
		return blacklistFrom[account];
	}

	function isBlacklistedTo(address account) public view returns (bool) {
		return blacklistTo[account];
	}

	function toggleBlacklistUserFrom(address[] memory accounts, bool blacklisted) external onlyOperator {
		require(blacklistFeatureAllowed, "ERROR: Function burned!");
		for (uint256 i = 0; i < accounts.length; i++) {
			blacklistFrom[accounts[i]] = blacklisted;
			emit BlacklistUpdated(accounts[i], blacklisted);
		}
	}

	function toggleBlacklistUserTo(address[] memory accounts, bool blacklisted) external onlyOperator {
		require(blacklistFeatureAllowed, "ERROR: Function burned!");
		for (uint256 i = 0; i < accounts.length; i++) {
			blacklistTo[accounts[i]] = blacklisted;
			emit BlacklistUpdated(accounts[i], blacklisted);
		}
	}

	function burnBlacklistingFeature() external onlyOperator {
		blacklistFeatureAllowed = false;
		emit BlacklistingFeatureBurn();
	}

	function toggleSellingEnabled(bool enabled) external onlyOperator {
		require(sellingToggleAllowed, "ERROR: Function burned!");
		sellingEnabled = enabled;
		emit SellingEnabledToggle(enabled);
	}

	function burnToggleSellFeature() external onlyOperator {
		sellingToggleAllowed = false;
		emit SellingToggleFeatureBurn();
	}

	function toggleTransfersPaused(bool isPaused) external onlyOperator {
		require(transfersPausedFeatureAllowed, "ERROR: Function burned!");
		transfersPaused = isPaused;
		emit TransferStatusUpdate(isPaused);
	}

	function burnTogglePauseFeature() external onlyOperator {
		transfersPausedFeatureAllowed = false;
		emit TransferPauseFeatureBurn();
	}
}
