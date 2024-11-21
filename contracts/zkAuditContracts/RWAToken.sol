// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract RWAToken is ERC20, AccessControl {
    address private adminAddress;
    constructor(uint256 initialSupply) ERC20("RWAs", "RWA") {
        adminAddress = msg.sender;
        _mint(adminAddress, initialSupply);
        _grantRole(DEFAULT_ADMIN_ROLE, adminAddress);
    }

    function mint(address to, uint256 amount) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _burn(from, amount);
    }
}