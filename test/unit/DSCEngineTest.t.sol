// SPDX-License_Identifier: MIT

pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DecentralizedStablecoin} from "../../src/CatStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";

contract DSCEngineTest is Test {

    DeployDSC deployer;
    DecentralizedStablecoin dsc;
    DSCEngine dsce;
    HelperConfig config;

    // get token addres and pricefeed address from the deployer contract with the help of HelperConfig contract
    address ethUsdPriceFeed;
    address weth;  

    address public USER = makeAddr("user");
    uint256 public constant AMOUNT_COLLATERAL = 10 ether;
    uint256 public constant STARTING_ERC20_BALANCE = 10 ether;



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

        ERC20Mock(weth).mint(USER, STARTING_ERC20_BALANCE);
    }

    // one of the test cases : testing pricefeed --> GetUsdPrice function

    //////////////////////////
    //---- Price Tests---- //
    /////////////////////////

    function testGetUsdValue() public {

        // we need to send token address and amount :  function getUsdValue(address token, uint256 amount) public view returns(uint256){

        uint256 ethAmount = 15e18;
        //15e18 = 2000$ (1 eth = 2000$) = 30,000e18

        uint256 exceptedUsd = 30000e18;
        uint256 actualUsd = dsce.getUsdValue(weth, ethAmount);
        assertEq(actualUsd, exceptedUsd); 
    }

    
    //////////////////////////////////////
    //---- depositCollateral Tests---- //
    ////////////////////////////////////

    function testRevertsIfCollateralZero() public {

        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);

        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dsce.depositeCollateral(weth, 0);
        vm.stopPrank();
        
    }
}