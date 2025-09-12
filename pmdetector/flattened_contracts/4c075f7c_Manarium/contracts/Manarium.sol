// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./core/interfaces/IDex.sol";
import "./core/interfaces/ILiquidityRestrictor.sol";
import "./core/DividendDistributor.sol";
import "./core/interfaces/IDividendDistributor.sol";


contract Manarium is ERC20, Ownable
{
    using SafeMath for uint256;
    using Address for address;

    // WBNB MAINNET: 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c
    address constant WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    
    address public prizePoolWallet = 0x3e44881b4BC060FC3cF202b796147022Cd8e80C3;
    address public developmentWallet = 0x1664a715B15345C50bdd3b92Bf3EB7a4E4d39B4A;
    address constant public REFERRAL_WALLET = 0x739F3d09fF6AD00610e1D5B34B21eA8Bf4F6C125;
    address constant public AIRDROP_WALLET = 0x38D457F0BAA0aa3cC6Cf0496e9eb12870a2AecdF;

    address private _pair;
    
    IDEXRouter private _router;    
    IDividendDistributor private _distributor;

    IAntisnipe public antisnipe = IAntisnipe(address(0));
	ILiquidityRestrictor public liquidityRestrictor = ILiquidityRestrictor(0xeD1261C063563Ff916d7b1689Ac7Ef68177867F2);

    uint256 public buyTax = 5; // 5%
    uint256 public sellTax = 8; // 8%

    uint256 public prizePoolProcent = 50; // 50% Threshold tax
    uint256 public distributionProcent = 25; // 25% Threshold tax
    uint256 public developmentProcent = 25; // 25% Threshold tax

    uint256 public swapThreshold = 1000 * 10 ** 18; // 1000 
    uint256 constant public PROCENT_DENOMINATOR = 100; // 100%

    bool public antisnipeEnabled = true;
	bool public liquidityRestrictionEnabled = true;

    bool public feesEnabled = true;
    bool private _inSwap;    

    mapping(address => bool) private _isExcludedFromFees;
    mapping(address => bool) private _isExcludedFromDividends;
    mapping(address => bool) private _isBurneable;
    mapping(address => bool) private _tournaments;

    event AntisnipeDisabled(uint256 timestamp, address user);
	event LiquidityRestrictionDisabled(uint256 timestamp, address user);
	event AntisnipeAddressChanged(address addr);
	event LiquidityRestrictionAddressChanged(address addr);

    event SendTokensForDividends(uint256 amount);
    event SendTokensForRewards(uint256 amount);
    event Burned(uint256 amount);

    modifier swapping() 
    {
        _inSwap = true;
        _; 
        _inSwap = false; 
    }

    receive() external payable {}

    constructor() ERC20("Manarium", "ARI"){

        // MAINNET 0xcF0feBd3f17CEf5b47b0cD257aCf6025c5BFf3b7 - APESWAP
        _router = IDEXRouter(0xcF0feBd3f17CEf5b47b0cD257aCf6025c5BFf3b7);
        _pair = IDEXFactory(_router.factory()).createPair(WBNB, address(this));
        _distributor = new DividendDistributor(address(_router));

        excludeFromFeesAndDividends(address(this), true);
        excludeFromFeesAndDividends(address(0), true);
        excludeFromFeesAndDividends(msg.sender, true);
        excludeFromFeesAndDividends(prizePoolWallet, true);
        excludeFromFeesAndDividends(REFERRAL_WALLET, true);
        excludeFromFeesAndDividends(developmentWallet, true);
        excludeFromFeesAndDividends(AIRDROP_WALLET, true);

        _isBurneable[msg.sender] = true;
        _isExcludedFromDividends[address(_pair)] = true;
        _approve(address(this), address(_router), type(uint128).max);
        _mint(msg.sender, 100000000 * 10**18); // 100 000 000
    }

    
    function isExcludedFromFees(address account_) external view returns(bool){
        return _isExcludedFromFees[account_];
    }

    function isExcludedFromDividends(address account_) external view returns(bool){
        return _isExcludedFromDividends[account_];
    }

    function canBurn(address address_) public view returns(bool){
        return _isBurneable[address_];
    }

    function getUnpaidEarnings(address shareholder) external view returns (uint256) {
        return _distributor.getUnpaidEarnings(shareholder);
    }

    function getRealisedEarnings(address shareholder) external view returns (uint256) {
        return _distributor.getRealisedEarnings(shareholder);
    }

    function enableFees(bool state) external onlyOwner {
        feesEnabled = state;
    }

    function enableBurneable(address address_, bool state_) external onlyOwner {
        _isBurneable[address_] = state_;
    }

    function excludeFromFees(address account_, bool excluded_) public onlyOwner{
        _isExcludedFromFees[account_] = excluded_;
    }

    function multiExcludeFromFees(address[] memory account_, bool excluded_) public onlyOwner{
        require(account_.length > 0);
        for(uint256 i = 0; i < account_.length; i++){
            _isExcludedFromFees[account_[i]] = excluded_; 
        }
    }

    function excludeFromDividends(address account_, bool excluded_) public onlyOwner{
        _isExcludedFromDividends[account_] = excluded_; 
    }

    function multiExcludeFromDividends(address[] memory account_, bool excluded_) public onlyOwner{
        require(account_.length > 0);
        for(uint256 i = 0; i < account_.length; i++){
            _isExcludedFromDividends[account_[i]] = excluded_; 
        }
    }

    function excludeFromFeesAndDividends(address account_, bool excluded_) public onlyOwner{
        excludeFromFees(account_, excluded_);
        excludeFromDividends(account_, excluded_);
    }

    function multiExcludeFromFeesAndDividends(address[] memory account_, bool excluded_) public onlyOwner{
        require(account_.length > 0);
        for(uint256 i = 0; i < account_.length; i++){
            _isExcludedFromFees[account_[i]] = excluded_; 
            _isExcludedFromDividends[account_[i]] = excluded_; 
        }
    }

    function setAntisnipeDisable() external onlyOwner {
		require(antisnipeEnabled);
		antisnipeEnabled = false;
		emit AntisnipeDisabled(block.timestamp, msg.sender);
	}

	function setLiquidityRestrictorDisable() external onlyOwner {
		require(liquidityRestrictionEnabled);
		liquidityRestrictionEnabled = false;
		emit LiquidityRestrictionDisabled(block.timestamp, msg.sender);
	}

	function setAntisnipeAddress(address addr) external onlyOwner {
		antisnipe = IAntisnipe(addr);
		emit AntisnipeAddressChanged(addr);
	}

	function setLiquidityRestrictionAddress(address addr) external onlyOwner {
		liquidityRestrictor = ILiquidityRestrictor(addr);
		emit LiquidityRestrictionAddressChanged(addr);
	}

    function updateBuyTax(uint256 tax) external onlyOwner {
        require(tax >= 0 && tax <= 12);
        buyTax = tax;
    }

    function updateSellTax(uint256 tax) external onlyOwner {
        require(tax >= 0 && tax <= 12);
        sellTax = tax;
    }

    function updatePrizePoolWallet(address address_) external onlyOwner{
        require(address_ != prizePoolWallet);
        prizePoolWallet = address_;
    }

    function updateDevelopmentWallet(address address_) external onlyOwner{
        require(address_ != developmentWallet);
        developmentWallet = address_;
    }

    function updateThresholdProcents(uint256 prizePool, uint256 distribution, uint256 development) external onlyOwner {
        require(prizePool.add(distribution).add(development) <= 100);
        prizePoolProcent = prizePool;
        distributionProcent = distribution;
        developmentProcent = development;
    }


    function updateRouter(address newAddress) public onlyOwner {
        require(newAddress != address(_router), "The router already has that address");
        _router = IDEXRouter(newAddress);
        _pair = IDEXFactory(_router.factory()).createPair(WBNB, address(this));
        _isExcludedFromDividends[_pair] = true;
        _approve(address(this), address(_router), type(uint128).max);
    }

    function updateDividendContract(address _contract) public onlyOwner{
        require(_contract != address(_distributor), "The dividend already has that address");
        _distributor = IDividendDistributor(_contract);
    }

    function registerTournament(address tournament) external onlyOwner {
        require(tournament.isContract());
        require(!_tournaments[tournament]);
        _tournaments[tournament] = true;
        _isBurneable[tournament] = true;
        excludeFromFeesAndDividends(tournament, true);
    }

    function unregisterTournament(address tournament) external onlyOwner{
        require(_tournaments[tournament]);
        _tournaments[tournament] = false;
        _isBurneable[tournament] = false;
        excludeFromFeesAndDividends(tournament, false);
    }

    function setSwapBackSettings(uint256 amount) external onlyOwner {
        swapThreshold = amount;
    }


    function burn(uint256 amount) external{
        require(canBurn(msg.sender), "Burn can only burneable addresses");
        require(amount <= balanceOf(msg.sender));
        
        _burn(msg.sender, amount);
        emit Burned(amount);
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {

        // Tokens from the Prize Pool Wallet do not require approve. 
        // They can only be used by tournament contracts (check on _transfer)
        if(sender == prizePoolWallet) {
            _transfer(sender, recipient, amount);
            return true;
        }
        
        // Tokens do not require approve to enter the tournament.
        // Only tournament contract 
        if(_tournaments[recipient] && _tournaments[msg.sender]){
            _transfer(sender, recipient, amount);
            return true;
        }

        return super.transferFrom(sender, recipient, amount);
    } 

    function _beforeTokenTransfer(
		address from,
		address to,
		uint256 amount
	) internal override {
		if (from == address(0) || to == address(0)) return;
		if (liquidityRestrictionEnabled && address(liquidityRestrictor) != address(0)) {
			(bool allow, string memory message) = liquidityRestrictor
				.assureLiquidityRestrictions(from, to);
			require(allow, message);
		}

		if (antisnipeEnabled && address(antisnipe) != address(0)) {
			require(antisnipe.assureCanTransfer(msg.sender, from, to, amount));
		}
	}

    function _transfer(
        address sender,
        address recipient,
        uint256 amount)
    internal override {
        if(sender == prizePoolWallet) require(_tournaments[msg.sender], 'Tokens from PRIZE_POOL_WALLET can sends only from tournaments.');

        if(shouldTakeFee(sender, recipient))
            amount = takeFee(sender, amount);

        if(shouldSwapBack())
            swapBack();

        super._transfer(sender, recipient, amount);
        
        if(!_isExcludedFromDividends[sender]){ try _distributor.setShare(sender, balanceOf(sender)) {} catch {} }
        if(!_isExcludedFromDividends[recipient]){ try _distributor.setShare(recipient, balanceOf(recipient)) {} catch {} }
    }

    function shouldTakeFee( address sender, address recipient) internal view returns(bool){
        return feesEnabled && !_isExcludedFromFees[sender] && !_isExcludedFromFees[recipient];
    }

    function takeFee(address sender, uint256 amount) internal returns (uint256) {
        uint256 tax = (sender == address(_pair)) ? buyTax : sellTax;
        uint256 _amountFee = amount.mul(tax).div(PROCENT_DENOMINATOR);
        super._transfer(sender, address(this), _amountFee);
        return amount.sub(_amountFee);
    }

    function shouldSwapBack() internal view returns (bool) {
        return msg.sender != _pair
               && !_inSwap
               && !_tournaments[msg.sender]
               && balanceOf(address(this)) >= swapThreshold;
    }

    function swapBack() internal swapping {
        
        uint256 amount = balanceOf(address(this));
        uint256 prizePoolAmount = amount.mul(prizePoolProcent).div(PROCENT_DENOMINATOR);
        
        uint256 amountBNB = swapTokens(amount.sub(prizePoolAmount));
        uint256 developmentAmount = amountBNB.mul(developmentProcent).div(PROCENT_DENOMINATOR.sub(prizePoolProcent));
        uint256 distributionAmount = amountBNB.sub(developmentAmount);

        sendToDevelopment(developmentAmount);
        sendToDistribution(distributionAmount);
        sendToPrizePool(prizePoolAmount);
    }

    function swapTokens(uint256 amount) private returns (uint256)
    {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = WBNB;

        _router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            amount,
            0,
            path,
            address(this),
            block.timestamp
        );

        uint256 amountBNB = address(this).balance;
        return amountBNB;
    }

    function sendToDevelopment(uint256 amount) private returns (bool){
        (bool success, ) = payable(developmentWallet).call{value: amount, gas: 30000}("");
        return success;
    }

    function sendToDistribution(uint256 amount) private{
        try _distributor.deposit{value: amount}() {} catch {}
        emit SendTokensForDividends(amount);
    }
    
    function sendToPrizePool(uint256 amount) private {
        _transfer(address(this), prizePoolWallet, amount);
        emit SendTokensForRewards(amount);
    }

    function claimDividend() external {
        _distributor.claimDividend(msg.sender);
    }
    
}