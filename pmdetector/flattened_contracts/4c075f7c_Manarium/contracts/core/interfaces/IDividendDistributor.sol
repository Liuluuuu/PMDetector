// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

interface IDividendDistributor {
    function setShare(address shareholder, uint256 amount) external;
    function deposit() external payable;
    function claimDividend(address shareholder) external;
    function getUnpaidEarnings(address shareholder) external view returns(uint256);
    function getRealisedEarnings(address shareholder) external view returns(uint256);
}