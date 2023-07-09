// SPDX-License_Identifier: MIT

pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {DeployDSC} from "../script/DeployDSC.s.sol";
import {DecentralizedStablecoin} from "../src/CatStableCoin.sol";
import {DSCEngine} from "../src/DSCEngine.sol";
import {HelperConfig} from "./../script/HelperConfig.s.sol";

contract DSCEngineTest is Test {

    DeployDSC deployer;
    DecentralizedStablecoin dsc;
    DSCEngine dsce;
    HelperConfig config;

    // get token addres and pricefeed address from the deployer contract with the help of HelperConfig contract
    address ethUsdPriceFeed;
    address weth;  



    /**
     * @dev This function will run before every test function.
     * It will deploy the DSC and DSCEngine contracts.
     * It will also set the deployer address.
     * config is the HelperConfig contract which will be used to get the pricefeed address.
     */
    function setUp() public {
        deployer = new DeployDSC();
        (dsc,dsce, config) = deployer.run();
        (ethUsdPriceFeed, , weth, ,) = config.activeNetworkConfig();
    }

    // one of the test cases : testing pricefeed --> GetUsdPrice function

    //////////////////////////
    //---- Price Tests---- //
    /////////////////////////
}