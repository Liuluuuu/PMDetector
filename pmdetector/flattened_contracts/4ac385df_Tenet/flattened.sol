// SPDX-License-Identifier: MIT
// Flattened contract combining multiple files


// File: IERC20.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
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
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

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



// File: TenetProxy.sol
// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "./ERC20.sol";
import "./IERC20.sol";
import "./SafeERC20.sol";
import "./EnumerableSet.sol";
import "./SafeMath.sol";
import "./Ownable.sol";
import "./IUniswapV2Pair.sol";
import "./IUniswapV2Factory.sol";
import "./TenetMine.sol";
import "./Tenet.sol";

contract TenetProxy is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    uint256 public constant MINLPTOKEN_AMOUNT = 10000000000;
    uint public constant MINIMUM_LIQUIDITY = 10**3;
    uint256 public constant PERSHARERATE = 1000000000000;

    Tenet public tenet;
    TenetMine public tenetmine;
    constructor(Tenet _tenet) public {
        tenet = _tenet;
        tenetmine = tenet.tenMineCalc();
    }
    function set_tenet(Tenet _tenet) public onlyOwner {
        tenet = _tenet;
        tenetmine = tenet.tenMineCalc();
    }     
    function getPoolAllInfo(uint256 _pid) public view returns (address[3] memory retData1,uint256[6] memory retData2,uint256[8] memory retData3) {
        (retData1) = getPoolSettingInfo1(_pid);
        (retData2) = getPoolSettingInfo2(_pid);
        (retData3) = getPoolInfo(_pid);
    }
    function getPoolSettingInfo1(uint256 _pid) public view returns (address[3] memory retData1) {
        (retData1[0],retData1[1],retData1[2],,,,,,) = tenet.poolSettingInfo(_pid);
    }  
    function getPoolSettingInfo2(uint256 _pid) public view returns (uint256[6] memory retData2) {
        (,,,retData2[0],retData2[1],retData2[2],retData2[3],retData2[4],retData2[5]) = tenet.poolSettingInfo(_pid);
    }                    
    function getPoolInfo(uint256 _pid) public view returns (uint256[8] memory retData3) {
        (retData3[0],retData3[1],retData3[2],retData3[3],retData3[4],retData3[5],retData3[6],retData3[7]) = tenet.poolInfo(_pid);
    } 
    
    function getPendingTenByProject(uint _pid) public view returns (uint256) {
        ( , ,uint256[8] memory retData3) = getPoolAllInfo(_pid);
        if(retData3[1] <= MINLPTOKEN_AMOUNT){
            return 0;
        }
        if(retData3[5] <= MINLPTOKEN_AMOUNT){
            return 0;
        }
        uint256[4] memory tenPoolInfo;
        (tenPoolInfo[0],tenPoolInfo[1],tenPoolInfo[2],tenPoolInfo[3]) = tenet.tenProjectPool();
        if(tenPoolInfo[3] < MINLPTOKEN_AMOUNT){
            return 0;
        }          
        if (block.number > tenPoolInfo[0] && retData3[5] != 0) {
            uint256 tenReward = tenetmine.calcMineTenReward(tenPoolInfo[0], block.number);
            tenReward = tenReward.mul(tenPoolInfo[2]).div(tenet.totalAllocPoint());
            tenPoolInfo[1] = tenPoolInfo[1].add(tenReward.mul(1e12).div(tenPoolInfo[3]));
        }
        return retData3[5].mul(tenPoolInfo[1]).div(1e12).sub(retData3[6]);
    }
    function _calcFreezeTen(uint256[6] memory userInfo,uint256 accTenPerShare) internal view returns (uint256 pendingTen,uint256 freezeBlocks,uint256 freezeTen){
        pendingTen = userInfo[0].mul(accTenPerShare).div(PERSHARERATE).sub(userInfo[2]);
        uint256 blockNow = block.number.sub(userInfo[3]);
        uint256 periodBlockNumer = tenetmine.subBlockNumerPeriod();
        freezeBlocks = blockNow.add(userInfo[4]);
        if(freezeBlocks <= periodBlockNumer){
            freezeTen = pendingTen.add(userInfo[5]);
            pendingTen = 0;
        }else{
            if(pendingTen == 0){
                freezeBlocks = 0;
                freezeTen = 0;
                pendingTen = userInfo[5];
            }else{
                freezeTen = pendingTen.add(userInfo[5]).mul(periodBlockNumer).div(freezeBlocks);
                pendingTen = pendingTen.add(userInfo[5]).sub(freezeTen);
                freezeBlocks = periodBlockNumer;
            }            
        }        
    }    
    
    function getPendingTenByUser(address _user) public view returns (uint256,uint256,uint256) {
        uint256[6] memory userInfo;
        (userInfo[0],userInfo[1],userInfo[2],userInfo[3],userInfo[4],userInfo[5]) = tenet.userInfoUserPool(_user);
        if(userInfo[0] <= MINLPTOKEN_AMOUNT){
            if(block.number.sub(userInfo[3])>tenetmine.subBlockNumerPeriod()){
                return (userInfo[5],0,0);
            }else{
                return (0,0,userInfo[5]);
            }
        }
        uint256[4] memory tenPoolInfo;
        (tenPoolInfo[0],tenPoolInfo[1],tenPoolInfo[2],tenPoolInfo[3]) = tenet.tenUserPool();
        if(tenPoolInfo[3] <= MINLPTOKEN_AMOUNT){
            if(block.number.sub(userInfo[3])>tenetmine.subBlockNumerPeriod()){
                return (userInfo[5],0,0);
            }else{
                return (0,0,userInfo[5]);
            }
        }  
        if (block.number > tenPoolInfo[0]) {
            uint256 tenReward = tenetmine.calcMineTenReward(tenPoolInfo[0], block.number);
            tenReward = tenReward.mul(tenPoolInfo[2]).div(tenet.totalAllocPoint());
            tenPoolInfo[1] = tenPoolInfo[1].add(tenReward.mul(1e12).div(tenPoolInfo[3]));
        }
        (uint256 pendingTen,uint256 freezeBlocks,uint256 freezeTen) = _calcFreezeTen(userInfo,tenPoolInfo[1]);
        return (pendingTen,freezeBlocks,freezeTen);
    }

    
    function getPendingTen(uint256 _pid, address _user) public view returns (uint256,uint256,uint256) {
        uint256[6] memory userInfo;
        (userInfo[0], ,userInfo[2],userInfo[3],userInfo[4],userInfo[5]) = tenet.userInfo(_pid,_user);
        if(userInfo[0] <= MINLPTOKEN_AMOUNT){
            if(block.number.sub(userInfo[3])>tenetmine.subBlockNumerPeriod()){
                return (userInfo[5],0,0);
            }else{
                return (0,0,userInfo[5]);
            }
        }
        ( , ,uint256[8] memory retData3) = getPoolAllInfo(_pid);
        if(retData3[1] <= MINLPTOKEN_AMOUNT){
            if(block.number.sub(userInfo[3])>tenetmine.subBlockNumerPeriod()){
                return (userInfo[5],0,0);
            }else{
                return (0,0,userInfo[5]);
            }
        } 
        uint256 pending = getPendingTenByProject(_pid);
        retData3[3] = retData3[3].add(pending.mul(1e12).div(retData3[1]));
        (uint256 pendingTen,uint256 freezeBlocks,uint256 freezeTen) = _calcFreezeTen(userInfo,retData3[3]);
        return (pendingTen,freezeBlocks,freezeTen);        
     }

    
    function getPendingToken(uint256 _pid, address _user) public view returns (uint256) {
        ( ,uint256[6] memory retData2,uint256[8] memory retData3) = getPoolAllInfo(_pid);
        if(retData3[1] <= MINLPTOKEN_AMOUNT){
            return 0;
        }
        uint256[6] memory userInfo;
        (userInfo[0],userInfo[2], , , , ) = tenet.userInfo(_pid,_user);
        if(userInfo[0] <= MINLPTOKEN_AMOUNT){
            return 0;
        }        
        if (block.number > retData3[0] && retData3[1] != 0) {
            uint256 tokenReward = retData2[3].mul(tenetmine.getMultiplier(retData3[0], block.number,retData2[2],retData2[4],retData2[5]));
            retData3[2] = retData3[2].add(tokenReward.mul(1e12).div(retData3[1]));
        }
        return userInfo[0].mul(retData3[2]).div(1e12).sub(userInfo[2]);
    }       
    function calcLiquidity2(address _pairAddr,uint256 _token0Amount,uint256 _token1Amount) public view returns (uint256 liquidity) {
        uint256 totalSupply = IUniswapV2Pair(_pairAddr).totalSupply();
        (uint256 reserve0, uint256 reserve1,) = IUniswapV2Pair(_pairAddr).getReserves();
        if(totalSupply == 0){
            liquidity = sqrt(_token0Amount.mul(_token1Amount)).sub(MINIMUM_LIQUIDITY);
        }else {
            liquidity = min(_token0Amount.mul(totalSupply) / reserve0, _token1Amount.mul(totalSupply) / reserve1);
        }
    }
    function calcLiquidity(address _pairAddr,address _tokenAddr,uint256 _tokenAmount) public view returns (uint256 liquidity) {
        uint256[2] memory tokenAmountOut;
        if(_tokenAddr == IUniswapV2Pair(_pairAddr).token0()){
            (tokenAmountOut[0],tokenAmountOut[1]) = calcTokenXOut(_pairAddr,_tokenAddr,_tokenAmount,0);
        }else if(_tokenAddr == IUniswapV2Pair(_pairAddr).token1()){
            (tokenAmountOut[0],tokenAmountOut[1]) = calcTokenXOut(_pairAddr,_tokenAddr,_tokenAmount,1);
        }else{
            (tokenAmountOut[0],tokenAmountOut[1]) = calcTokensOut(_pairAddr,_tokenAddr,_tokenAmount);
        }
        if(tokenAmountOut[0] == 0){
            liquidity = 0;
        }else if(tokenAmountOut[0] == 0){
            liquidity = 0;
        }else{
            uint256 totalSupply = IUniswapV2Pair(_pairAddr).totalSupply();
            (uint256 reserve0, uint256 reserve1,) = IUniswapV2Pair(_pairAddr).getReserves();
            if(totalSupply == 0){
                liquidity = sqrt(tokenAmountOut[0].mul(tokenAmountOut[1])).sub(MINIMUM_LIQUIDITY);
            }else {
                liquidity = min(tokenAmountOut[0].mul(totalSupply) / reserve0, tokenAmountOut[1].mul(totalSupply) / reserve1);
            }
        }
    }    
    
    function getAmountOut(address _pairAddr, address _fromAddr,uint amountIn) public view virtual returns (uint256){
        //require(amountIn > 0, 'getAmountOut: INSUFFICIENT_INPUT_AMOUNT');
        if(amountIn == 0){
            return 0;
        }         
        (uint256 reserve0, uint256 reserve1,) = IUniswapV2Pair(_pairAddr).getReserves();
        //require(reserve0 > 0 && reserve1 > 0, 'getAmountOut: INSUFFICIENT_LIQUIDITY');
        if(reserve0 == 0){
            return 0;
        } 
        if(reserve1 == 0){
            return 0;
        }                
        uint amountInWithFee = amountIn.mul(997);
        if(_fromAddr == IUniswapV2Pair(_pairAddr).token0()){
            uint numerator = amountInWithFee.mul(reserve1);
            uint denominator = reserve0.mul(1000).add(amountInWithFee);
            return numerator.div(denominator);
        }else{
            uint numerator = amountInWithFee.mul(reserve0);
            uint denominator = reserve1.mul(1000).add(amountInWithFee);
            return numerator.div(denominator);
        }
    }         
    
    function getPrice(address _pairAddr, address _fromAddr) public view returns (uint256) {
        (uint256 reserve0, uint256 reserve1,) = IUniswapV2Pair(_pairAddr).getReserves();
        if(_fromAddr == IUniswapV2Pair(_pairAddr).token0()){
            return reserve1.mul(1e12).div(reserve0);
        }else{
            return reserve0.mul(1e12).div(reserve1);
        }
    }    
    
    function calcTokensOut(address _pairAddr,address _tokenAddr,uint256 _tokenAmount) public view returns (uint256,uint256) {
        IUniswapV2Factory factory = IUniswapV2Factory(IUniswapV2Pair(_pairAddr).factory());
        //require(address(factory) != address(0), 'calcTokensOut: INSUFFICIENT_PAIRADDR');
        if(address(factory) == address(0)){
            return (0,0);
        }        
        uint256[8] memory dataAll;
        (dataAll[6], dataAll[7],) = IUniswapV2Pair(_pairAddr).getReserves();
        //require(dataAll[6] > 0, 'calcTokenOut: INSUFFICIENT_RESERVE0');
        //require(dataAll[7] > 0, 'calcTokenOut: INSUFFICIENT_RESERVE1');   
        if(dataAll[6] == 0){
            return (0,0);
        } 
        if(dataAll[7] == 0){
            return (0,0);
        }         
        address[2] memory allPairAddr;
        allPairAddr[0] = factory.getPair(_tokenAddr,IUniswapV2Pair(_pairAddr).token0());
        //require(allPairAddr[0] != address(0), 'calcToken: INVALID_PAIR0');
        if(allPairAddr[0] == address(0)){
            return (0,0);
        }          
        dataAll[0] = getPrice(allPairAddr[0],_tokenAddr);
        allPairAddr[1] = factory.getPair(_tokenAddr,IUniswapV2Pair(_pairAddr).token1());
        //require(allPairAddr[1] != address(0), 'calcToken: INVALID_PAIR1');
        if(allPairAddr[1] == address(0)){
            return (0,0);
        }   
        dataAll[1] = getPrice(allPairAddr[1],_tokenAddr);
        
        dataAll[2] = _tokenAmount.mul(dataAll[1]).mul(dataAll[6]).div(dataAll[0].mul(dataAll[7]).add(dataAll[1].mul(dataAll[6])));
        
        dataAll[3] = _tokenAmount.sub(dataAll[2]);
        dataAll[4] = getAmountOut(allPairAddr[0],_tokenAddr,dataAll[2]);
        dataAll[5] = getAmountOut(allPairAddr[1],_tokenAddr,dataAll[3]);
        return (dataAll[4],dataAll[5]);
    }
    
    function calcTokenXOut(address _pairAddr,address _tokenAddr,uint256 _tokenAmount,uint256 tokenType) public view returns (uint256,uint256) {
        IUniswapV2Factory factory = IUniswapV2Factory(IUniswapV2Pair(_pairAddr).factory());
        //require(address(factory) != address(0), 'calcTokenXOut: INSUFFICIENT_PAIRADDR');
        if(address(factory) == address(0)){
            return (0,0);
        }
        uint256[5] memory dataAll;
        (dataAll[0], dataAll[1],) = IUniswapV2Pair(_pairAddr).getReserves();
        //require(dataAll[0] > 0, 'calcTokenXOut: INSUFFICIENT_RESERVE0');
        //require(dataAll[1] > 0, 'calcTokenXOut: INSUFFICIENT_RESERVE1');   
        if(dataAll[0] == 0){
            return (0,0);
        } 
        if(dataAll[1] == 0){
            return (0,0);
        }         
        // (reserv_USDT * amount / (reserv_USDT + reserv_TEN) )
        dataAll[2] = _tokenAmount.div(2);
        dataAll[3] = _tokenAmount.sub(dataAll[2]);
        dataAll[4] = getAmountOut(_pairAddr,_tokenAddr,dataAll[3]);
        if(tokenType == 0){
            return (dataAll[2],dataAll[4]);
        }else{
            return (dataAll[4],dataAll[2]);
        }
    }
    function min(uint x, uint y) internal pure returns (uint z) {
        z = x < y ? x : y;
    }
    function sqrt(uint y) internal pure returns (uint z) {
        if (y > 3) {
            z = y;
            uint x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }                
}


