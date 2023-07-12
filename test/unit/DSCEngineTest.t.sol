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
    address btcUsdPriceFeed; 

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
        (ethUsdPriceFeed,btcUsdPriceFeed , weth, ,) = config.activeNetworkConfig();

        ERC20Mock(weth).mint(USER, STARTING_ERC20_BALANCE);
    }

     //////////////////////////////
    //---- Constuctor Tests---- //
    /////////////////////////////

    /**
     * @notice This function will test the constructor of the DSCEngine contract.
     * It will check if the length of the token address and pricefeed address is same.
     * for example if we have 3 tokens then we should have 3 pricefeeds.
     * If the length is not same then it will revert.
     * 
     * for checking the test you need array of token address and pricefeed address.
     * where you can pass the token address and pricefeed address.
     */
    
    address[] public tokenAddress;
    address[] public priceFeedAddress;

    function testRevertIfTokenLengthDoesntMatchPriceFeeds() public {
        tokenAddress.push(weth);
        priceFeedAddress.push(ethUsdPriceFeed);
        priceFeedAddress.push(btcUsdPriceFeed);

        vm.expectRevert(DSCEngine.DSCEngine__TokenAddressAndPriceFeedAddressMustBeSameLength.selector);
        new DSCEngine(tokenAddress, priceFeedAddress, address(dsc));

    }

    //////////////////////////
    //---- Price Tests---- //
    /////////////////////////

    function testGetUsdValue() public {

        // we need to send token address and amount :  
        // function getUsdValue(address token, uint256 amount) public view returns(uint256){

        uint256 ethAmount = 15e18;
        //15e18 = 2000$ *15 (1 eth = 2000$) = 30,000e18

        uint256 exceptedUsd = 30000e18;
        uint256 actualUsd = dsce.getUsdValue(weth, ethAmount);
        assertEq(actualUsd, exceptedUsd); 
    }

    function testGetTokenAmountFromUsd() public {

        // take input
        uint256 usdAmount = 100 ether;
        // 1 eth = 2000$ so 100$ = 0.05 eth
        uint excpectedWeth = 0.05 ether;
        uint actualWeth = dsce.getTokenAmountFromUsd(weth, usdAmount);
        assertEq(actualWeth, excpectedWeth);
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
     
    /**
     * @notice we need to check "isAllowedToken" modifier in depositeColllateral func
     * @notice for that you need to pass tokenCollateralAddress(address token) , also need to mock ERC20
     * @notice you need to send token(name,symbol) and user and amount
     */
    function testRevertsWithUnapprovedCollateral() public {

        ERC20Mock randomToken = new ERC20Mock("RAN", "RAN", USER, AMOUNT_COLLATERAL);
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__NotAllowedToken.selector);
        dsce.depositeCollateral(address(randomToken), AMOUNT_COLLATERAL);
        vm.stopPrank();

    }

    // we are going to do lots depositCollateral test so make a modifier for that
    modifier depositCollateral() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositeCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
        _;
    }

    function testCanDepositeCollateralAndGetAccountInfo() public depositCollateral {
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = dsce.getAccountInformation(USER);

        uint256 expectedTotalDscMinted = 0;
        // uint256 expectedCollateralValueInUsd = dsce.getTokenAmountFromUsd(weth, collateralValueInUsd);
        // assertEq(totalDscMinted, expectedTotalDscMinted);
        // assertEq(collateralValueInUsd, expectedCollateralValueInUsd);

        uint256 expectedDepositeAmount = dsce.getTokenAmountFromUsd(weth, collateralValueInUsd);
        assertEq(totalDscMinted, expectedTotalDscMinted);
        assertEq(AMOUNT_COLLATERAL, expectedDepositeAmount);




    }
}