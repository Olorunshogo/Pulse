// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {PulseSessionFactory} from "../contracts/PulseSessionFactory.sol";
import {SomniaBinaryAdapter} from "../contracts/SomniaBinaryAdapter.sol";

contract DeployPulseSessionFactory is Script {
    address internal constant SOMNIA_SHANNON_BINARY_MODULE = 0x3ecC694Cef705358864a646142ac17A90E29e388;
    address internal constant SOMNIA_SHANNON_COLLATERAL = 0x70a86D8842FB63C4Ad2b7cdddF530eBf1BB25d8E;
    address internal constant SOMNIA_SHANNON_OUTCOME_TOKEN = 0xB52c5934113Af5c0Bb20eb3C72290C8215f755b9;

    function run() external returns (SomniaBinaryAdapter adapter, PulseSessionFactory factory) {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address collateral = vm.envOr("COLLATERAL_ADDRESS", SOMNIA_SHANNON_COLLATERAL);
        address module = vm.envOr("BINARY_MODULE_ADDRESS", SOMNIA_SHANNON_BINARY_MODULE);
        address outcomeToken = vm.envOr("OUTCOME_TOKEN_ADDRESS", SOMNIA_SHANNON_OUTCOME_TOKEN);
        uint256 maxYesPrice = vm.envOr("MAX_YES_PRICE", uint256(990_000));
        uint256 maxNoPrice = vm.envOr("MAX_NO_PRICE", uint256(990_000));

        vm.startBroadcast(privateKey);
        adapter = new SomniaBinaryAdapter(module, collateral, outcomeToken, maxYesPrice, maxNoPrice);
        factory = new PulseSessionFactory(collateral, address(adapter));
        vm.stopBroadcast();

        console2.log("NEXT_PUBLIC_MARKET_ADAPTER=%s", address(adapter));
        console2.log("NEXT_PUBLIC_SESSION_FACTORY=%s", address(factory));
    }
}