// File: ERC20.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "./Context.sol";
import "./IERC20.sol";
import "./SafeMath.sol";
import "./Address.sol";

/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 * For a generic mechanism see {ERC20PresetMinterPauser}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.zeppelin.solutions/t/how-to-implement-erc20-supply-mechanisms/226[How
 * to implement supply mechanisms].
 *
 * We have followed general OpenZeppelin guidelines: functions revert instead
 * of returning `false` on failure. This behavior is nonetheless conventional
 * and does not conflict with the expectations of ERC20 applications.
 *
 * Additionally, an {Approval} event is emitted on calls to {transferFrom}.
 * This allows applications to reconstruct the allowance for all accounts just
 * by listening to said events. Other implementations of the EIP may not emit
 * these events, as it isn't required by the specification.
 *
 * Finally, the non-standard {decreaseAllowance} and {increaseAllowance}
 * functions have been added to mitigate the well-known issues around setting
 * allowances. See {IERC20-approve}.
 */
contract ERC20 is Context, IERC20 {
    using SafeMath for uint256;
    using Address for address;

    mapping (address => uint256) private _balances;

    mapping (address => mapping (address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;
    uint8 private _decimals;

    /**
     * @dev Sets the values for {name} and {symbol}, initializes {decimals} with
     * a default value of 18.
     *
     * To select a different value for {decimals}, use {_setupDecimals}.
     *
     * All three of these values are immutable: they can only be set once during
     * construction.
     */
    constructor (string memory name, string memory symbol) public {
        _name = name;
        _symbol = symbol;
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
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view returns (uint8) {
        return _decimals;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20};
     *
     * Requirements:
     * - `sender` and `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     * - the caller must have allowance for ``sender``'s tokens of at least
     * `amount`.
     */
    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
        return true;
    }

    /**
     * @dev Moves tokens `amount` from `sender` to `recipient`.
     *
     * This is internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `sender` cannot be the zero address.
     * - `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     */
    function _transfer(address sender, address recipient, uint256 amount) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(sender, recipient, amount);

        _balances[sender] = _balances[sender].sub(amount, "ERC20: transfer amount exceeds balance");
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements
     *
     * - `to` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        _balances[account] = _balances[account].sub(amount, "ERC20: burn amount exceeds balance");
        _totalSupply = _totalSupply.sub(amount);
        emit Transfer(account, address(0), amount);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Sets {decimals} to a value other than the default one of 18.
     *
     * WARNING: This function should only be called from the constructor. Most
     * applications that interact with token contracts will not expect
     * {decimals} to ever change, and may work incorrectly if it does.
     */
    function _setupDecimals(uint8 decimals_) internal {
        _decimals = decimals_;
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be to transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual { }
}



// File: IUniswapV2ERC20.sol
// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

interface IUniswapV2ERC20 {
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
}


// File: MockERC20.sol
// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;


import "./ERC20.sol";


contract MockERC20 is ERC20 {
    constructor(
        string memory name,
        string memory symbol,
        uint256 supply
    ) public ERC20(name, symbol) {
        _mint(msg.sender, supply);
    }
}


// File: TenetProxyInner.sol
// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "./ERC20.sol";
import "./IERC20.sol";
import "./SafeERC20.sol";
import "./EnumerableSet.sol";
import "./SafeMath.sol";
import "./Ownable.sol";
import "./IUniswapV2Pair.sol";
import "./IUniswapV2Factory.sol";
import "./TenetMine.sol";
import "./Tenet.sol";

contract TenetProxyInner is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    uint256 public constant MINLPTOKEN_AMOUNT = 10000000000;
    uint256 public constant MINWEALTH_AMOUNT = 1000000000000000000;
    Tenet public tenet;
    TenetMine public tenetmine;
    address public wethAddr;
    address public wusdtAddr;
    IUniswapV2Factory public uniFactory;
    constructor(Tenet _tenet,address _weth,address _wusdt) public {
        tenet = _tenet;
        tenetmine = tenet.tenMineCalc();
        wethAddr = _weth;
        wusdtAddr = _wusdt;
        uniFactory = IUniswapV2Factory(IUniswapV2Pair(address(tenet.lpTokenTen())).factory());
    }
    function set_tenet(Tenet _tenet) public onlyOwner {
        tenet = _tenet;
        tenetmine = tenet.tenMineCalc();
    }    
    
    function getTenPoolNewInfo() public view returns (uint256[6] memory retDatas1,uint256[6] memory retDatas2,uint256[8] memory retDatas3) {
        retDatas1 = getTenUserPool();//(lastRewardBlock,accTenPerShare,allocPoint,lpTokenTotalAmount,totalAllocPoint,newBlockTen);
        retDatas2 = getTenProjectPool();//(lastRewardBlock,accTenPerShare,allocPoint,lpTokenTotalAmount,totalAllocPoint,newBlockTen);
        retDatas3 = getPoolPriceInfo(address(tenet.lpTokenTen()),address(tenet.ten()));//(lpSupply,reserve0,reserve1,pricetype,price0,price1,tokeneth,tokenusdt);
    }
    
    function getTokenPoolNewInfo(uint256 _pid) public view returns (uint256[8] memory retDatas1,uint256 newTenPerBlock,uint256[8] memory retDatas3) {
        retDatas1 = getPoolInfo(_pid);//(lastRewardBlock,lpTokenTotalAmount,accTokenPerShare,accTenPerShare,userCount,tenLPTokenAmount,rewardTenDebt,mineTokenAmount)
        newTenPerBlock = getTenPerBlockByProjectID(_pid);
        (address pairAddr,address tokenAddr, , , , , , , ) = tenet.poolSettingInfo(_pid);
        retDatas3 = getPoolPriceInfo(pairAddr,tokenAddr);//(lpSupply,reserve0,reserve1,pricetype,price0,price1,tokeneth,tokenusdt);
    }
    
    function getTenPoolBasicInfo() public view returns (address[5] memory retData1,uint256[3] memory retData2,uint256[8] memory retData3,uint256[50] memory retData4,string memory retData5,string memory retData6,string memory retData7) {
        address pairAddr = address(tenet.lpTokenTen());
        address tokenAddr = address(tenet.ten());
        (retData1,retData2,retData5,retData6,retData7) = getPairBasicInfo(pairAddr,tokenAddr);
        (retData3,retData4) = getTenPoolMineInfo();
    }
    
    function getTokenPoolBasicInfo(uint256 _pid) public view returns (address[5] memory retData1,uint256[3] memory retData2,address[3] memory retData3,uint256[6] memory retData4,string memory retData5,string memory retData6,string memory retData7) {
        (address pairAddr,address tokenAddr, , , , , , , ) = tenet.poolSettingInfo(_pid);
        (retData1,retData2,retData5,retData6,retData7) = getPairBasicInfo(pairAddr,tokenAddr);
        (retData3,retData4) = getTokenPoolMineInfo(_pid);
    }
    
    function getPoolPriceInfo(address pairAddr,address tokenAddr) public view returns (uint256[8] memory retDatas) {
        address factory = IUniswapV2Pair(pairAddr).factory();
        address token0Addr = IUniswapV2Pair(pairAddr).token0();
        address token1Addr = IUniswapV2Pair(pairAddr).token1();
        retDatas[0] = IUniswapV2Pair(pairAddr).totalSupply();
        (retDatas[1], retDatas[2],) = IUniswapV2Pair(pairAddr).getReserves();
        (retDatas[3],retDatas[4],retDatas[5]) = calcTokenPrice(IUniswapV2Factory(factory),token0Addr,token1Addr);
        (retDatas[6],retDatas[7]) = calcPrice(uniFactory,tokenAddr);
    }
    function getPairBasicInfo(address pairAddr,address tokenAddr) public view returns (address[5] memory retData1,uint256[3] memory retData2,string memory retData3,string memory retData4,string memory retData5) {
        retData1[0] = IUniswapV2Pair(pairAddr).factory();
        retData1[1] = pairAddr;
        retData1[2] = tokenAddr;
        retData1[3] = IUniswapV2Pair(pairAddr).token0();
        retData1[4] = IUniswapV2Pair(pairAddr).token1();
        (retData2[0],retData3) = getTokenInfo(retData1[2]);
        (retData2[1],retData4) = getTokenInfo(retData1[3]);
        (retData2[2],retData5) = getTokenInfo(retData1[4]);
    }    
    
    function getTenUserPool() public view returns (uint256[6] memory) {
        uint256[6] memory retDatas;
        (retDatas[0],retDatas[1],retDatas[2],retDatas[3]) = tenet.tenUserPool();
        retDatas[4] = tenet.totalAllocPoint();
        retDatas[5] = getTenPerBlockByUser();
        return retDatas;//(lastRewardBlock,accTenPerShare,allocPoint,lpTokenTotalAmount,totalAllocPoint,newBlockTen);
    }
    
    function getTenProjectPool() public view returns (uint256[6] memory) {
        uint256[6] memory retDatas;
        (retDatas[0],retDatas[1],retDatas[2],retDatas[3]) = tenet.tenProjectPool();
        retDatas[4] = tenet.totalAllocPoint();
        retDatas[5] = getTenPerBlockByProject();
        return retDatas;//(lastRewardBlock,accTenPerShare,allocPoint,lpTokenTotalAmount,totalAllocPoint,newBlockTen);
    }
    
    function getTenPoolMineInfo() public view returns (uint256[8] memory retData1,uint256[50] memory retData2) {
        retData1[0] = tenetmine.startBlock();
        retData1[1] = tenetmine.endBlock();
        retData1[2] = tenetmine.bonusEndBlock();
        retData1[3] = tenetmine.bonus_multiplier();
        retData1[4] = tenetmine.bonusTenPerBlock();
        retData1[5] = tenetmine.subBlockNumerPeriod();
        retData1[6] = tenetmine.totalSupply();
        retData1[7] = tenetmine.getMinePeriodCount();
        for(uint256 i=0;i<tenetmine.getMinePeriodCount();i++){
            if(i >= 50){
                break;
            }
            (retData2[i], )= tenetmine.allMinePeriodInfo(i);
        }
    }
    
    function getTokenPoolMineInfo(uint256 _pid) public view returns (address[3] memory retData1,uint256[6] memory retData2) {
        (retData1) = getPoolSettingInfo1(_pid);
        (retData2) = getPoolSettingInfo2(_pid);
    }
    function getPoolSettingInfo1(uint256 _pid) public view returns (address[3] memory retData1) {
        (retData1[0],retData1[1],retData1[2],,,,,,) = tenet.poolSettingInfo(_pid);
    }  
    function getPoolSettingInfo2(uint256 _pid) public view returns (uint256[6] memory retData2) {
        (,,,retData2[0],retData2[1],retData2[2],retData2[3],retData2[4],retData2[5]) = tenet.poolSettingInfo(_pid);
    }                    
    function getPoolInfo(uint256 _pid) public view returns (uint256[8] memory retData3) {
        (retData3[0],retData3[1],retData3[2],retData3[3],retData3[4],retData3[5],retData3[6],retData3[7]) = tenet.poolInfo(_pid);
    }    
    function getTokenInfo(address tokenAddr) public view returns (uint256 retData1,string memory retData2) {
        retData1 = ERC20(tokenAddr).decimals();
        retData2 = ERC20(tokenAddr).symbol();
    }
    
    function calcPrice(IUniswapV2Factory _factory,address tokenAddr) public view returns (uint256,uint256) {
        uint256 price0 = calcTokenWealth(_factory,tokenAddr,wethAddr);
        uint256 price1 = calcTokenWealth(_factory,tokenAddr,wusdtAddr);
        return (price0,price1);    
    }   
    
    function calcTokenPrice(IUniswapV2Factory _factory,address token0Addr,address token1Addr) public view returns (uint256,uint256,uint256) {
        uint256 pricetype = 0;
        uint256 price0 = 0;
        uint256 price1 = 0;     
        price0 = calcTokenWealth(_factory,token0Addr,wethAddr);
        if(price0 == 0){
            price1 = calcTokenWealth(_factory,token1Addr,wethAddr);
            if(price1 == 0){
                pricetype = 1;
                price0 = calcTokenWealth(_factory,token0Addr,wusdtAddr);
                if(price0 == 0){
                    price1 = calcTokenWealth(_factory,token1Addr,wusdtAddr);
                }
            }
        }
        return (pricetype,price0,price1);    
    }
    
    function calcETHPrice() public view returns (uint256) {
        IUniswapV2Pair pair = IUniswapV2Pair(uniFactory.getPair(wethAddr,wusdtAddr));
        if (address(pair) == address(0)) {
            return 0;
        }
        address token0 = pair.token0();
        (uint reserve0, uint reserve1,) = pair.getReserves();
        if(token0 == wethAddr){
            return reserve1.mul(MINWEALTH_AMOUNT).div(reserve0);
        }
        return reserve0.mul(MINWEALTH_AMOUNT).div(reserve1);
    }    
    
    function calcTokenWealth(IUniswapV2Factory _factory,address token,address wealth) public view returns (uint256) {
        if (token == wealth) {
           return MINWEALTH_AMOUNT;
        }
        IUniswapV2Pair pair = IUniswapV2Pair(_factory.getPair(token, wealth));
        if (address(pair) == address(0)) {
            return 0;
        }
        (uint reserve0, uint reserve1,) = pair.getReserves();
        if(token == pair.token0()){
            return reserve1.mul(MINWEALTH_AMOUNT).div(reserve0);
        }
        return reserve0.mul(MINWEALTH_AMOUNT).div(reserve1);
    }
    
    function getTenPerBlockByUser() public view returns (uint256 tenReward) {
        uint256[2] memory allTmpData; //allocPoint,lpSupply
        (,,allTmpData[0],allTmpData[1]) = tenet.tenUserPool();
        if (allTmpData[1] <= MINLPTOKEN_AMOUNT) {
            return 0;
        }        
        tenReward = tenetmine.calcMineTenReward(block.number-1, block.number);
        tenReward = tenReward.mul(allTmpData[0]).div(tenet.totalAllocPoint());
    }
    
    function getTenPerBlockByProject() public view returns (uint256 tenReward) {
        uint256[3] memory allTmpData; //lpTokenAmount,allocPoint,tenLPTokenAmount
        ( , ,allTmpData[0],allTmpData[1]) = tenet.tenProjectPool();
        if (allTmpData[1] <= MINLPTOKEN_AMOUNT) {
            return 0;
        }        
        tenReward = tenetmine.calcMineTenReward(block.number-1, block.number);
        tenReward = tenReward.mul(allTmpData[0]).div(tenet.totalAllocPoint());
    }      
    
    function getTenPerBlockByProjectID(uint _pid) public view returns (uint256 tenReward) {
        uint256[4] memory allTmpData; //lpTokenAmount,allocPoint,tenLPTokenAmount
        ( ,allTmpData[0], , , ,allTmpData[3], , ) = tenet.poolInfo(_pid);
        if(allTmpData[0] <= MINLPTOKEN_AMOUNT){
            return 0;
        }
        if (allTmpData[3] <= MINLPTOKEN_AMOUNT) {
            return 0;
        }
        ( , ,allTmpData[1],allTmpData[2]) = tenet.tenProjectPool();
        tenReward = tenetmine.calcMineTenReward(block.number-1, block.number);
        tenReward = tenReward.mul(allTmpData[3]).mul(allTmpData[1]).div(tenet.totalAllocPoint()).div(allTmpData[2]);
    }            
}


// File: Ownable.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "./Context.sol";
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
}



// File: SafeERC20.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "./IERC20.sol";
import "./SafeMath.sol";
import "./Address.sol";

/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
    using SafeMath for uint256;
    using Address for address;

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        // solhint-disable-next-line max-line-length
        require((value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).add(value);
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).sub(value, "SafeERC20: decreased allowance below zero");
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address.functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) { // Return data is optional
            // solhint-disable-next-line max-line-length
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}



// File: SafeMath.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

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



// File: GovernorAlpha.sol
// SPDX-License-Identifier: MIT
// COPIED FROM https://github.com/compound-finance/compound-protocol/blob/master/contracts/Governance/GovernorAlpha.sol
// Copyright 2020 Compound Labs, Inc.
// Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
// 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
// 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
// 3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
// Ctrl+f for XXX to see all the modifications.
// uint96s are changed to uint256s for simplicity and safety.

// XXX: pragma solidity ^0.5.16;
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "./TenetToken.sol";

contract GovernorAlpha {
    // @notice The name of this contract
    // XXX: string public constant name = "Compound Governor Alpha";
    string public constant name = "Tenet Governor Alpha";

    // @notice The number of votes in support of a proposal required in order for a quorum to be reached and for a vote to succeed
    // XXX: function quorumVotes() public pure returns (uint) { return 400000e18; } // 400,000 = 4% of Comp
    function quorumVotes() public view returns (uint) { return govToken.totalSupply() / 25; } // 4% of Supply

    // @notice The number of votes required in order for a voter to become a proposer
    // function proposalThreshold() public pure returns (uint) { return 100000e18; } // 100,000 = 1% of Comp
    function proposalThreshold() public view returns (uint) { return govToken.totalSupply() / 100; } // 1% of Supply

    // @notice The maximum number of actions that can be included in a proposal
    function proposalMaxOperations() public pure returns (uint) { return 10; } // 10 actions

    // @notice The delay before voting on a proposal may take place, once proposed
    function votingDelay() public pure returns (uint) { return 1; } // 1 block

    // @notice The duration of voting on a proposal, in blocks
    function votingPeriod() public pure returns (uint) { return 17280; } // ~3 days in blocks (assuming 15s blocks)

    // @notice The address of the Compound Protocol Timelock
    TimelockInterface public timelock;

    // @notice The address of the Compound governance token
    // XXX: CompInterface public comp;
    TenetToken public govToken;

    // @notice The address of the Governor Guardian
    address public guardian;

    // @notice The total number of proposals
    uint public proposalCount;

    struct Proposal {
        // @notice Unique id for looking up a proposal
        uint id;

        // @notice Creator of the proposal
        address proposer;

        // @notice The timestamp that the proposal will be available for execution, set once the vote succeeds
        uint eta;

        // @notice the ordered list of target addresses for calls to be made
        address[] targets;

        // @notice The ordered list of values (i.e. msg.value) to be passed to the calls to be made
        uint[] values;

        // @notice The ordered list of function signatures to be called
        string[] signatures;

        // @notice The ordered list of calldata to be passed to each call
        bytes[] calldatas;

        // @notice The block at which voting begins: holders must delegate their votes prior to this block
        uint startBlock;

        // @notice The block at which voting ends: votes must be cast prior to this block
        uint endBlock;

        // @notice Current number of votes in favor of this proposal
        uint forVotes;

        // @notice Current number of votes in opposition to this proposal
        uint againstVotes;

        // @notice Flag marking whether the proposal has been canceled
        bool canceled;

        // @notice Flag marking whether the proposal has been executed
        bool executed;

        // @notice Receipts of ballots for the entire set of voters
        mapping (address => Receipt) receipts;
    }

    // @notice Ballot receipt record for a voter
    struct Receipt {
        // @notice Whether or not a vote has been cast
        bool hasVoted;

        // @notice Whether or not the voter supports the proposal
        bool support;

        // @notice The number of votes the voter had, which were cast
        uint256 votes;
    }

    // @notice Possible states that a proposal may be in
    enum ProposalState {
        Pending,
        Active,
        Canceled,
        Defeated,
        Succeeded,
        Queued,
        Expired,
        Executed
    }

    // @notice The official record of all proposals ever proposed
    mapping (uint => Proposal) public proposals;

    // @notice The latest proposal for each proposer
    mapping (address => uint) public latestProposalIds;

    // @notice The EIP-712 typehash for the contract's domain
    bytes32 public constant DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");

    // @notice The EIP-712 typehash for the ballot struct used by the contract
    bytes32 public constant BALLOT_TYPEHASH = keccak256("Ballot(uint256 proposalId,bool support)");

    // @notice An event emitted when a new proposal is created
    event ProposalCreated(uint id, address proposer, address[] targets, uint[] values, string[] signatures, bytes[] calldatas, uint startBlock, uint endBlock, string description);

    // @notice An event emitted when a vote has been cast on a proposal
    event VoteCast(address voter, uint proposalId, bool support, uint votes);

    // @notice An event emitted when a proposal has been canceled
    event ProposalCanceled(uint id);

    // @notice An event emitted when a proposal has been queued in the Timelock
    event ProposalQueued(uint id, uint eta);

    // @notice An event emitted when a proposal has been executed in the Timelock
    event ProposalExecuted(uint id);

    constructor(address timelock_, address govToken_, address guardian_) public {
        timelock = TimelockInterface(timelock_);
        govToken = TenetToken(govToken_);
        guardian = guardian_;
    }

    function propose(address[] memory targets, uint[] memory values, string[] memory signatures, bytes[] memory calldatas, string memory description) public returns (uint) {
        require(govToken.getPriorVotes(msg.sender, sub256(block.number, 1)) > proposalThreshold(), "GovernorAlpha::propose: proposer votes below proposal threshold");
        require(targets.length == values.length && targets.length == signatures.length && targets.length == calldatas.length, "GovernorAlpha::propose: proposal function information arity mismatch");
        require(targets.length != 0, "GovernorAlpha::propose: must provide actions");
        require(targets.length <= proposalMaxOperations(), "GovernorAlpha::propose: too many actions");

        uint latestProposalId = latestProposalIds[msg.sender];
        if (latestProposalId != 0) {
          ProposalState proposersLatestProposalState = state(latestProposalId);
          require(proposersLatestProposalState != ProposalState.Active, "GovernorAlpha::propose: one live proposal per proposer, found an already active proposal");
          require(proposersLatestProposalState != ProposalState.Pending, "GovernorAlpha::propose: one live proposal per proposer, found an already pending proposal");
        }

        uint startBlock = add256(block.number, votingDelay());
        uint endBlock = add256(startBlock, votingPeriod());

        proposalCount++;
        Proposal memory newProposal = Proposal({
            id: proposalCount,
            proposer: msg.sender,
            eta: 0,
            targets: targets,
            values: values,
            signatures: signatures,
            calldatas: calldatas,
            startBlock: startBlock,
            endBlock: endBlock,
            forVotes: 0,
            againstVotes: 0,
            canceled: false,
            executed: false
        });

        proposals[newProposal.id] = newProposal;
        latestProposalIds[newProposal.proposer] = newProposal.id;

        emit ProposalCreated(newProposal.id, msg.sender, targets, values, signatures, calldatas, startBlock, endBlock, description);
        return newProposal.id;
    }

    function queue(uint proposalId) public {
        require(state(proposalId) == ProposalState.Succeeded, "GovernorAlpha::queue: proposal can only be queued if it is succeeded");
        Proposal storage proposal = proposals[proposalId];
        uint eta = add256(block.timestamp, timelock.delay());
        for (uint i = 0; i < proposal.targets.length; i++) {
            _queueOrRevert(proposal.targets[i], proposal.values[i], proposal.signatures[i], proposal.calldatas[i], eta);
        }
        proposal.eta = eta;
        emit ProposalQueued(proposalId, eta);
    }

    function _queueOrRevert(address target, uint value, string memory signature, bytes memory data, uint eta) internal {
        require(!timelock.queuedTransactions(keccak256(abi.encode(target, value, signature, data, eta))), "GovernorAlpha::_queueOrRevert: proposal action already queued at eta");
        timelock.queueTransaction(target, value, signature, data, eta);
    }

    function execute(uint proposalId) public payable {
        require(state(proposalId) == ProposalState.Queued, "GovernorAlpha::execute: proposal can only be executed if it is queued");
        Proposal storage proposal = proposals[proposalId];
        proposal.executed = true;
        for (uint i = 0; i < proposal.targets.length; i++) {
            timelock.executeTransaction.value(proposal.values[i])(proposal.targets[i], proposal.values[i], proposal.signatures[i], proposal.calldatas[i], proposal.eta);
        }
        emit ProposalExecuted(proposalId);
    }

    function cancel(uint proposalId) public {
        ProposalState state = state(proposalId);
        require(state != ProposalState.Executed, "GovernorAlpha::cancel: cannot cancel executed proposal");

        Proposal storage proposal = proposals[proposalId];
        require(msg.sender == guardian || govToken.getPriorVotes(proposal.proposer, sub256(block.number, 1)) < proposalThreshold(), "GovernorAlpha::cancel: proposer above threshold");

        proposal.canceled = true;
        for (uint i = 0; i < proposal.targets.length; i++) {
            timelock.cancelTransaction(proposal.targets[i], proposal.values[i], proposal.signatures[i], proposal.calldatas[i], proposal.eta);
        }

        emit ProposalCanceled(proposalId);
    }

    function getActions(uint proposalId) public view returns (address[] memory targets, uint[] memory values, string[] memory signatures, bytes[] memory calldatas) {
        Proposal storage p = proposals[proposalId];
        return (p.targets, p.values, p.signatures, p.calldatas);
    }

    function getReceipt(uint proposalId, address voter) public view returns (Receipt memory) {
        return proposals[proposalId].receipts[voter];
    }

    function state(uint proposalId) public view returns (ProposalState) {
        require(proposalCount >= proposalId && proposalId > 0, "GovernorAlpha::state: invalid proposal id");
        Proposal storage proposal = proposals[proposalId];
        if (proposal.canceled) {
            return ProposalState.Canceled;
        } else if (block.number <= proposal.startBlock) {
            return ProposalState.Pending;
        } else if (block.number <= proposal.endBlock) {
            return ProposalState.Active;
        } else if (proposal.forVotes <= proposal.againstVotes || proposal.forVotes < quorumVotes()) {
            return ProposalState.Defeated;
        } else if (proposal.eta == 0) {
            return ProposalState.Succeeded;
        } else if (proposal.executed) {
            return ProposalState.Executed;
        } else if (block.timestamp >= add256(proposal.eta, timelock.GRACE_PERIOD())) {
            return ProposalState.Expired;
        } else {
            return ProposalState.Queued;
        }
    }

    function castVote(uint proposalId, bool support) public {
        return _castVote(msg.sender, proposalId, support);
    }

    function castVoteBySig(uint proposalId, bool support, uint8 v, bytes32 r, bytes32 s) public {
        bytes32 domainSeparator = keccak256(abi.encode(DOMAIN_TYPEHASH, keccak256(bytes(name)), getChainId(), address(this)));
        bytes32 structHash = keccak256(abi.encode(BALLOT_TYPEHASH, proposalId, support));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        address signatory = ecrecover(digest, v, r, s);
        require(signatory != address(0), "GovernorAlpha::castVoteBySig: invalid signature");
        return _castVote(signatory, proposalId, support);
    }

    function _castVote(address voter, uint proposalId, bool support) internal {
        require(state(proposalId) == ProposalState.Active, "GovernorAlpha::_castVote: voting is closed");
        Proposal storage proposal = proposals[proposalId];
        Receipt storage receipt = proposal.receipts[voter];
        require(receipt.hasVoted == false, "GovernorAlpha::_castVote: voter already voted");
        uint256 votes = govToken.getPriorVotes(voter, proposal.startBlock);

        if (support) {
            proposal.forVotes = add256(proposal.forVotes, votes);
        } else {
            proposal.againstVotes = add256(proposal.againstVotes, votes);
        }

        receipt.hasVoted = true;
        receipt.support = support;
        receipt.votes = votes;

        emit VoteCast(voter, proposalId, support, votes);
    }

    function __acceptAdmin() public {
        require(msg.sender == guardian, "GovernorAlpha::__acceptAdmin: sender must be gov guardian");
        timelock.acceptAdmin();
    }

    function __abdicate() public {
        require(msg.sender == guardian, "GovernorAlpha::__abdicate: sender must be gov guardian");
        guardian = address(0);
    }

    function __queueSetTimelockPendingAdmin(address newPendingAdmin, uint eta) public {
        require(msg.sender == guardian, "GovernorAlpha::__queueSetTimelockPendingAdmin: sender must be gov guardian");
        timelock.queueTransaction(address(timelock), 0, "setPendingAdmin(address)", abi.encode(newPendingAdmin), eta);
    }

    function __executeSetTimelockPendingAdmin(address newPendingAdmin, uint eta) public {
        require(msg.sender == guardian, "GovernorAlpha::__executeSetTimelockPendingAdmin: sender must be gov guardian");
        timelock.executeTransaction(address(timelock), 0, "setPendingAdmin(address)", abi.encode(newPendingAdmin), eta);
    }

    function add256(uint256 a, uint256 b) internal pure returns (uint) {
        uint c = a + b;
        require(c >= a, "addition overflow");
        return c;
    }

    function sub256(uint256 a, uint256 b) internal pure returns (uint) {
        require(b <= a, "subtraction underflow");
        return a - b;
    }

    function getChainId() internal pure returns (uint) {
        uint chainId;
        assembly { chainId := chainid() }
        return chainId;
    }
}

interface TimelockInterface {
    function delay() external view returns (uint);
    function GRACE_PERIOD() external view returns (uint);
    function acceptAdmin() external;
    function queuedTransactions(bytes32 hash) external view returns (bool);
    function queueTransaction(address target, uint value, string calldata signature, bytes calldata data, uint eta) external returns (bytes32);
    function cancelTransaction(address target, uint value, string calldata signature, bytes calldata data, uint eta) external;
    function executeTransaction(address target, uint value, string calldata signature, bytes calldata data, uint eta) external payable returns (bytes memory);
}



// File: TenetMine.sol
// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;


import "./IERC20.sol";
import "./SafeERC20.sol";
import "./EnumerableSet.sol";
import "./SafeMath.sol";
import "./Ownable.sol";
contract TenetMine is Ownable {
    using SafeMath for uint256;
    struct MinePeriodInfo {
        uint256 tenPerBlockPeriod;
        uint256 totalTenPeriod;
    }
    uint256 public bonusEndBlock;
    uint256 public bonus_multiplier;
    uint256 public bonusTenPerBlock;
    uint256 public startBlock;
    uint256 public endBlock;
    uint256 public subBlockNumerPeriod;
    uint256 public totalSupply;
    MinePeriodInfo[] public allMinePeriodInfo;

    constructor(
        uint256 _startBlock,   
        uint256 _bonusEndBlockOffset,
        uint256 _bonus_multiplier,
        uint256 _bonusTenPerBlock,
        uint256 _subBlockNumerPeriod,
        uint256[] memory _tenPerBlockPeriod
    ) public {
        startBlock = _startBlock>0 ? _startBlock : block.number + 1;
        bonusEndBlock = startBlock.add(_bonusEndBlockOffset);
        bonus_multiplier = _bonus_multiplier;
        bonusTenPerBlock = _bonusTenPerBlock;
        subBlockNumerPeriod = _subBlockNumerPeriod;
        totalSupply = bonusEndBlock.sub(startBlock).mul(bonusTenPerBlock).mul(bonus_multiplier);
        for (uint256 i = 0; i < _tenPerBlockPeriod.length; i++) {
            allMinePeriodInfo.push(MinePeriodInfo({
                tenPerBlockPeriod: _tenPerBlockPeriod[i],
                totalTenPeriod: totalSupply
            }));
            totalSupply = totalSupply.add(subBlockNumerPeriod.mul(_tenPerBlockPeriod[i]));
        }
        endBlock = bonusEndBlock.add(subBlockNumerPeriod.mul(_tenPerBlockPeriod.length));        
    }
    function set_startBlock(uint256 _startBlock) public onlyOwner {
		require(block.number < _startBlock, "set_startBlock: startBlock invalid");
        uint256 bonusEndBlockOffset = bonusEndBlock.sub(startBlock);
        startBlock = _startBlock>0 ? _startBlock : block.number + 1;
        bonusEndBlock = startBlock.add(bonusEndBlockOffset);
        endBlock = bonusEndBlock.add(subBlockNumerPeriod.mul(allMinePeriodInfo.length));
	}
    function getMinePeriodCount() public view returns (uint256) {
        return allMinePeriodInfo.length;
    }
    function calcMineTenReward(uint256 _from,uint256 _to) public view returns (uint256) {
        if(_from < startBlock){
            _from = startBlock;
        }
        if(_from >= endBlock){
            return 0;
        }
        if(_from >= _to){
            return 0;
        }
        uint256 mineFrom = calcTotalMine(_from);
        uint256 mineTo= calcTotalMine(_to);
        return mineTo.sub(mineFrom);
    }
    function calcTotalMine(uint256 _to) public view returns (uint256 totalMine) {
        if(_to <= startBlock){
            totalMine = 0;
        }else if(_to <= bonusEndBlock){
            totalMine = _to.sub(startBlock).mul(bonusTenPerBlock).mul(bonus_multiplier);
        }else if(_to < endBlock){
            uint256 periodIndex = _to.sub(bonusEndBlock).div(subBlockNumerPeriod);
            uint256 periodBlock = _to.sub(bonusEndBlock).mod(subBlockNumerPeriod);
            MinePeriodInfo memory minePeriodInfo = allMinePeriodInfo[periodIndex];
            uint256 curMine = periodBlock.mul(minePeriodInfo.tenPerBlockPeriod);
            totalMine = curMine.add(minePeriodInfo.totalTenPeriod);
        }else{
            totalMine = totalSupply;
        }
    }    
    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to,uint256 _end,uint256 _tokenBonusEndBlock,uint256 _tokenBonusMultipler) public pure returns (uint256) {
        if(_to > _end){
            _to = _end;
        }
        if(_from>_end){
            return 0;
        }else if (_to <= _tokenBonusEndBlock) {
            return _to.sub(_from).mul(_tokenBonusMultipler);
        } else if (_from >= _tokenBonusEndBlock) {
            return _to.sub(_from);
        } else {
            return _tokenBonusEndBlock.sub(_from).mul(_tokenBonusMultipler).add(_to.sub(_tokenBonusEndBlock));
        }
    }    
}



