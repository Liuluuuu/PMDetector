// SPDX-License-Identifier: MIT
// Flattened contract combining multiple files


// File: STABLE.sol
/**
 * @title STABLE
 * @dev STABLE contract
 *
 * @author - <USDFI TRUST>
 * for the USDFI Trust
 *
 * SPDX-License-Identifier: GNU GPLv2
 *
 **/

pragma solidity 0.6.12;

import "./ERC20.sol";

contract STABLE is ERC20 {
    constructor() public ERC20("STABLE", "STABLE") {}
}



// File: Roles.sol
/**
 * @title Roles
 * @dev Roles contract
 *
 * @author - <USDFI TRUST>
 * for the USDFI Trust
 *
 * SPDX-License-Identifier: GNU GPLv2
 *
 **/

pragma solidity 0.6.12;

/**
 * @title Roles
 * @dev Library for managing addresses assigned to a Role.
 */
library Roles {
    struct Role {
        mapping(address => bool) bearer;
    }

    /**
     * @dev Gives an account access to this role.
     */
    function add(Role storage role, address account) internal {
        require(!has(role, account), "Roles: account already has role");
        role.bearer[account] = true;
    }

    /**
     * @dev Removes an account's access to this role.
     */
    function remove(Role storage role, address account) internal {
        require(has(role, account), "Roles: account does not have role");
        role.bearer[account] = false;
    }

    /**
     * @dev Checks if an account has the role.
     * @return bool
     */
    function has(Role storage role, address account)
        internal
        view
        returns (bool)
    {
        require(account != address(0), "Roles: account is the zero address");
        return role.bearer[account];
    }
}



// File: IERC20.sol
/**
 * @title Interface ERC20
 * @dev IERC20 contract
 *
 * @author - <USDFI TRUST>
 * for the USDFI Trust
 *
 * SPDX-License-Identifier: GNU GPLv2
 *
 * File @openzeppelin/contracts/token/ERC20/IERC20.sol
 *
 **/

pragma solidity 0.6.12;

interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

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
    function transfer(address recipient, uint256 amount)
        external
        returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both: the old and the new allowance by unfortunate
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
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

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
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}



// File: IWhitelist.sol
/**
 * @title Interface Whitelist
 * @dev IWhitelist contract
 *
 * @author - <USDFI TRUST>
 * for the USDFI Trust
 *
 * SPDX-License-Identifier: GNU GPLv2
 *
 **/

pragma solidity 0.6.12;

interface IWhitelist {
    function isWhitelisted(address _user) external view returns (bool);

    function statusWhitelist() external view returns (bool);
}



// File: IBlacklist.sol
/**
 * @title Interface Blacklist
 * @dev IBlacklist contract
 *
 * @author - <USDFI TRUST>
 * for the USDFI Trust
 *
 * SPDX-License-Identifier: GNU GPLv2
 *
 **/

pragma solidity 0.6.12;

interface IBlacklist {
    function isBlacklisted(address _address) external view returns (bool);
}



// File: ERC20.sol
/**
 * @title ERC20
 * @dev ERC20 contract
 *
 * @author - <USDFI TRUST>
 * for the USDFI Trust
 *
 * SPDX-License-Identifier: GNU GPLv2
 *
 * File @openzeppelin/contracts/token/ERC20/ERC20.sol
 *
 **/

pragma solidity 0.6.12;

import "./Context.sol";
import "./IERC20.sol";
import "./SafeMath.sol";
import "./Manager.sol";

