// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

// import "./libs/BEP20.sol";
import "@openzeppelin/contracts/token/erc20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract AtmosSoftToken is Ownable, ERC20("Atmosphere CCG", "ATMSSFT") {
    using SafeMath for uint256;

    uint256  maxSupply = 40000000;
    mapping(address => bool)  _botBlocker;
    mapping(address => bool) _feeExempt;
    address public _gameFeeAddress;
    bool public _gameFeeEnabled;
    uint256 public _gameFee;
    uint256 _percentageBase = 1000;

    event SetGameFeeAddress(address newAddress);
    event SetBotAddress(address botAddress, bool blocked);
    event SetGameFeeEnabled(bool enabled);
    event SetGameFee(uint256 fee);

    constructor(){        
        _mint(msg.sender, maxSupply.mul(10**18));                
        _gameFee = 50;
        _feeExempt[msg.sender] = true;
        _gameFeeEnabled = false;
    }

    
    function _mint(address _to, uint256 _amount) internal override onlyOwner {
        require(totalSupply() + _amount <= maxSupply.mul(10**18), "MINT: Max supply reached");
        super._mint(_to, _amount);
    }

   function _transfer(address from,address to,uint256 amount) internal override {
       require(_botBlocker[from] == false, "TRANSFER: BOT Address BLOCKED");
       if(_gameFeeEnabled && _feeExempt[from] == false && _feeExempt[to] == false ){
            uint256 feeAmount = amount.mul(_gameFee).div(_percentageBase);
            super._transfer(from, _gameFeeAddress, feeAmount);  
            super._transfer(from, to, amount.sub(feeAmount));
       }else{
            super._transfer(from, to, amount);
       }
   }

   function setGameFeeAddress(address gameFeeAddress) public onlyOwner{
       _gameFeeAddress = gameFeeAddress;
       emit SetGameFeeAddress(gameFeeAddress);
   }

   //block bot trading on this token.
   function setBotAddress(address botAddress, bool blocked) public onlyOwner{
       _botBlocker[botAddress] = blocked;       
       emit SetBotAddress(botAddress, blocked);
   }

   function setGameFeeEnabled(bool feeEnabled) public onlyOwner{
       _gameFeeEnabled = feeEnabled;       
       emit SetGameFeeEnabled(feeEnabled);
   }

   function setFeeExemptAddress(address addr, bool exempt) public onlyOwner{
       _feeExempt[addr] = exempt;
   }

   function setGameFee(uint256 fee) public onlyOwner{
       require(fee <= 100, "setGameFee: Cannot exceed 10%");
       _gameFee = fee;       
       emit SetGameFee(fee);
   }

   function isAddressBotBlocked(address addr) public view returns (bool){
       return _botBlocker[addr];
   }

   function isAddressFeeExempt(address addr) public view returns (bool){
       return _feeExempt[addr];
   }
}