// File: Address.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.6.2;

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
        // This method relies in extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        // solhint-disable-next-line no-inline-assembly
        assembly { size := extcodesize(account) }
        return size > 0;
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



// File: Migrations.sol
// SPDX-License-Identifier: MIT
pragma solidity >=0.4.25 <0.7.0;

contract Migrations {
  address public owner;
  uint public last_completed_migration;

  modifier restricted() {
    if (msg.sender == owner) _;
  }

  constructor() public {
    owner = msg.sender;
  }

  function setCompleted(uint completed) public restricted {
    last_completed_migration = completed;
  }
}



// File: Timelock.sol
// SPDX-License-Identifier: MIT
// COPIED FROM https://github.com/compound-finance/compound-protocol/blob/master/contracts/Governance/GovernorAlpha.sol
// Copyright 2020 Compound Labs, Inc.
// Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
// 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
// 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
// 3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
// Ctrl+f for XXX to see all the modifications.

// XXX: pragma solidity ^0.5.16;
pragma solidity 0.6.12;

// XXX: import "./SafeMath.sol";
import "./SafeMath.sol";

contract Timelock {
    using SafeMath for uint;

    event NewAdmin(address indexed newAdmin);
    event NewPendingAdmin(address indexed newPendingAdmin);
    event NewDelay(uint indexed newDelay);
    event CancelTransaction(bytes32 indexed txHash, address indexed target, uint value, string signature,  bytes data, uint eta);
    event ExecuteTransaction(bytes32 indexed txHash, address indexed target, uint value, string signature,  bytes data, uint eta);
    event QueueTransaction(bytes32 indexed txHash, address indexed target, uint value, string signature, bytes data, uint eta);

    uint public constant GRACE_PERIOD = 14 days;
    uint public constant MINIMUM_DELAY = 2 days;
    uint public constant MAXIMUM_DELAY = 30 days;

    address public admin;
    address public pendingAdmin;
    uint public delay;
    bool public admin_initialized;

    mapping (bytes32 => bool) public queuedTransactions;


    constructor(address admin_, uint delay_) public {
        require(delay_ >= MINIMUM_DELAY, "Timelock::constructor: Delay must exceed minimum delay.");
        require(delay_ <= MAXIMUM_DELAY, "Timelock::constructor: Delay must not exceed maximum delay.");

        admin = admin_;
        delay = delay_;
        admin_initialized = false;
    }

    // XXX: function() external payable { }
    receive() external payable { }

    function setDelay(uint delay_) public {
        require(msg.sender == address(this), "Timelock::setDelay: Call must come from Timelock.");
        require(delay_ >= MINIMUM_DELAY, "Timelock::setDelay: Delay must exceed minimum delay.");
        require(delay_ <= MAXIMUM_DELAY, "Timelock::setDelay: Delay must not exceed maximum delay.");
        delay = delay_;

        emit NewDelay(delay);
    }

    function acceptAdmin() public {
        require(msg.sender == pendingAdmin, "Timelock::acceptAdmin: Call must come from pendingAdmin.");
        admin = msg.sender;
        pendingAdmin = address(0);

        emit NewAdmin(admin);
    }

    function setPendingAdmin(address pendingAdmin_) public {
        // allows one time setting of admin for deployment purposes
        if (admin_initialized) {
            require(msg.sender == address(this), "Timelock::setPendingAdmin: Call must come from Timelock.");
        } else {
            require(msg.sender == admin, "Timelock::setPendingAdmin: First call must come from admin.");
            admin_initialized = true;
        }
        pendingAdmin = pendingAdmin_;

        emit NewPendingAdmin(pendingAdmin);
    }

    function queueTransaction(address target, uint value, string memory signature, bytes memory data, uint eta) public returns (bytes32) {
        require(msg.sender == admin, "Timelock::queueTransaction: Call must come from admin.");
        require(eta >= getBlockTimestamp().add(delay), "Timelock::queueTransaction: Estimated execution block must satisfy delay.");

        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
        queuedTransactions[txHash] = true;

        emit QueueTransaction(txHash, target, value, signature, data, eta);
        return txHash;
    }

    function cancelTransaction(address target, uint value, string memory signature, bytes memory data, uint eta) public {
        require(msg.sender == admin, "Timelock::cancelTransaction: Call must come from admin.");

        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
        queuedTransactions[txHash] = false;

        emit CancelTransaction(txHash, target, value, signature, data, eta);
    }

    function executeTransaction(address target, uint value, string memory signature, bytes memory data, uint eta) public payable returns (bytes memory) {
        require(msg.sender == admin, "Timelock::executeTransaction: Call must come from admin.");

        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
        require(queuedTransactions[txHash], "Timelock::executeTransaction: Transaction hasn't been queued.");
        require(getBlockTimestamp() >= eta, "Timelock::executeTransaction: Transaction hasn't surpassed time lock.");
        require(getBlockTimestamp() <= eta.add(GRACE_PERIOD), "Timelock::executeTransaction: Transaction is stale.");

        queuedTransactions[txHash] = false;

        bytes memory callData;

        if (bytes(signature).length == 0) {
            callData = data;
        } else {
            callData = abi.encodePacked(bytes4(keccak256(bytes(signature))), data);
        }

        // solium-disable-next-line security/no-call-value
        (bool success, bytes memory returnData) = target.call.value(value)(callData);
        require(success, "Timelock::executeTransaction: Transaction execution reverted.");

        emit ExecuteTransaction(txHash, target, value, signature, data, eta);

        return returnData;
    }

    function getBlockTimestamp() internal view returns (uint) {
        // solium-disable-next-line security/no-block-members
        return block.timestamp;
    }
}


