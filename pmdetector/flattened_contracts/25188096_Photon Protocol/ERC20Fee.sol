// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.7.5;

import './SafeMath.sol';
import './IERC20.sol';
import './IUniswapV2Factory.sol';
import './IUniswapV2Pair.sol';
import './IUniswapV2Router02.sol';

contract ERC20Fee is IERC20 {

    using SafeMath for uint256;

    // TODO comment actual hash value.
    bytes32 constant private ERC20TOKEN_ERC1820_INTERFACE_ID = keccak256( "ERC20Token" );
    
    mapping (address => uint256) internal _balances;

    mapping (address => mapping (address => uint256)) internal _allowances;

    uint256 internal _totalSupply;

    string internal _name;
    
    string internal _symbol;
    
    uint8 internal _decimals;

    mapping (address => bool) public _isExcludedFromFee;

    IUniswapV2Router02 public immutable uniswapV2Router;

    address public immutable uniswapV2Pair;

    address public BUSD = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56; // TestNet 0x703736e1d858b326ac1eee7185babb42e766cd07 /// mainNet 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56

    address public _devAddress;

    bool inSwapAndLiquify;

    modifier lockTheSwap {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }

    constructor (string memory name_, string memory symbol_, uint8 decimals_) {
        _name = name_;
        _symbol = symbol_;
        _decimals = decimals_;
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E); //testNet 0x1Ed675D5e63314B760162A3D1Cae1803DCFC87C7 //mainNet 0x10ED43C718714eb63d5aA57B78B54704E256024E
        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), BUSD); //BUSD Address
        uniswapV2Router = _uniswapV2Router;
        _isExcludedFromFee[address(this)] = true;
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, msg.sender, _allowances[sender][msg.sender].sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender].add(addedValue));
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
        return true;
    }

    function _transfer(address sender, address recipient, uint256 amount) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(sender, recipient, amount);

        bool isSellOrBuy;
        uint256 feeAmount;
        bool takeFee = false;

        

        _balances[sender] = _balances[sender].sub(amount, "ERC20: transfer amount exceeds balance");

        if (sender == uniswapV2Pair || recipient == uniswapV2Pair) {
            isSellOrBuy = true;

            if( !_isExcludedFromFee[sender] && !_isExcludedFromFee[recipient]){
                takeFee = true;
            }
        }

        if ( !isSellOrBuy && !inSwapAndLiquify) {
            swapAndSendFee();
        }

        if ( takeFee ) {
            feeAmount = amount.mul(5).div(100);
            amount = amount.sub(feeAmount);
            _balances[address(this)] = _balances[address(this)].add(feeAmount);
            emit Transfer(sender, address(this), feeAmount);
        }

        _balances[recipient] = _balances[recipient].add(amount);

        emit Transfer(sender, recipient, amount);
    }

    function swapAndSendFee() internal lockTheSwap {
        uint256 contractTokenAmount = balanceOf(address(this));
        if (contractTokenAmount > 0 && _devAddress != address(0)) {
            address[] memory path = new address[](2);
            path[0] = address(this);
            path[1] = BUSD;

            _approve(address(this), address(uniswapV2Router), contractTokenAmount);

            // make the swap
            uniswapV2Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
                contractTokenAmount,
                0,
                path,
                _devAddress,
                block.timestamp
            );
        }
    }

    function _setDevAddress(address devAddress) internal {
        _devAddress = devAddress;
    }

    function _excludeFromFee(address account) internal {
        _isExcludedFromFee[account] = true;
    }

    function _mint(address account_, uint256 ammount_) internal virtual {
        require(account_ != address(0), "ERC20: mint to the zero address");
        _beforeTokenTransfer(address( this ), account_, ammount_);
        _totalSupply = _totalSupply.add(ammount_);
        _balances[account_] = _balances[account_].add(ammount_);
        emit Transfer(address( this ), account_, ammount_);
    }

    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        _balances[account] = _balances[account].sub(amount, "ERC20: burn amount exceeds balance");
        _totalSupply = _totalSupply.sub(amount);
        emit Transfer(account, address(0), amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

  function _beforeTokenTransfer( address from_, address to_, uint256 amount_ ) internal virtual { }
}