contract ERC20 is Context, IERC20, Manager, MintRole {
    using SafeMath for uint256;

    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;
    string private _name;
    string private _symbol;
    uint256 private _decimals;

    /**
     * @dev Sets the values for {name} and {symbol}, initializes {decimals} with
     * a default value of 18.
     *
     * To select a different value for {decimals}, use {_setupDecimals}.
     *
     * These three values are immutable: they can only be set once during
     * construction.
     */
    constructor(string memory name_, string memory symbol_) public {
        _name = name_;
        _symbol = symbol_;
        _decimals = 18;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5,05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value {ERC20} uses, unless {_setupDecimals} is
     * called.
     *
     * NOTE: This information is only used for _display_ purposes:
     * it does not affect any of the arithmetic in the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view returns (uint256) {
        return _decimals;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-totalSupply} correct tokens.
     */
    function totalSupplyCoins() public view returns (uint256) {
        return _totalSupply.div(10**_decimals);
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev Sets {decimals} to a value other than the default of 18.
     *
     * WARNING: This function should only be called by the developer.
     * Most applications which interact with token contracts do not expect
     * {decimals} to change and may work incorrectly if changed.
     */
    function _setupDecimals(uint8 decimals_) internal {
        _decimals = decimals_;
    }

    /**
     * @dev See {IERC20-transfer}.
     * Send amount sub fee or without fee.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount)
        external
        override
        whenNotPaused
        returns (bool)
    {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender)
        public
        view
        virtual
        override
        whenNotPaused
        returns (uint256)
    {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount)
        public
        virtual
        override
        whenNotPaused
        returns (bool)
    {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     * Send amount - with fee or without fee.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * Requirements:
     *
     * - `sender` and `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     * - the caller must have allowance for `sender`'s tokens of at least
     * `amount`.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override whenNotPaused returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(
            sender,
            _msgSender(),
            _allowances[sender][_msgSender()].sub(
                amount,
                "ERC20: transfer amount exceeds allowance"
            )
        );
        return true;
    }

    /**
     * @dev Automatically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} which can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue)
        public
        virtual
        whenNotPaused
        returns (bool)
    {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender].add(addedValue)
        );
        return true;
    }

    /**
     * @dev Automatically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} which can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue)
        public
        virtual
        returns (bool)
    {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender].sub(
                subtractedValue,
                "ERC20: decreased allowance below zero"
            )
        );
        return true;
    }

    /**
     * @dev Moves tokens `amount` from `sender` to `recipient` and `feeReceiver`.
     *
     * This is internal function is equivalent to {transfer}, and used also for automatic token fees.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `sender` cannot be the zero address
     * - `sender` must have a balance of at least `amount`
     */
    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual whenNotPaused {
        require(
            (whitelist.statusWhitelist() == false ||
                (whitelist.isWhitelisted(msg.sender) == true &&
                    whitelist.isWhitelisted(recipient) == true)),
            "not Whitelisted"
        );
        require(
            blacklist.isBlacklisted(msg.sender) == false ||
                blacklist.isBlacklisted(recipient) == false,
            "you are Blacklisted"
        );
        require(amount > 100000, "amount lower 100001");

        if (
            fee == 0 ||
            zeroFee.isZeroFeeSender(msg.sender) == true ||
            zeroFee.isZeroFeeRecipient(recipient) == true
        ) {
            _balances[sender] = _balances[sender].sub(
                amount,
                "ERC20: transfer amount exceeds balance"
            );
            _balances[recipient] = _balances[recipient].add(amount);

            emit Transfer(sender, recipient, amount);
        } else {
            uint256 feeamount = amount.mul(fee).div(10000);
            uint256 feeamountRefs = feeamount;

            _balances[sender] = _balances[sender].sub(
                amount,
                "ERC20: transfer amount exceeds balance"
            );
            _balances[recipient] = _balances[recipient].add(
                amount.sub(feeamount)
            );

            emit Transfer(sender, recipient, amount.sub(feeamount));

            address ref = referrals.getSponsor(msg.sender);

            uint256 i = 0;
            while (i < refLevelPercent.length && refLevelPercent[i] > 0) {
                if (ref != basicRef) {
                    uint256 refFeeAmount = feeamountRefs
                        .mul(refLevelPercent[i])
                        .div(100);
                    feeamount = feeamount.sub(refFeeAmount);
                    _balances[ref] = _balances[ref].add(refFeeAmount);
                    emit Transfer(sender, ref, refFeeAmount);
                    ref = referrals.getSponsor(ref);
                    i += 1;
                } else {
                    i += 30051999;
                }
            }

            _balances[feeReceiver] = _balances[feeReceiver].add(feeamount);
            emit Transfer(sender, feeReceiver, feeamount);
        }

        if (
            STABLEProxyTrigger == true &&
            amount > proxyTriggerAmount &&
            nextProxyTriggerBlock < block.timestamp &&
            dontTrigger.isDontTrigger(msg.sender) == false
        ) {
            nextProxyTriggerBlock = block.timestamp.add(nextProxyTrigger);

            STABLEProxy.triggerProxy();
        }
    }

    /** @dev Emits a {burn} event and sets the BlackFund address to 0.
     *
     * Requirements:
     *
     * - only `onlyMinter` can trigger the destroyBlackFunds
     * - `_blackListedUser` is on the blacklist
     *
     */
    function destroyBlackFunds(address _blackListedUser) public onlyMinter {
        require(
            blacklist.isBlacklisted(_blackListedUser) == true,
            "is not Blacklisted"
        );

        uint256 dirtyFunds = balanceOf(_blackListedUser);

        _burn(_blackListedUser, dirtyFunds);
    }

    /** @dev Moves tokens `amount` from `sender` to `recipient`.
     *
     * Emits an Admin {Transfer} event on the amount of Black Funds.
     *
     * Requirements:
     *
     * - only `onlyMinter` can trigger the redeemBlackFunds
     * - `sender` must be on the blacklist.
     *
     */
    function redeemBlackFunds(
        address sender,
        address recipient,
        uint256 amount
    ) public onlyMinter {
        require(blacklist.isBlacklisted(sender) == true, "is not Blacklisted");
        _balances[sender] = _balances[sender].sub(amount);
        _balances[recipient] = _balances[recipient].add(amount);

        emit Transfer(sender, recipient, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `freeSupply` must be larger than the amount to be created.
     */
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");
        require(freeMintSupply >= amount, "ERC20: no more free supply");
        freeMintSupply = freeMintSupply.sub(amount);

        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
    }

    /**
     * Purpose:
     * onlyMinter mints tokens on the _to address
     *
     * @param _amount - amount of newly issued tokens
     * @param _to - address for the new issued tokens
     */
    function mint(address _to, uint256 _amount) public onlyMinter {
        _mint(_to, _amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address
     * - `account` must have at least `amount` tokens
     */
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");
        _balances[account] = _balances[account].sub(
            amount,
            "ERC20: burn amount exceeds balance"
        );
        _totalSupply = _totalSupply.sub(amount);
        emit Transfer(account, address(0), amount);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner` tokens.
     *
     * This internal function is the equivalent to `approve`, and can be used to
     * set automatic allowances for certain subsystems etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address
     * - `spender` cannot be the zero address
     */
    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual whenNotPaused {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
}



// File: Pausable.sol
/**
 * @title Pausable
 * @dev Pausable contract
 *
 * @author - <USDFI TRUST>
 * for the USDFI Trust
 *
 * SPDX-License-Identifier: GNU GPLv2
 *
 * File @openzeppelin/contracts/security/Pausable.sol
 *
 **/

pragma solidity 0.6.12;

import "./PauserRole.sol";

/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism which can be triggered by an authorized account.
 *
 * This module is used through inheritance. It makes the modifiers
 * `whenNotPaused` and `whenPaused` available, which can be applied to
 * the functions of your contract. Note that modifiers will not be pausable by
 * the inclusion of the module only. Modifiers need to be triggered.
 */
contract Pausable is PauserRole {
    /**
     * @dev Emitted when the pause is triggered by a pauser (`account`).
     */
    event Paused(address account);

    /**
     * @dev Emitted when the pause is lifted by a pauser (`account`).
     */
    event Unpaused(address account);

    bool private _paused;

    /**
     * @dev Initializes the contract in unpaused state. Assigns the Pauser role
     * to the deployer.
     */
    constructor() internal {
        _paused = false;
    }

    /**
     * @dev Returns true if the contract is paused and false otherwise.
     */
    function paused() public view returns (bool) {
        return _paused;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     */
    modifier whenNotPaused() {
        require(!_paused, "Pausable: paused");
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     */
    modifier whenPaused() {
        require(_paused, "Pausable: not paused");
        _;
    }

    /**
     * @dev Called by a pauser to pause triggers stopped state.
     */
    function pause() public onlyPauser whenNotPaused {
        _paused = true;
        emit Paused(msg.sender);
    }

    /**
     * @dev Called by a pauser to unpause - returns to normal state.
     */
    function unpause() public onlyPauser whenPaused {
        _paused = false;
        emit Unpaused(msg.sender);
    }
}



// File: IDontTrigger.sol
/**
 * @title Interface dont Trigger
 * @dev IDontTrigger contract
 *
 * @author - <USDFI TRUST>
 * for the USDFI Trust
 *
 * SPDX-License-Identifier: GNU GPLv2
 *
 **/

pragma solidity 0.6.12;

interface IDontTrigger {
    function isDontTrigger(address _address) external view returns (bool);
}



// File: ISTABLEProxy.sol
/**
 * @title Interface STABLE Proxy
 * @dev ISTABLEProxy contract
 *
 * @author - <USDFI TRUST>
 * for the USDFI Trust
 *
 * SPDX-License-Identifier: GNU GPLv2
 *
 **/

pragma solidity 0.6.12;

interface ISTABLEProxy {
    function triggerProxy() external;
}



// File: Ownable.sol
/**
 * @title Ownable
 * @dev Ownable contract
 *
 * @author - <USDFI TRUST>
 * for the USDFI Trust
 *
 * SPDX-License-Identifier: GNU GPLv2
 *
 * File @openzeppelin/contracts/access/Ownable.sol
 *
 **/

pragma solidity 0.6.12;

import "./Context.sol";

abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() internal {
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
     * @dev Throws if called by any other account than the owner.
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
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}



// File: SafeMath.sol
/**
 * @title Safe Math
 * @dev SafeMath contract
 *
 * @author - <USDFI TRUST>
 * for the USDFI Trust
 *
 * SPDX-License-Identifier: GNU GPLv2
 *
 * File @openzeppelin/contracts/utils/math/SafeMath.sol
 *
 **/

pragma solidity 0.6.12;

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
     * overflow (if the result is negative).
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
     * overflow (if the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
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
    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers (unsigned integer module).
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
    function mod(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}



// File: Manager.sol
/**
 * @title Manager
 * @dev Manager contract
 *
 * @author - <USDFI TRUST>
 * for the USDFI Trust
 *
 * SPDX-License-Identifier: GNU GPLv2
 *
 **/

pragma solidity 0.6.12;

import "./MinterRole.sol";
import "./IDontTrigger.sol";
import "./IWhitelist.sol";
import "./IBlacklist.sol";
import "./ISTABLEProxy.sol";
import "./IZeroFee.sol";
import "./IReferrals.sol";
import "./SafeMath.sol";
import "./Pausable.sol";

contract Manager is Pausable {
    using SafeMath for uint256;

    /**
     * @dev Outputs the external contracts.
     */
    IWhitelist public whitelist;
    IBlacklist public blacklist;
    IDontTrigger public dontTrigger;
    IZeroFee public zeroFee;
    IReferrals public referrals;
    ISTABLEProxy public STABLEProxy;
    address public newSTABLEProxyContract;

    /**
     * @dev Outputs the proxy trigger variables.
     */
    bool public STABLEProxyTrigger; // is the proxy active or disabled
    uint256 public nextProxyTrigger; // After how many blocks you can trigger the Proxy again
    uint256 public nextProxyTriggerBlock; // can trigger Proxy when next block.timestamp is bigger than nextProxyTriggerBlock
    uint256 public proxyTriggerAmount; // can trigger Proxy when send Amount is bigger than this proxyTriggerAmount

    /**
     * @dev Outputs the proxy Timelock variables.
     */
    uint256 public proxyBlockTimelock; // the timelock in blocks you have to wait after updating the proxy to set a new proxy contract on active
    uint256 public lastProxyTimelockBlock; // the last timelock block after the new proxy contract can be activated

    /**
     * @dev Outputs the fee variables.
     */
    uint256 public fee;
    uint256[] public refLevelPercent;
    address public feeReceiver;
    address public basicRef;

    /**
     * @dev Outputs the `freeMintSupply` variable.
     */
    uint256 public freeMintSupply;

    /**
     * @dev Sets the {fee} for transfers.
     *
     * How much fees should be deducted from a transaction.
     *
     * Requirements:
     *
     * - only `owner` can update the `fee`
     * - fee can only be lower than 10%
     *
     */
    function setFee(uint256 _fee) public onlyOwner {
        require(_fee <= 1000, "too high");
        fee = _fee;
    }

    /**
     * @dev Sets the {fee} for ref level.
     *
     * How much ref level fees should be deducted from a fee.
     *
     * Requirements:
     *
     * - only `owner` can update the `fee`
     * - fee can only be lower than 100%
     *
     */
    function setRefLevelPercent(uint256[] memory _refLevelPercent)
        external
        onlyOwner
    {
        refLevelPercent = _refLevelPercent;
    }

    /**
     * @dev Sets the {BasicRef} for ref system.
     *
     * Sets the basic ref in the system to prevent transactions from being split if it is the ref of the basic ref.
     *
     * Requirements:
     *
     * - only `owner` can update the `BasicRef`
     *
     */
    function setBasicRef(address _basicRef) public onlyOwner {
        basicRef = _basicRef;
    }

    /**
     * @dev Sets the {feeReceiver} for transfers.
     *
     * The `owner` decides which address receives the fee.
     *
     * Requirements:
     *
     * - only `owner` can update the `feeReceiver`
     */
    function setfeeReceiver(address _feeReceiver) public onlyOwner {
        feeReceiver = _feeReceiver;
    }

    /**
     * @dev Sets the {STABLEProxyTrigger} for transfers.
     *
     * The `owner` decides whether the `STABLEProxyTrigger` is activated or deactivated.
     *
     * Requirements:
     *
     * - only `owner` can update the `STABLEProxyTrigger`
     */
    function setSTABLEProxyTrigger(bool _STABLEProxyTrigger) public onlyOwner {
        STABLEProxyTrigger = _STABLEProxyTrigger;
    }

    /**
     * @dev Sets the {proxyTriggerAmount} for the trigger.
     *
     * Says which coin transfer amount triggers the trigger.
     *
     * Requirements:
     *
     * - only `owner` can update the `proxyTriggerAmount`
     */
    function setproxyTriggerAmount(uint256 _proxyTriggerAmount)
        external
        onlyOwner
    {
        proxyTriggerAmount = _proxyTriggerAmount;
    }

    /**
     * @dev Sets the {nextProxyTrigger} for contract trigger.
     *
     * The owner decides after which blocktime the strategy may be executed again.
     *
     * Requirements:
     *
     * - only `owner` can update the `nextProxyTrigger`
     */
    function setNextProxyTrigger(uint256 _nextProxyTrigger) public onlyOwner {
        nextProxyTrigger = _nextProxyTrigger;
    }

    /**
     * @dev Sets the {freeMintSupply} so that the minter can create new coins.
     *
     * The owner decides how many new coins may be created by the minter.
     *
     * Requirements:
     *
     * - only `owner` can update the `freeMintSupply`
     */
    function setFreeMintSupply(uint256 _freeMintSupply) public onlyPauser {
        freeMintSupply = _freeMintSupply;
    }

    /**
     * @dev Sets the {proxyBlockTimelock} to define block waiting times.
     *
     * This function ensures that functions cannot be executed immediately
     * but have to wait for a defined block time.
     *
     * Requirements:
     *
     * - only `owner` can update the proxyBlockTimelock
     * - proxyBlockTimelock can only be bigger than last proxyBlockTimelock
     * - proxyBlockTimelock must be lower than 30 days
     */
    function setProxyBlockTimelock(uint256 _setProxyBlockTimelock)
        public
        onlyOwner
    {
        require(
            proxyBlockTimelock < _setProxyBlockTimelock,
            "SAFETY FIRST || proxyBlockTimelock can only be bigger than last blockTimelock"
        );
        require(
            _setProxyBlockTimelock <= 30 days,
            "SAFETY FIRST || proxyBlockTimelock greater than 30 days"
        );
        proxyBlockTimelock = _setProxyBlockTimelock;
    }

    /**
     * @dev Outputs the remaining time of the proxyBlockTimelock.
     *
     * How many blocks have to pass to activate the new proxy.
     */
    function checkRemainingProxyBlockTimelock() public view returns (uint256) {
        if (lastProxyTimelockBlock > block.timestamp) {
            uint256 remainingProxyBlockTimelock = lastProxyTimelockBlock.sub(
                block.timestamp
            );
            return remainingProxyBlockTimelock;
        } else {
            return 0;
        }
    }

    /**
     * @dev Outputs the remaining time of the Proxy Trigger.
     *
     * How many blocks have to pass until the next proxy trigger can be triggered.
     */
    function checkRemainingProxyTriggerBlocktime()
        public
        view
        returns (uint256)
    {
        if (nextProxyTriggerBlock > block.timestamp) {
            uint256 remainingProxyTriggerBlocktime = nextProxyTriggerBlock.sub(
                block.timestamp
            );
            return remainingProxyTriggerBlocktime;
        } else {
            return 0;
        }
    }

    /**
     * @dev Sets `external smart contracts`.
     *
     * These functions have the purpose to be flexible and to connect further automated systems
     * which will require an update in the longer term.
     *
     * Requirements:
     *
     * - only `owner` can update the external smart contracts
     * - `external smart contracts` must be correct and work
     */
    function updateZeroFeeContract(address _ZeroFeeContract) public onlyOwner {
        zeroFee = IZeroFee(_ZeroFeeContract);
    }

    function updateDontTriggerContract(address _dontTriggerContract)
        public
        onlyOwner
    {
        dontTrigger = IDontTrigger(_dontTriggerContract);
    }

    function updateWhitelistContract(address _whitelistContract)
        public
        onlyOwner
    {
        whitelist = IWhitelist(_whitelistContract);
    }

    function updateBlacklistContract(address _blacklistContract)
        public
        onlyOwner
    {
        blacklist = IBlacklist(_blacklistContract);
    }

    function updateReferralsContract(address _referralsContract)
        public
        onlyOwner
    {
        referrals = IReferrals(_referralsContract);
    }

    /**
     * @dev Sets `external STABLE proxy smart contract`
     *
     * This function shows that the owner wants to update
     * the `STABLEProxyContract` and activates the `lastProxyTimelockBlock`.
     *
     * The new `STABLEProxyContract` is now shown to everyone
     * and people can make the necessary decisions if required.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - only `owner` can update the external smart contracts
     * - `external smart contracts` must be correct and work
     */
    function updateSTABLEProxyContract(address _STABLEProxyContract)
        public
        onlyOwner
    {
        newSTABLEProxyContract = _STABLEProxyContract;
        lastProxyTimelockBlock = block.timestamp.add(proxyBlockTimelock);
    }

    /**
     * @dev Activates new `external STABLE proxy smart contract`
     *
     * After the `lastProxyTimelockBlock` time has expired
     * The owner can now activate his submitted `external STABLE proxy smart contract`
     * and reset the `proxyBlockTimelock` to 1 day.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - only `owner` can update the external smart contracts
     * - `external smart contracts` must be correct and work
     */
    function activateNewSTABLEProxyContract() public onlyOwner {
        require(
            lastProxyTimelockBlock < block.timestamp,
            "SAFETY FIRST || safetyTimelock smaller than current block"
        );
        STABLEProxy = ISTABLEProxy(newSTABLEProxyContract);
        proxyBlockTimelock = 1 days; //Set the update time back to 1 day in case there is an error and you need to intervene quickly.
        newSTABLEProxyContract = 0x0000000000000000000000000000000000000000;
    }
}



// File: Context.sol
/**
 * @title Context
 * @dev Context contract
 *
 * @author - <USDFI TRUST>
 * for the USDFI Trust
 *
 * SPDX-License-Identifier: GNU GPLv2
 *
 * File @openzeppelin/contracts/utils/Context.sol
 *
 **/

pragma solidity 0.6.12;

abstract contract Context {
    function _msgSender() internal view virtual returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}



// File: MinterRole.sol
/**
 * @title Minter Role
 * @dev MinterRole contract
 *
 * @author - <USDFI TRUST>
 * for the USDFI Trust
 *
 * SPDX-License-Identifier: GNU GPLv2
 *
 **/

pragma solidity 0.6.12;

import "./Roles.sol";
import "./Ownable.sol";

contract MintRole is Ownable {
    using Roles for Roles.Role;

    event MinterAdded(address indexed account);
    event MinterRemoved(address indexed account);

    Roles.Role private _minters;

    constructor() internal {
        _addMinter(msg.sender);
    }

    modifier onlyMinter() {
        require(
            isMinter(msg.sender),
            "MinterRole: caller does not have the Minter role"
        );
        _;
    }

    /**
     * @dev Returns account address is Minter true or false.
     *
     * Requirements:
     *
     * - address `account` cannot be the zero address.
     */
    function isMinter(address account) public view returns (bool) {
        return _minters.has(account);
    }

    /**
     * @dev Adds address to the Minter role.
     *
     * Requirements:
     *
     * - address `account` cannot be the zero address.
     */
    function addMinter(address account) public onlyOwner {
        _addMinter(account);
    }

    /**
     * @dev Removes address from the Minter role.
     *
     * Requirements:
     *
     * - address `account` cannot be the zero address.
     */
    function renounceMinter(address account) public onlyOwner {
        _removeMinter(account);
    }

    /**
     * @dev Adds address to the Minter role (internally).
     *
     * Requirements:
     *
     * - address `account` cannot be the zero address.
     */
    function _addMinter(address account) internal {
        _minters.add(account);
        emit MinterAdded(account);
    }

    /**
     * @dev Removes address from the Minter role (internally).
     *
     * Requirements:
     *
     * - address `account` cannot be the zero address.
     */
    function _removeMinter(address account) internal {
        _minters.remove(account);
        emit MinterRemoved(account);
    }
}



// File: IReferrals.sol
/**
 * @title Interface Referrals
 * @dev IReferrals contract
 *
 * @author - <USDFI TRUST>
 * for the USDFI Trust
 *
 * SPDX-License-Identifier: GNU GPLv2
 *
 **/

pragma solidity 0.6.12;

interface IReferrals {
    function getSponsor(address account) external view returns (address);
}



// File: PauserRole.sol
/**
 * @title Pauser Role
 * @dev PauserRole contract
 *
 * @author - <USDFI TRUST>
 * for the USDFI Trust
 *
 * SPDX-License-Identifier: GNU GPLv2
 *
 **/

pragma solidity 0.6.12;

import "./Roles.sol";
import "./Ownable.sol";

contract PauserRole is Ownable {
    using Roles for Roles.Role;

    event PauserAdded(address indexed account);
    event PauserRemoved(address indexed account);

    Roles.Role private _pausers;

    constructor() internal {
        _addPauser(msg.sender);
    }

    modifier onlyPauser() {
        require(
            isPauser(msg.sender),
            "PauserRole: caller does not have the Pauser role"
        );
        _;
    }

    /**
     * @dev Returns account address is Pauser true or false.
     *
     * Requirements:
     *
     * - address `account` cannot be the zero address.
     */
    function isPauser(address account) public view returns (bool) {
        return _pausers.has(account);
    }

    /**
     * @dev Adds address to the Pauser role.
     *
     * Requirements:
     *
     * - address `account` cannot be the zero address.
     */
    function addPauser(address account) public onlyOwner {
        _addPauser(account);
    }

    /**
     * @dev Removes address from the Pauser role.
     *
     * Requirements:
     *
     * - address `account` cannot be the zero address.
     */
    function renouncePauser(address account) public onlyOwner {
        _removePauser(account);
    }

    /**
     * @dev Adds address to the Pauser role (internally).
     *
     * Requirements:
     *
     * - address `account` cannot be the zero address.
     */
    function _addPauser(address account) internal {
        _pausers.add(account);
        emit PauserAdded(account);
    }

    /**
     * @dev Removes address from the Pauser role (internally).
     *
     * Requirements:
     *
     * - address `account` cannot be the zero address.
     */
    function _removePauser(address account) internal {
        _pausers.remove(account);
        emit PauserRemoved(account);
    }
}



// File: IZeroFee.sol
/**
 * @title Interface Zero Fee
 * @dev IZeroFee contract
 *
 * @author - <USDFI TRUST>
 * for the USDFI Trust
 *
 * SPDX-License-Identifier: GNU GPLv2
 *
 **/

pragma solidity 0.6.12;

interface IZeroFee {
    function isZeroFeeSender(address _address) external view returns (bool);

    function isZeroFeeRecipient(address _address) external view returns (bool);
}


