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
