// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {DecentralizedStablecoin} from "../src/CatStableCoin.sol";
import {DSCEngine} from "../src/DSCEngine.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployDSC is Script {

    address[] public tokenAddress;
    address[] public priceFeedAddress;

    function run() external returns (DecentralizedStablecoin,DSCEngine, HelperConfig){

       

        HelperConfig config = new HelperConfig();

        //now we are going to get the config
        (address wethUsdPriceFeed, address wbtcUsdPriceFeed, address weth, address wbtc, uint256 deployerKey) = config.activeNetworkConfig();

        // now our dscengine take array of tokenAddress and priceFeedAddress
        tokenAddress = [weth, wbtc];
        priceFeedAddress = [wethUsdPriceFeed, wbtcUsdPriceFeed];


        vm.startBroadcast(deployerKey);

        DecentralizedStablecoin dsc = new DecentralizedStablecoin();
        DSCEngine engine = new DSCEngine(tokenAddress, priceFeedAddress, address(dsc));

        //DecentralizedStableCoin contract is owned by only DscEngine. So transfer ownership to deployer
        dsc.transferOwnership(address(engine));


        vm.stopBroadcast();

        return (dsc, engine,config);
    }

}