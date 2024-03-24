// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract MockStablecoin is ERC20("MockaUSD", "MAUSD") {
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function mintToMany(address[] calldata recipients, uint256 amount) external {
        for (uint256 i = 0; i < recipients.length; i++) {
            _mint(recipients[i], amount);
        }
    }
}

contract MockMetisDerivative is ERC20("MockMetisDerivative", "dMetis") {
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function mintToMany(address[] calldata recipients, uint256 amount) external {
        for (uint256 i = 0; i < recipients.length; i++) {
            _mint(recipients[i], amount);
        }
    }
}
