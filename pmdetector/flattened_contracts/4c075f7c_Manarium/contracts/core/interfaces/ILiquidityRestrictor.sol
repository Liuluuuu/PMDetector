
// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

interface ILiquidityRestrictor {
	function assureByAgent(
		address token,
		address from,
		address to
	) external returns (bool allow, string memory message);

	function assureLiquidityRestrictions(address from, address to)
		external
		returns (bool allow, string memory message);
}

interface IAntisnipe {
	function assureCanTransfer(
		address sender,
		address from,
		address to,
		uint256 amount
	) external returns (bool response);
}