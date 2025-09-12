// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../WrappedToken.sol";

contract KillSwitchToken is WrappedToken {
    constructor() WrappedToken("KillSwitchToken", "KSW", 18) {}
}
