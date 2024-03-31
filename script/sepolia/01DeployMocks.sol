// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import "src/mocks/mockErc20.sol";

contract DeployMocks is Script {
    function run() external {
        vm.startBroadcast();

        MockStablecoin mockStablecoin = new MockStablecoin();
        console.log("Deployed MockStablecoin at:", address(mockStablecoin));

        MockMetisDerivative mockMetisDerivative = new MockMetisDerivative();
        console.log("Deployed mockMetisDerivative at:", address(mockMetisDerivative));

        vm.stopBroadcast();
    }
}