// File: EnumerableSet.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

/**
 * @dev Library for managing
 * https://en.wikipedia.org/wiki/Set_(abstract_data_type)[sets] of primitive
 * types.
 *
 * Sets have the following properties:
 *
 * - Elements are added, removed, and checked for existence in constant time
 * (O(1)).
 * - Elements are enumerated in O(n). No guarantees are made on the ordering.
 *
 * ```
 * contract Example {
 *     // Add the library methods
 *     using EnumerableSet for EnumerableSet.AddressSet;
 *
 *     // Declare a set state variable
 *     EnumerableSet.AddressSet private mySet;
 * }
 * ```
 *
 * As of v3.0.0, only sets of type `address` (`AddressSet`) and `uint256`
 * (`UintSet`) are supported.
 */
library EnumerableSet {
    // To implement this library for multiple types with as little code
    // repetition as possible, we write it in terms of a generic Set type with
    // bytes32 values.
    // The Set implementation uses private functions, and user-facing
    // implementations (such as AddressSet) are just wrappers around the
    // underlying Set.
    // This means that we can only create new EnumerableSets for types that fit
    // in bytes32.

    struct Set {
        // Storage of set values
        bytes32[] _values;

        // Position of the value in the `values` array, plus 1 because index 0
        // means a value is not in the set.
        mapping (bytes32 => uint256) _indexes;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function _add(Set storage set, bytes32 value) private returns (bool) {
        if (!_contains(set, value)) {
            set._values.push(value);
            // The value is stored at length-1, but we add 1 to all indexes
            // and use 0 as a sentinel value
            set._indexes[value] = set._values.length;
            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function _remove(Set storage set, bytes32 value) private returns (bool) {
        // We read and store the value's index to prevent multiple reads from the same storage slot
        uint256 valueIndex = set._indexes[value];

        if (valueIndex != 0) { // Equivalent to contains(set, value)
            // To delete an element from the _values array in O(1), we swap the element to delete with the last one in
            // the array, and then remove the last element (sometimes called as 'swap and pop').
            // This modifies the order of the array, as noted in {at}.

            uint256 toDeleteIndex = valueIndex - 1;
            uint256 lastIndex = set._values.length - 1;

            // When the value to delete is the last one, the swap operation is unnecessary. However, since this occurs
            // so rarely, we still do the swap anyway to avoid the gas cost of adding an 'if' statement.

            bytes32 lastvalue = set._values[lastIndex];

            // Move the last value to the index where the value to delete is
            set._values[toDeleteIndex] = lastvalue;
            // Update the index for the moved value
            set._indexes[lastvalue] = toDeleteIndex + 1; // All indexes are 1-based

            // Delete the slot where the moved value was stored
            set._values.pop();

            // Delete the index for the deleted slot
            delete set._indexes[value];

            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function _contains(Set storage set, bytes32 value) private view returns (bool) {
        return set._indexes[value] != 0;
    }

    /**
     * @dev Returns the number of values on the set. O(1).
     */
    function _length(Set storage set) private view returns (uint256) {
        return set._values.length;
    }

   /**
    * @dev Returns the value stored at position `index` in the set. O(1).
    *
    * Note that there are no guarantees on the ordering of values inside the
    * array, and it may change when more values are added or removed.
    *
    * Requirements:
    *
    * - `index` must be strictly less than {length}.
    */
    function _at(Set storage set, uint256 index) private view returns (bytes32) {
        require(set._values.length > index, "EnumerableSet: index out of bounds");
        return set._values[index];
    }

    // AddressSet

    struct AddressSet {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(AddressSet storage set, address value) internal returns (bool) {
        return _add(set._inner, bytes32(uint256(value)));
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(AddressSet storage set, address value) internal returns (bool) {
        return _remove(set._inner, bytes32(uint256(value)));
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(AddressSet storage set, address value) internal view returns (bool) {
        return _contains(set._inner, bytes32(uint256(value)));
    }

    /**
     * @dev Returns the number of values in the set. O(1).
     */
    function length(AddressSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

   /**
    * @dev Returns the value stored at position `index` in the set. O(1).
    *
    * Note that there are no guarantees on the ordering of values inside the
    * array, and it may change when more values are added or removed.
    *
    * Requirements:
    *
    * - `index` must be strictly less than {length}.
    */
    function at(AddressSet storage set, uint256 index) internal view returns (address) {
        return address(uint256(_at(set._inner, index)));
    }


    // UintSet

    struct UintSet {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(UintSet storage set, uint256 value) internal returns (bool) {
        return _add(set._inner, bytes32(value));
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(UintSet storage set, uint256 value) internal returns (bool) {
        return _remove(set._inner, bytes32(value));
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(UintSet storage set, uint256 value) internal view returns (bool) {
        return _contains(set._inner, bytes32(value));
    }

    /**
     * @dev Returns the number of values on the set. O(1).
     */
    function length(UintSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

   /**
    * @dev Returns the value stored at position `index` in the set. O(1).
    *
    * Note that there are no guarantees on the ordering of values inside the
    * array, and it may change when more values are added or removed.
    *
    * Requirements:
    *
    * - `index` must be strictly less than {length}.
    */
    function at(UintSet storage set, uint256 index) internal view returns (uint256) {
        return uint256(_at(set._inner, index));
    }
}



// File: TenetToken.sol
// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;


import "./ERC20.sol";
import "./Ownable.sol";


// TntToken with Governance.
contract TenetToken is ERC20("Tenet", "TEN"), Ownable {
    // @notice Creates `_amount` token to `_to`. Must only be called by the owner (MasterChef).
    function mint(address _to, uint256 _amount) public onlyOwner {
        _mint(_to, _amount);
        _moveDelegates(address(0), _delegates[_to], _amount);
    }
    function burn(address _account, uint256 _amount) public onlyOwner {
        _burn(_account, _amount);
    }
    // Copied and modified from YAM code:
    // https://github.com/yam-finance/yam-protocol/blob/master/contracts/token/YAMGovernanceStorage.sol
    // https://github.com/yam-finance/yam-protocol/blob/master/contracts/token/YAMGovernance.sol
    // Which is copied and modified from COMPOUND:
    // https://github.com/compound-finance/compound-protocol/blob/master/contracts/Governance/Comp.sol

    // @notice A record of each accounts delegate
    mapping (address => address) internal _delegates;

    // @notice A checkpoint for marking number of votes from a given block
    struct Checkpoint {
        uint32 fromBlock;
        uint256 votes;
    }

    // @notice A record of votes checkpoints for each account, by index
    mapping (address => mapping (uint32 => Checkpoint)) public checkpoints;

    // @notice The number of checkpoints for each account
    mapping (address => uint32) public numCheckpoints;

    // @notice The EIP-712 typehash for the contract's domain
    bytes32 public constant DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");

    // @notice The EIP-712 typehash for the delegation struct used by the contract
    bytes32 public constant DELEGATION_TYPEHASH = keccak256("Delegation(address delegatee,uint256 nonce,uint256 expiry)");

    // @notice A record of states for signing / validating signatures
    mapping (address => uint) public nonces;

    // @notice An event thats emitted when an account changes its delegate
    event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);

    // @notice An event thats emitted when a delegate account's vote balance changes
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
        require(signatory != address(0), "delegateBySig: invalid signature");
        require(nonce == nonces[signatory]++, "delegateBySig: invalid nonce");
        require(now <= expiry, "delegateBySig: signature expired");
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
        uint32 nCheckpoints = numCheckpoints[account];
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
        require(blockNumber < block.number, "getPriorVotes: not yet determined");

        uint32 nCheckpoints = numCheckpoints[account];
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

        uint32 lower = 0;
        uint32 upper = nCheckpoints - 1;
        while (upper > lower) {
            uint32 center = upper - (upper - lower) / 2; // ceil, avoiding overflow
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
        uint256 delegatorBalance = balanceOf(delegator); // balance of underlying TNTs (not scaled);
        _delegates[delegator] = delegatee;

        emit DelegateChanged(delegator, currentDelegate, delegatee);

        _moveDelegates(currentDelegate, delegatee, delegatorBalance);
    }

    function _moveDelegates(address srcRep, address dstRep, uint256 amount) internal {
        if (srcRep != dstRep && amount > 0) {
            if (srcRep != address(0)) {
                // decrease old representative
                uint32 srcRepNum = numCheckpoints[srcRep];
                uint256 srcRepOld = srcRepNum > 0 ? checkpoints[srcRep][srcRepNum - 1].votes : 0;
                uint256 srcRepNew = srcRepOld.sub(amount);
                _writeCheckpoint(srcRep, srcRepNum, srcRepOld, srcRepNew);
            }

            if (dstRep != address(0)) {
                // increase new representative
                uint32 dstRepNum = numCheckpoints[dstRep];
                uint256 dstRepOld = dstRepNum > 0 ? checkpoints[dstRep][dstRepNum - 1].votes : 0;
                uint256 dstRepNew = dstRepOld.add(amount);
                _writeCheckpoint(dstRep, dstRepNum, dstRepOld, dstRepNew);
            }
        }
    }

    function _writeCheckpoint(
        address delegatee,
        uint32 nCheckpoints,
        uint256 oldVotes,
        uint256 newVotes
    )
        internal
    {
        uint32 blockNumber = safe32(block.number, "_writeCheckpoint: block number exceeds 32 bits");

        if (nCheckpoints > 0 && checkpoints[delegatee][nCheckpoints - 1].fromBlock == blockNumber) {
            checkpoints[delegatee][nCheckpoints - 1].votes = newVotes;
        } else {
            checkpoints[delegatee][nCheckpoints] = Checkpoint(blockNumber, newVotes);
            numCheckpoints[delegatee] = nCheckpoints + 1;
        }

        emit DelegateVotesChanged(delegatee, oldVotes, newVotes);
    }

    function safe32(uint n, string memory errorMessage) internal pure returns (uint32) {
        require(n < 2**32, errorMessage);
        return uint32(n);
    }

    function getChainId() internal pure returns (uint) {
        uint256 chainId;
        assembly { chainId := chainid() }
        return chainId;
    }
}


// File: TenetSwap.sol
// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;


import "./IERC20.sol";
import "./SafeERC20.sol";
import "./EnumerableSet.sol";
import "./SafeMath.sol";
import "./Ownable.sol";
import "./IUniswapV2Pair.sol";
import "./IUniswapV2Factory.sol";
import "./Tenet.sol";
interface IWETH {
    function deposit() external payable;
    function transfer(address to, uint value) external returns (bool);
    function withdraw(uint) external;
}
contract TenetSwap is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    Tenet public tenetAddr;
    address public wethAddr;

    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, 'TenetSwap: EXPIRED');
        _;
    }
    event TransferTokenToLPToken(address indexed user, uint256 indexed pid, address tokenAddr,uint256 tokenAmount,address lpTokenAddr, uint256 lpTenAmount);
    event TransferTokensToLPToken(address indexed user, uint256 indexed pid, uint256 token0Amount,uint256 token1Amount,address lpTokenAddr, uint256 lpTenAmount);
    event ChangeLPToken(address indexed user,address lpTokenAddr,uint256 token0Amount,uint256 token1Amount,uint256 lpTenAmount);

    constructor(address _tenetAddr,address _wethAddr) public {
         tenetAddr = Tenet(_tenetAddr);
         wethAddr = _wethAddr;
    }
    function set_tenet(Tenet _tenet) public onlyOwner {
        tenetAddr = _tenet;
    }    
    receive() external payable {
        assert(msg.sender == wethAddr); // only accept ETH via fallback from the WETH contract
    }
    function _calcLiquidAmountIn(address _pairAddr,uint256[2] memory _amountDesired,uint256 _amountMinRate) internal virtual view returns (uint amount0, uint amount1) {
        require(_amountMinRate <= 1000, 'addLiquidity: INSUFFICIENT_AMOUNT_MINRATE');
        uint256[2] memory _amountMin;
        _amountMin[0] = _amountDesired[0].mul(_amountMinRate).div(1000);
        _amountMin[1] = _amountDesired[1].mul(_amountMinRate).div(1000);
        uint256[2] memory _reserve;
        (_reserve[0],_reserve[1],) = IUniswapV2Pair(_pairAddr).getReserves();
        uint amount1Optimal = _amountDesired[0].mul(_reserve[1]).div(_reserve[0]);
        if (amount1Optimal <= _amountDesired[1]) {
            require(amount1Optimal >= _amountMin[1], '_addLiquidity: INSUFFICIENT_1_AMOUNT');
            (amount0, amount1) = (_amountDesired[0], amount1Optimal);
        } else {
            uint amount0Optimal = _amountDesired[1].mul(_reserve[0]).div(_reserve[1]);
            assert(amount0Optimal <= _amountDesired[0]);
            require(amount0Optimal >= _amountMin[0], '_addLiquidity: INSUFFICIENT_0_AMOUNT');
            (amount0, amount1) = (amount0Optimal, _amountDesired[1]);
        }
    }
    function _transferToPair(address _tokenAddr,address _fromAddr, address _toAddr, uint256 _value) internal {
        if(_tokenAddr == wethAddr){
            IWETH(_tokenAddr).transfer(_toAddr, _value);
        }else{
            if(_fromAddr == address(this)){
                IERC20(_tokenAddr).transfer(_toAddr, _value);
            }else{
                IERC20(_tokenAddr).transferFrom(_fromAddr,_toAddr, _value);
            }
        }
    }
    function _returnToUser(address _tokenAddr,address _fromAddr,uint256 _value) internal{
        if(_value > 0){
            if(_tokenAddr == wethAddr){
                IWETH(_tokenAddr).withdraw(_value);
                msg.sender.transfer(_value);
            }else{
                if(_fromAddr == address(this)){
                    IERC20(_tokenAddr).transfer(msg.sender, _value);
                }
            }
        }
    }    
    function _addLiquidity(address _fromAddr,address _pairAddr,uint256[2] memory _amountDesired,address to,uint256 _amountMinRate) internal returns (uint256) {
        address[2] memory _tokenAddr;
        _tokenAddr[0] = IUniswapV2Pair(_pairAddr).token0();
        _tokenAddr[1] = IUniswapV2Pair(_pairAddr).token1();        
        (uint256 amountA,uint256 amountB) = _calcLiquidAmountIn(_pairAddr, _amountDesired, _amountMinRate);
        _transferToPair(_tokenAddr[0],_fromAddr,_pairAddr,amountA);
        _transferToPair(_tokenAddr[1],_fromAddr,_pairAddr,amountB);
        uint256 liquidity = IUniswapV2Pair(_pairAddr).mint(to);
        _returnToUser(_tokenAddr[0],_fromAddr,_amountDesired[0].sub(amountA));
        _returnToUser(_tokenAddr[1],_fromAddr,_amountDesired[1].sub(amountB));
        return liquidity;
    }    
    function getPrice(address _pairAddr, address _fromAddr) public view returns (uint256) {
        (uint256 reserve0, uint256 reserve1,) = IUniswapV2Pair(_pairAddr).getReserves();
        if(_fromAddr == IUniswapV2Pair(_pairAddr).token0()){
            return reserve1.mul(1e12).div(reserve0);
        }else{
            return reserve0.mul(1e12).div(reserve1);
        }
    }
    function getAmountOut(address _pairAddr, address _fromAddr,uint amountIn) public view virtual returns (uint256){
        require(amountIn > 0, 'getAmountOut: INSUFFICIENT_INPUT_AMOUNT');
        (uint256 reserve0, uint256 reserve1,) = IUniswapV2Pair(_pairAddr).getReserves();
        require(reserve0 > 0 && reserve1 > 0, 'getAmountOut: INSUFFICIENT_LIQUIDITY');
        if(_fromAddr == IUniswapV2Pair(_pairAddr).token0()){
            uint amountInWithFee = amountIn.mul(997);
            uint numerator = amountInWithFee.mul(reserve1);
            uint denominator = reserve0.mul(1000).add(amountInWithFee);
            return numerator.div(denominator);
        }else{
            uint amountInWithFee = amountIn.mul(997);
            uint numerator = amountInWithFee.mul(reserve0);
            uint denominator = reserve1.mul(1000).add(amountInWithFee);
            return numerator.div(denominator);
        }
    }
    function _swapToken(address _pairAddr, address _fromAddr,uint256 _tokenAmount) internal returns (uint256) {
        uint256 tokenAmountOut = getAmountOut(_pairAddr,_fromAddr,_tokenAmount);
        if(_fromAddr == wethAddr){
            IWETH(_fromAddr).transfer(_pairAddr, _tokenAmount);
        }else{
            IERC20(_fromAddr).transfer(_pairAddr, _tokenAmount);
        }
        if(_fromAddr == IUniswapV2Pair(_pairAddr).token0()){
            IUniswapV2Pair(_pairAddr).swap(0, tokenAmountOut, address(this), new bytes(0));
        }else{
            IUniswapV2Pair(_pairAddr).swap(tokenAmountOut, 0, address(this), new bytes(0));
        }
        return tokenAmountOut;
    }
    function _transferTokensOut(address _pairAddr,address _tokenAddr,uint256 _tokenAmount) internal returns (uint256,uint256) {
        IUniswapV2Factory factory = IUniswapV2Factory(IUniswapV2Pair(_pairAddr).factory());
        require(address(factory) != address(0), 'transferTokensOut: INSUFFICIENT_PAIR');
        uint256[8] memory dataAll;
        (dataAll[6], dataAll[7],) = IUniswapV2Pair(_pairAddr).getReserves();
        require(dataAll[6] > 0, 'transferTokensOut: INSUFFICIENT_RESERVE0');
        require(dataAll[7] > 0, 'transferTokensOut: INSUFFICIENT_RESERVE1');   
        address[2] memory allPairAddr;
        allPairAddr[0] = factory.getPair(_tokenAddr,IUniswapV2Pair(_pairAddr).token0());
        require(allPairAddr[0] != address(0), 'transferTokensOut: INVALID_PAIR0');
        dataAll[0] = getPrice(allPairAddr[0],_tokenAddr);
        allPairAddr[1] = factory.getPair(_tokenAddr,IUniswapV2Pair(_pairAddr).token1());
        require(allPairAddr[1] != address(0), 'transferTokensOut: INVALID_PAIR1');
        dataAll[1] = getPrice(allPairAddr[1],_tokenAddr);
        dataAll[2] = _tokenAmount.mul(dataAll[1]).mul(dataAll[6]).div(dataAll[0].mul(dataAll[7]).add(dataAll[1].mul(dataAll[6])));
        dataAll[3] = _tokenAmount.sub(dataAll[2]);
        dataAll[4] = _swapToken(allPairAddr[0],_tokenAddr,dataAll[2]);
        dataAll[5] = _swapToken(allPairAddr[1],_tokenAddr,dataAll[3]);
        return (dataAll[4],dataAll[5]);            
    }
    function _transferTokenXOut(address _pairAddr,address _tokenAddr,uint256 _tokenAmount,uint256 tokenType) internal returns (uint256,uint256) {
        IUniswapV2Factory factory = IUniswapV2Factory(IUniswapV2Pair(_pairAddr).factory());
        require(address(factory) != address(0), 'transferTokenXOut: INSUFFICIENT_PAIR');
        uint256[4] memory dataAll;
        (dataAll[0], dataAll[1],) = IUniswapV2Pair(_pairAddr).getReserves();
        require(dataAll[0] > 0, 'transferTokenXOut: INSUFFICIENT_RESERVE0');
        require(dataAll[1] > 0, 'transferTokenXOut: INSUFFICIENT_RESERVE1');   
        dataAll[2] = _tokenAmount.div(2);
        dataAll[3] = _swapToken(_pairAddr,_tokenAddr,dataAll[2]);
        if(tokenType == 0){
            return (dataAll[2],dataAll[3]);
        }else{
            return (dataAll[3],dataAll[2]);
        }
    }
    function _transferLPToken(uint256 _poolType,uint256 _pid,address _pairAddr,uint256[2] memory _tokenAmountOut,uint256 _amountMinRate) internal returns (uint256) {
        uint liquidity = _addLiquidity(address(this),_pairAddr,_tokenAmountOut,address(this),_amountMinRate);
        IERC20(_pairAddr).approve(address(tenetAddr),liquidity);
        if(_poolType == 0){
            tenetAddr.depositTenByUserFrom(msg.sender,liquidity);
        }else{
            tenetAddr.depositLPTokenFrom(msg.sender,_pid,liquidity);
        }
        return liquidity;
    }
    function transferTokenToLPToken(uint256 _poolType,uint256 _pid,address _pairAddr,address _tokenAddr,uint256 _tokenAmount,uint256 _amountMinRate,uint256 deadline) public virtual ensure(deadline) {
        if(_tokenAddr != wethAddr){
            IERC20(_tokenAddr).transferFrom(msg.sender, address(this),_tokenAmount);
        }
        uint256[2] memory tokenAmountOut;
        if(_tokenAddr == IUniswapV2Pair(_pairAddr).token0()){
            (tokenAmountOut[0],tokenAmountOut[1]) = _transferTokenXOut(_pairAddr,_tokenAddr,_tokenAmount,0);
        }else if(_tokenAddr == IUniswapV2Pair(_pairAddr).token1()){
            (tokenAmountOut[0],tokenAmountOut[1]) = _transferTokenXOut(_pairAddr,_tokenAddr,_tokenAmount,1);
        }else{
            (tokenAmountOut[0],tokenAmountOut[1]) = _transferTokensOut(_pairAddr,_tokenAddr,_tokenAmount);
        }
        uint liquidity = _transferLPToken(_poolType,_pid,_pairAddr,tokenAmountOut,_amountMinRate);
        emit TransferTokenToLPToken(msg.sender,_pid,_tokenAddr,_tokenAmount,_pairAddr,liquidity);
    }
    function transferETHToLPToken(uint256 _poolType,uint256 _pid,address _pairAddr,uint256 _amountMinRate,uint256 deadline) external virtual payable ensure(deadline) {
        IWETH(wethAddr).deposit{value: msg.value}();
        transferTokenToLPToken(_poolType,_pid,_pairAddr,wethAddr,msg.value,_amountMinRate,deadline);
    }
    function transferTokensToLPToken(uint256 _poolType,uint256 _pid,address _pairAddr,uint256 _token0Amount,uint256 _token1Amount,uint256 _amountMinRate,uint256 deadline) public virtual ensure(deadline) {
        uint256[2] memory tokenAmountOut;
        tokenAmountOut[0] = _token0Amount;
        tokenAmountOut[1] = _token1Amount;
        if(wethAddr != IUniswapV2Pair(_pairAddr).token0()){
            IERC20(IUniswapV2Pair(_pairAddr).token0()).transferFrom(msg.sender, address(this), tokenAmountOut[0]);
        }
        if(wethAddr != IUniswapV2Pair(_pairAddr).token1()){
            IERC20(IUniswapV2Pair(_pairAddr).token1()).transferFrom(msg.sender, address(this), tokenAmountOut[1]);
        }
        uint liquidity = _transferLPToken(_poolType,_pid,_pairAddr,tokenAmountOut,_amountMinRate);  
        emit TransferTokensToLPToken(msg.sender,_pid,tokenAmountOut[0],tokenAmountOut[1],_pairAddr,liquidity);
    }
    function transferETHsToLPToken(uint256 _poolType,uint256 _pid,address _pairAddr,uint256 _tokenAmount,uint256 _amountMinRate,uint256 deadline) external virtual payable ensure(deadline) {    
        IWETH(wethAddr).deposit{value: msg.value}();
        if(wethAddr == IUniswapV2Pair(_pairAddr).token0()){
            transferTokensToLPToken(_poolType,_pid,_pairAddr,msg.value,_tokenAmount,_amountMinRate,deadline);
        }else{
            transferTokensToLPToken(_poolType,_pid,_pairAddr,_tokenAmount,msg.value,_amountMinRate,deadline);
        }        
    }    
    function changeLPToken(address _pairAddr,uint256[2] memory _tokenAmountOut,uint256 _amountMinRate,uint256 deadline) public ensure(deadline){
        uint liquidity = _addLiquidity(msg.sender,_pairAddr,_tokenAmountOut,msg.sender,_amountMinRate);
        emit ChangeLPToken(msg.sender,_pairAddr,_tokenAmountOut[0],_tokenAmountOut[1],liquidity);
    }   
    function changeWethLPToken(address _pairAddr,uint256 _tokenAmount,uint256 _amountMinRate,uint256 deadline) external payable ensure(deadline){
        uint256[2] memory tokenAmountOut;
        if(wethAddr == IUniswapV2Pair(_pairAddr).token0()){
            tokenAmountOut[0] = msg.value;
            tokenAmountOut[1] = _tokenAmount;
        }else{
            tokenAmountOut[0] = _tokenAmount;
            tokenAmountOut[1] = msg.value;
        }
        IWETH(wethAddr).deposit{value: msg.value}();
        changeLPToken(_pairAddr,tokenAmountOut,_amountMinRate,deadline);
    }
}



// File: IUniswapV2Factory.sol
// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

interface IUniswapV2Factory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);
    function migrator() external view returns (address);

    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function allPairs(uint) external view returns (address pair);
    function allPairsLength() external view returns (uint);

    function createPair(address tokenA, address tokenB) external returns (address pair);

    function setFeeTo(address) external;
    function setFeeToSetter(address) external;
    function setMigrator(address) external;
}



// File: Context.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

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



// File: Tenet.sol
// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;


import "./IERC20.sol";
import "./SafeERC20.sol";
import "./EnumerableSet.sol";
import "./SafeMath.sol";
import "./Ownable.sol";
import "./TenetToken.sol";
import "./TenetMine.sol";
// Tenet is the master of TEN. He can make TEN and he is a fair guy.
contract Tenet is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Info of each user.
    struct UserInfo {
        uint256 amount;             
        uint256 rewardTokenDebt;    
        uint256 rewardTenDebt;      
        uint256 lastBlockNumber;    
        uint256 freezeBlocks;      
        uint256 freezeTen;         
    }
    // Info of each pool.
    struct PoolSettingInfo{
        address lpToken;            
        address tokenAddr;          
        address projectAddr;        
        uint256 tokenAmount;       
        uint256 startBlock;        
        uint256 endBlock;          
        uint256 tokenPerBlock;      
        uint256 tokenBonusEndBlock; 
        uint256 tokenBonusMultipler;
    }
    struct PoolInfo {
        uint256 lastRewardBlock;  
        uint256 lpTokenTotalAmount;
        uint256 accTokenPerShare; 
        uint256 accTenPerShare; 
        uint256 userCount;
        uint256 amount;     
        uint256 rewardTenDebt; 
        uint256 mineTokenAmount;
    }

    struct TenPoolInfo {
        uint256 lastRewardBlock;
        uint256 accTenPerShare; 
        uint256 allocPoint;
        uint256 lpTokenTotalAmount;
    }

    TenetToken public ten;
    TenetMine public tenMineCalc;
    IERC20 public lpTokenTen;
    address public devaddr;
    uint256 public devaddrAmount;
    uint256 public modifyAllocPointPeriod;
    uint256 public lastModifyAllocPointBlock;
    uint256 public totalAllocPoint;
    uint256 public devWithdrawStartBlock;
    uint256 public addpoolfee;
    uint256 public bonusAllocPointBlock;
    uint256 public minProjectUserCount;

    uint256 public updateBlock;
    uint256 public constant MINLPTOKEN_AMOUNT = 10000000000;
    uint256 public constant PERSHARERATE = 1000000000000;
    PoolInfo[] public poolInfo;
    PoolSettingInfo[] public poolSettingInfo;
    TenPoolInfo public tenProjectPool;
    TenPoolInfo public tenUserPool;
    mapping (uint256 => mapping (address => UserInfo)) public userInfo;
    mapping (address => UserInfo) public userInfoUserPool;
    mapping (address => bool) public tenMintRightAddr;

    event AddPool(address indexed user, uint256 indexed pid, uint256 tokenAmount,uint256 lpTenAmount);
    event Deposit(address indexed user, uint256 indexed pid, uint256 amount,uint256 penddingToken,uint256 penddingTen,uint256 freezeTen,uint256 freezeBlocks);
    event DepositFrom(address indexed user, uint256 indexed pid, uint256 amount,address from,uint256 penddingToken,uint256 penddingTen,uint256 freezeTen,uint256 freezeBlocks);
    event MineLPToken(address indexed user, uint256 indexed pid, uint256 penddingToken,uint256 penddingTen,uint256 freezeTen,uint256 freezeBlocks);    
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount,uint256 penddingToken,uint256 penddingTen,uint256 freezeTen,uint256 freezeBlocks);

    event DepositLPTen(address indexed user, uint256 indexed pid, uint256 amount,uint256 penddingTen,uint256 freezeTen,uint256 freezeBlocks);
    event WithdrawLPTen(address indexed user, uint256 indexed pid, uint256 amount,uint256 penddingTen,uint256 freezeTen,uint256 freezeBlocks);    
    event MineLPTen(address indexed user, uint256 penddingTen,uint256 freezeTen,uint256 freezeBlocks);    
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event DevWithdraw(address indexed user, uint256 amount);

    constructor(
        TenetToken _ten,
        TenetMine _tenMineCalc,
        IERC20 _lpTen,        
        address _devaddr,
        uint256 _allocPointProject,
        uint256 _allocPointUser,
        uint256 _devWithdrawStartBlock,
        uint256 _modifyAllocPointPeriod,
        uint256 _bonusAllocPointBlock,
        uint256 _minProjectUserCount
    ) public {
        ten = _ten;
        tenMineCalc = _tenMineCalc;
        devaddr = _devaddr;
        lpTokenTen = _lpTen;
        tenProjectPool.allocPoint = _allocPointProject;
        tenUserPool.allocPoint = _allocPointUser;
        totalAllocPoint = _allocPointProject + _allocPointUser;
        devaddrAmount = 0;
        devWithdrawStartBlock = _devWithdrawStartBlock;
        addpoolfee = 0;
        updateBlock = 0;
        modifyAllocPointPeriod = _modifyAllocPointPeriod;
        lastModifyAllocPointBlock = tenMineCalc.startBlock();
        bonusAllocPointBlock = _bonusAllocPointBlock;
        minProjectUserCount = _minProjectUserCount;
    }
    modifier onlyMinter() {
        require(tenMintRightAddr[msg.sender] == true, "onlyMinter: caller is no right to mint");
        _;
    }
    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }
    function set_tenMintRightAddr(address _addr,bool isHaveRight) public onlyOwner {
        tenMintRightAddr[_addr] = isHaveRight;
    }
    function tenMint(address _toAddr,uint256 _amount) public onlyMinter {
        ten.mint(_toAddr,_amount);
        devaddrAmount = devaddrAmount.add(_amount.div(10));
    }    
    function set_tenetToken(TenetToken _ten) public onlyOwner {
        ten = _ten;
    }
    function set_tenNewOwner(address _tenNewOwner) public onlyOwner {
        ten.transferOwnership(_tenNewOwner);
    }    
    function set_tenetLPToken(IERC20 _lpTokenTen) public onlyOwner {
        lpTokenTen = _lpTokenTen;
    }
    function set_tenetMine(TenetMine _tenMineCalc) public onlyOwner {
        tenMineCalc = _tenMineCalc;
    }
    function set_updateContract(uint256 _updateBlock) public onlyOwner {
        updateBlock = _updateBlock;
    }
    function set_addPoolFee(uint256 _addpoolfee) public onlyOwner {
        addpoolfee = _addpoolfee;
    }
    function set_devWithdrawStartBlock(uint256 _devWithdrawStartBlock) public onlyOwner {
        devWithdrawStartBlock = _devWithdrawStartBlock;
    }   
    function set_allocPoint(uint256 _allocPointProject,uint256 _allocPointUser,uint256 _modifyAllocPointPeriod) public onlyOwner {
        _minePoolTen(tenProjectPool);
        _minePoolTen(tenUserPool);
        tenProjectPool.allocPoint = _allocPointProject;
        tenUserPool.allocPoint = _allocPointUser;
        modifyAllocPointPeriod = _modifyAllocPointPeriod;
        totalAllocPoint = _allocPointProject + _allocPointUser;        
    }
    function set_bonusAllocPointBlock(uint256 _bonusAllocPointBlock) public onlyOwner {
        bonusAllocPointBlock = _bonusAllocPointBlock;
    }  
    function set_minProjectUserCount(uint256 _minProjectUserCount) public onlyOwner {
        minProjectUserCount = _minProjectUserCount;
    } 
    function add(address _lpToken,
            address _tokenAddr,
            uint256 _tokenAmount,
            uint256 _startBlock,
            uint256 _endBlockOffset,
            uint256 _tokenPerBlock,
            uint256 _tokenBonusEndBlockOffset,
            uint256 _tokenBonusMultipler,
            uint256 _lpTenAmount) public {
        if(_startBlock == 0){
            _startBlock = block.number;
        }
        require(block.number <= _startBlock, "add: startBlock invalid");
        require(_endBlockOffset >= _tokenBonusEndBlockOffset, "add: bonusEndBlockOffset invalid");
        require(tenMineCalc.getMultiplier(_startBlock,_startBlock + _endBlockOffset,_startBlock + _endBlockOffset,_startBlock + _tokenBonusEndBlockOffset,_tokenBonusMultipler).mul(_tokenPerBlock) <= _tokenAmount, "add: token amount invalid");
        if(updateBlock > 0){
            require(block.number <= updateBlock, "add: updateBlock invalid");
        }
        IERC20(_tokenAddr).transferFrom(msg.sender,address(this), _tokenAmount);
        if(addpoolfee > 0){
            ten.transferFrom(msg.sender,address(this), addpoolfee);
            ten.burn(address(this),addpoolfee);
        }
        uint256 pid = poolInfo.length;
        poolSettingInfo.push(PoolSettingInfo({
                lpToken: _lpToken,
                tokenAddr: _tokenAddr,
                projectAddr: msg.sender,
                tokenAmount:_tokenAmount,
                startBlock: _startBlock,
                endBlock: _startBlock + _endBlockOffset,
                tokenPerBlock: _tokenPerBlock,
                tokenBonusEndBlock: _startBlock + _tokenBonusEndBlockOffset,
                tokenBonusMultipler: _tokenBonusMultipler
            }));
        poolInfo.push(PoolInfo({
            lastRewardBlock: block.number > _startBlock ? block.number : _startBlock,
            accTokenPerShare: 0,
            accTenPerShare: 0,
            lpTokenTotalAmount: 0,
            userCount: 0,
            amount: 0,
            rewardTenDebt: 0,
            mineTokenAmount: 0
        }));
        if(_lpTenAmount>MINLPTOKEN_AMOUNT){
            depositTenByProject(pid,_lpTenAmount);
        }
        emit AddPool(msg.sender, pid, _tokenAmount,_lpTenAmount);
    }
    function updateAllocPoint() public {
        if(lastModifyAllocPointBlock.add(modifyAllocPointPeriod) <= block.number){
            uint256 totalLPTokenAmount = tenProjectPool.lpTokenTotalAmount.mul(bonusAllocPointBlock.add(1e4)).div(1e4).add(tenUserPool.lpTokenTotalAmount);
            if(totalLPTokenAmount > MINLPTOKEN_AMOUNT)
            {
                tenProjectPool.allocPoint = tenProjectPool.allocPoint.add(tenProjectPool.lpTokenTotalAmount.mul(1e4).mul(bonusAllocPointBlock.add(1e4)).div(1e4).div(totalLPTokenAmount)).div(2);
                tenUserPool.allocPoint = tenUserPool.allocPoint.add(tenUserPool.lpTokenTotalAmount.mul(1e4).div(totalLPTokenAmount)).div(2);
                totalAllocPoint = tenProjectPool.allocPoint + tenUserPool.allocPoint;
                lastModifyAllocPointBlock = block.number;
            }
        }     
    }
    // Update reward variables of the given pool to be up-to-date.
    function _minePoolTen(TenPoolInfo storage tenPool) internal {
        if (block.number <= tenPool.lastRewardBlock) {
            return;
        }
        if (tenPool.lpTokenTotalAmount <= MINLPTOKEN_AMOUNT) {
            tenPool.lastRewardBlock = block.number;
            return;
        }
        if(updateBlock > 0){
            if(block.number >= updateBlock){
                tenPool.lastRewardBlock = block.number;
                return;                
            }
        }
        uint256 tenReward = tenMineCalc.calcMineTenReward(tenPool.lastRewardBlock, block.number);
        tenReward = tenReward.mul(tenPool.allocPoint).div(totalAllocPoint);
        devaddrAmount = devaddrAmount.add(tenReward.div(10));
        ten.mint(address(this), tenReward);
        tenPool.accTenPerShare = tenPool.accTenPerShare.add(tenReward.mul(PERSHARERATE).div(tenPool.lpTokenTotalAmount));
        tenPool.lastRewardBlock = block.number;
        updateAllocPoint();
    }
    function _withdrawProjectTenPool(PoolInfo storage pool) internal returns (uint256 pending){
        if (pool.amount > MINLPTOKEN_AMOUNT) {
            pending = pool.amount.mul(tenProjectPool.accTenPerShare).div(PERSHARERATE).sub(pool.rewardTenDebt);
            if(pending > 0){
                if(pool.userCount == 0){
                    ten.burn(address(this),pending);
                    pending = 0;
                }
                else{
                    if(pool.userCount<minProjectUserCount){
                        uint256 newPending = pending.mul(bonusAllocPointBlock.mul(pool.userCount).div(minProjectUserCount).add(1e4)).div(bonusAllocPointBlock.add(1e4));
                        ten.burn(address(this),pending.sub(newPending));
                        pending = newPending;
                    }                    
                    pool.accTenPerShare = pool.accTenPerShare.add(pending.mul(PERSHARERATE).div(pool.lpTokenTotalAmount));
                }
            }
        }
    }
    function _updateProjectTenPoolAmount(PoolInfo storage pool,uint256 _amount,uint256 amountType) internal{
        if(amountType == 1){
            lpTokenTen.safeTransferFrom(msg.sender, address(this), _amount);
            tenProjectPool.lpTokenTotalAmount = tenProjectPool.lpTokenTotalAmount.add(_amount);
            pool.amount = pool.amount.add(_amount);
        }else if(amountType == 2){
            pool.amount = pool.amount.sub(_amount);
            if(pool.amount <= MINLPTOKEN_AMOUNT){
                pool.amount = 0;
            }
            lpTokenTen.safeTransfer(address(msg.sender), _amount);
            tenProjectPool.lpTokenTotalAmount = tenProjectPool.lpTokenTotalAmount.sub(_amount);
        }
        pool.rewardTenDebt = pool.amount.mul(tenProjectPool.accTenPerShare).div(PERSHARERATE);
    }
    function depositTenByProject(uint256 _pid,uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        PoolSettingInfo storage poolSetting = poolSettingInfo[_pid];
        require(poolSetting.projectAddr == msg.sender, "depositTenByProject: not good");
        _minePoolTen(tenProjectPool);
        _withdrawProjectTenPool(pool);
        _updateProjectTenPoolAmount(pool,_amount,1);
        emit DepositLPTen(msg.sender, 1, _amount,0,0,0);
    }

    function withdrawTenByProject(uint256 _pid,uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        PoolSettingInfo storage poolSetting = poolSettingInfo[_pid];
        require(poolSetting.projectAddr == msg.sender, "withdrawTenByProject: not good");
        require(pool.amount >= _amount, "withdrawTenByProject: not good");
        _minePoolTen(tenProjectPool);
        _withdrawProjectTenPool(pool);
        _updateProjectTenPoolAmount(pool,_amount,2);
        emit WithdrawLPTen(msg.sender, 1, _amount,0,0,0);
    }

    function _updatePoolUserInfo(uint256 accTenPerShare,UserInfo storage user,uint256 _freezeBlocks,uint256 _freezeTen,uint256 _amount,uint256 _amountType) internal {
        if(_amountType == 1){
            user.amount = user.amount.add(_amount);
        }else if(_amountType == 2){
            user.amount = user.amount.sub(_amount);
            if(user.amount<=MINLPTOKEN_AMOUNT){
                user.amount = 0;
            }          
        }
        user.rewardTenDebt = user.amount.mul(accTenPerShare).div(PERSHARERATE);
        user.lastBlockNumber = block.number;
        user.freezeBlocks = _freezeBlocks;
        user.freezeTen = _freezeTen;
    }
    function _calcFreezeTen(UserInfo storage user,uint256 accTenPerShare) internal view returns (uint256 pendingTen,uint256 freezeBlocks,uint256 freezeTen){
        pendingTen = user.amount.mul(accTenPerShare).div(PERSHARERATE).sub(user.rewardTenDebt);
        uint256 blockNow = block.number.sub(user.lastBlockNumber);
        uint256 periodBlockNumer = tenMineCalc.subBlockNumerPeriod();
        freezeBlocks = blockNow.add(user.freezeBlocks);
        if(freezeBlocks <= periodBlockNumer){
            freezeTen = pendingTen.add(user.freezeTen);
            pendingTen = 0;
        }else{
            if(pendingTen == 0){
                freezeBlocks = 0;
                freezeTen = 0;
                pendingTen = user.freezeTen;
            }else{
                freezeTen = pendingTen.add(user.freezeTen).mul(periodBlockNumer).div(freezeBlocks);
                pendingTen = pendingTen.add(user.freezeTen).sub(freezeTen);
                freezeBlocks = periodBlockNumer;
            }            
        }        
    }
    function _withdrawUserTenPool(address userAddr,UserInfo storage user) internal returns (uint256 pendingTen,uint256 freezeBlocks,uint256 freezeTen){
        (pendingTen,freezeBlocks,freezeTen) = _calcFreezeTen(user,tenUserPool.accTenPerShare);
        safeTenTransfer(userAddr, pendingTen);
    }   
    function depositTenByUser(uint256 _amount) public {
        UserInfo storage user = userInfoUserPool[msg.sender];
        _minePoolTen(tenUserPool);
        (uint256 pending,uint256 freezeBlocks,uint256 freezeTen) = _withdrawUserTenPool(msg.sender,user);
        lpTokenTen.safeTransferFrom(address(msg.sender), address(this), _amount);
        _updatePoolUserInfo(tenUserPool.accTenPerShare,user,freezeBlocks,freezeTen,_amount,1);
        tenUserPool.lpTokenTotalAmount = tenUserPool.lpTokenTotalAmount.add(_amount);        
        emit DepositLPTen(msg.sender, 2, _amount,pending,freezeTen,freezeBlocks);
    }

    function withdrawTenByUser(uint256 _amount) public {
        UserInfo storage user = userInfoUserPool[msg.sender];
        require(user.amount >= _amount, "withdrawTenByUser: not good");
        _minePoolTen(tenUserPool);
        (uint256 pending,uint256 freezeBlocks,uint256 freezeTen) = _withdrawUserTenPool(msg.sender,user);
        _updatePoolUserInfo(tenUserPool.accTenPerShare,user,freezeBlocks,freezeTen,_amount,2);
        tenUserPool.lpTokenTotalAmount = tenUserPool.lpTokenTotalAmount.sub(_amount);          
        lpTokenTen.safeTransfer(address(msg.sender), _amount);
        emit WithdrawLPTen(msg.sender, 2, _amount,pending,freezeTen,freezeBlocks);
    }

    function mineLPTen() public {
        _minePoolTen(tenUserPool);
        UserInfo storage user = userInfoUserPool[msg.sender];
        (uint256 pending,uint256 freezeBlocks,uint256 freezeTen) = _withdrawUserTenPool(msg.sender,user);
        _updatePoolUserInfo(tenUserPool.accTenPerShare,user,freezeBlocks,freezeTen,0,0);
        emit MineLPTen(msg.sender,pending,freezeTen,freezeBlocks);
    }
    function depositTenByUserFrom(address _from,uint256 _amount) public {
        UserInfo storage user = userInfoUserPool[_from];
        _minePoolTen(tenUserPool);
        (uint256 pending,uint256 freezeBlocks,uint256 freezeTen) = _withdrawUserTenPool(_from,user);
        lpTokenTen.safeTransferFrom(address(msg.sender), address(this), _amount);
        _updatePoolUserInfo(tenUserPool.accTenPerShare,user,freezeBlocks,freezeTen,_amount,1);
        tenUserPool.lpTokenTotalAmount = tenUserPool.lpTokenTotalAmount.add(_amount);        
        emit DepositLPTen(_from, 2, _amount,pending,freezeTen,freezeBlocks);
    } 
    function _minePoolToken(PoolInfo storage pool,PoolSettingInfo storage poolSetting) internal {
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        if (pool.lpTokenTotalAmount > MINLPTOKEN_AMOUNT) {
            uint256 multiplier = tenMineCalc.getMultiplier(pool.lastRewardBlock, block.number,poolSetting.endBlock,poolSetting.tokenBonusEndBlock,poolSetting.tokenBonusMultipler);
            if(multiplier > 0){
                uint256 tokenReward = multiplier.mul(poolSetting.tokenPerBlock);
                pool.mineTokenAmount = pool.mineTokenAmount.add(tokenReward);
                pool.accTokenPerShare = pool.accTokenPerShare.add(tokenReward.mul(PERSHARERATE).div(pool.lpTokenTotalAmount));
            }
        }
        if(pool.lastRewardBlock < poolSetting.endBlock){
            if(block.number >= poolSetting.endBlock){
                if(poolSetting.tokenAmount.sub(pool.mineTokenAmount) > MINLPTOKEN_AMOUNT){
                    IERC20(poolSetting.tokenAddr).transfer(poolSetting.projectAddr,poolSetting.tokenAmount.sub(pool.mineTokenAmount));
                }
            }
        }
        pool.lastRewardBlock = block.number;
        _minePoolTen(tenProjectPool);
        _withdrawProjectTenPool(pool);
        _updateProjectTenPoolAmount(pool,0,0);
    }
    function _withdrawTokenPool(address userAddr,PoolInfo storage pool,UserInfo storage user,PoolSettingInfo storage poolSetting) 
            internal returns (uint256 pendingToken,uint256 pendingTen,uint256 freezeBlocks,uint256 freezeTen){
        if (user.amount > MINLPTOKEN_AMOUNT) {
            pendingToken = user.amount.mul(pool.accTokenPerShare).div(PERSHARERATE).sub(user.rewardTokenDebt);
            IERC20(poolSetting.tokenAddr).transfer(userAddr, pendingToken);
            (pendingTen,freezeBlocks,freezeTen) = _calcFreezeTen(user,pool.accTenPerShare);
            safeTenTransfer(userAddr, pendingTen);
        }
    }
    function _updateTokenPoolUser(uint256 accTokenPerShare,uint256 accTenPerShare,UserInfo storage user,uint256 _freezeBlocks,uint256 _freezeTen,uint256 _amount,uint256 _amountType) 
            internal {
        _updatePoolUserInfo(accTenPerShare,user,_freezeBlocks,_freezeTen,_amount,_amountType);
        user.rewardTokenDebt = user.amount.mul(accTokenPerShare).div(PERSHARERATE);
    }
    function depositLPToken(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        PoolSettingInfo storage poolSetting = poolSettingInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        _minePoolToken(pool,poolSetting);
        (uint256 pendingToken,uint256 pendingTen,uint256 freezeBlocks,uint256 freezeTen) = _withdrawTokenPool(msg.sender,pool,user,poolSetting);
        if (user.amount <= MINLPTOKEN_AMOUNT) {
            pool.userCount = pool.userCount.add(1);
        }
        IERC20(poolSetting.lpToken).safeTransferFrom(address(msg.sender), address(this), _amount);
        pool.lpTokenTotalAmount = pool.lpTokenTotalAmount.add(_amount);
        _updateTokenPoolUser(pool.accTokenPerShare,pool.accTenPerShare,user,freezeBlocks,freezeTen,_amount,1);
        emit Deposit(msg.sender, _pid, _amount,pendingToken,pendingTen,freezeTen,freezeBlocks);
    }

    function withdrawLPToken(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        PoolSettingInfo storage poolSetting = poolSettingInfo[_pid];
        require(user.amount >= _amount, "withdrawLPToken: not good");
        _minePoolToken(pool,poolSetting);
        (uint256 pendingToken,uint256 pendingTen,uint256 freezeBlocks,uint256 freezeTen) = _withdrawTokenPool(msg.sender,pool,user,poolSetting);
        _updateTokenPoolUser(pool.accTokenPerShare,pool.accTenPerShare,user,freezeBlocks,freezeTen,_amount,2);
        IERC20(poolSetting.lpToken).safeTransfer(address(msg.sender), _amount);
        pool.lpTokenTotalAmount = pool.lpTokenTotalAmount.sub(_amount);
        if(user.amount <= MINLPTOKEN_AMOUNT){
            pool.userCount = pool.userCount.sub(1);
        }        
        emit Withdraw(msg.sender, _pid, _amount,pendingToken,pendingTen,freezeTen,freezeBlocks);
    }

    function mineLPToken(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        PoolSettingInfo storage poolSetting = poolSettingInfo[_pid];
        _minePoolToken(pool,poolSetting);
        (uint256 pendingToken,uint256 pendingTen,uint256 freezeBlocks,uint256 freezeTen) = _withdrawTokenPool(msg.sender,pool,user,poolSetting);
        _updateTokenPoolUser(pool.accTokenPerShare,pool.accTenPerShare,user,freezeBlocks,freezeTen,0,0);
        emit MineLPToken(msg.sender, _pid, pendingToken,pendingTen,freezeTen,freezeBlocks);
    }

    function depositLPTokenFrom(address _from,uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_from];
        PoolSettingInfo storage poolSetting = poolSettingInfo[_pid];
        _minePoolToken(pool,poolSetting);
        (uint256 pendingToken,uint256 pendingTen,uint256 freezeBlocks,uint256 freezeTen) = _withdrawTokenPool(_from,pool,user,poolSetting);
        if (user.amount <= MINLPTOKEN_AMOUNT) {
            pool.userCount = pool.userCount.add(1);
        }
        IERC20(poolSetting.lpToken).safeTransferFrom(msg.sender, address(this), _amount);
        pool.lpTokenTotalAmount = pool.lpTokenTotalAmount.add(_amount);
        _updateTokenPoolUser(pool.accTokenPerShare,pool.accTenPerShare,user,freezeBlocks,freezeTen,_amount,1);
        emit DepositFrom(_from, _pid, _amount,msg.sender,pendingToken,pendingTen,freezeTen,freezeBlocks);
    }
 
    function dev(address _devaddr) public {
        require(msg.sender == devaddr, "dev: wut?");
        devaddr = _devaddr;
    }

    function devWithdraw(uint256 _amount) public {
        require(block.number >= devWithdrawStartBlock, "devWithdraw: start Block invalid");
        require(msg.sender == devaddr, "devWithdraw: devaddr invalid");
        require(devaddrAmount >= _amount, "devWithdraw: amount invalid");        
        ten.mint(devaddr,_amount);
        devaddrAmount = devaddrAmount.sub(_amount);
        emit DevWithdraw(msg.sender, _amount);
    }    

    function safeTenTransfer(address _to, uint256 _amount) internal {
        if(_amount > MINLPTOKEN_AMOUNT){
            uint256 bal = ten.balanceOf(address(this));
            if (_amount > bal) {
                ten.transfer(_to, bal);
            } else {
                ten.transfer(_to, _amount);
            }
        }
    }        
}



// File: IUniswapV2Pair.sol
// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

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


// File: IUniswapV2Callee.sol
// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

interface IUniswapV2Callee {
    function uniswapV2Call(address sender, uint amount0, uint amount1, bytes calldata data) external;
}


