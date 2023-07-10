pragma solidity ^0.8.18;

// Layout of contract
// Version
// imports
// errors
// interfaces, libraries, contracts
// type declarations
// state variables
// events
// modifiers
// functions

// Layout of functions
// constructor
// recieve function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

import {DecentralizedStablecoin} from "./CatStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/** 
 * @title DSCEngine
 * @author Rahul Prasad
 * 
 * The system is designed to have token maintain a 1 tokrn == $1 peg
 * This stablecoin has properties:
 * - Exogenous collateral
 * - Doller pegged
 * - Algorithmic
 * 
 * It is similar to DAI if DAI has no governance, no fees, and was only backed by WETH and WBTC
 * Our DSC system should always be "Over Collateralized". At no point, should the value of all collateral <= the $ backed value of all the DSC.
 *  
 *    $100 ETh --> $40 ETH : it goes liquidated
 *    $100 ETh --> $60 ETH : Threshold setup --> you should kick out of the system, you close to liquidate
 *    $50 DSC

 *    $100 ETh --> $75 ETH : Threshold setup for 150% --> you should kick out of the system, you close to liquidate
 *    $50 DSC
 *    Undercollateralized !!

 *    If someone pays back your 50 minted dsc, they can have all your collateral for a discount
 *    like by paying $50 DSC, they can have $75 ETH, he made $25 profit
 * 
 * @notice This is the main contract of the system. This contract is the logic contract of the system.
 * It handles all logic for minting and redeeming DSC, as well as depositing & withdrawing collateral.
 * @notice This contract is very loosely based on the MakerDao DSS (DAI) system 
 * 
 * Where to start writing ? 
 * - as you procced with actual proccess, you need to add deposite. Yes then start with "depositeCollateral"func.
 * - Then you need to add minting. Yes then start with "mintDsc" func.
 * 
 * **/

contract DSCEngine is ReentrancyGuard {


    ///////////////////////
    //------ Errors -----//
    ///////////////////////

    error DSCEngine__NeedsMoreThanZero();
    error DSCEngine__TokenAddressAndPriceFeedAddressMustBeSameLength();
    error DSCEngine__NotAllowedToken();
    error DSCEngine__TransferFailed();
    error DSC__BreakHealthFactor(uint256 healthFactor);
    error DSCEngine__MintFailed();
    error  DSCEngine__UserHealthy();
    error DSCEngine__HealthFactorNotImproved();

    /////////////////////////////////
    //------ State Variables ------//
    /////////////////////////////////

    // we are mapping the token address to the price feed address bcz we need to know the price of the token
    // so we have list of s_priceFeeds(these are allowed token) : where we are going to set it ? --> In constructor
    mapping(address token => address priceFeed) private s_priceFeeds;
    mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposited;
    mapping(address user => uint256) private s_dscMinted;

    address [] private s_collateralTokens; // list of all collateral token. push tokenAddress[i] this variable in our constructor
    DecentralizedStablecoin private immutable i_dsc;

    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50 ; // It means you need to be 200% overcollateralized
    uint256 private constant LIQUIDATION_PRECISION = 100; // DIDVIDE it while checking health factor bcz it's has big value 
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;  
    uint256 private constant LIQUIDATION_BONUS = 10; // this means 10% discount on collateral (10/100 = 10 %)

    ////////////////////////
    //------ Events ------//
    ///////////////////////

    event collateralDeposited(address indexed user, address indexed token, uint256 amount);
    event CollateralRedeemed(address indexed redeemedFrom, address indexed  redeemedTo , address indexed token ,uint256 amount);

    ///////////////////////////
    //------ Modifier ------//
    ///////////////////////////

    modifier moreThanZero(uint256 amount) {
        if (amount == 0) {
            revert DSCEngine__NeedsMoreThanZero();
        }
        _;
    }

    modifier isAllowedToken(address token) {
        if (s_priceFeeds[token] == address(0)) {
            revert DSCEngine__NotAllowedToken();
        }
        _;
    }

    ///////////////////////////
    //------ Functions ------//
    ///////////////////////////

    /**
     *
     * set the allowed toeknlist (priceFeed address)
     * Dsc engine needs to know abount our CatStableCoin bcz it needs to done burn and mint : passed dscAddress
     *
     * @param tokenAddress The address of the token to deposit as collateral
     * @param priceFeedAddress  The address of the price feed for the token
     * @param dscAddress The address of the DSC token
     *
     * loop throgh the token address and update our mapping (token address maps to pricefeed address)
     * for getting price we use USD Price Feed. for example : ETH/USD, BTC/USD, MKR/USD
     *
     * That's how are set to allowed which token we are going to use
     * If they has price feed then they are allowed otherwise they are not
     *
     * Import decentralizedStableCoin from CatStableCoin.sol and set it as private immutable variable i_dsc
     * Then we can use it in our functions constructor and set dsCAddress to i_dsc
     *
     * @notice : nonReentrant is gas intensive, if your func doesn't need that then remove while auditing
     *
     */

    constructor(
        address[] memory tokenAddress,
        address[] memory priceFeedAddress,
        address dscAddress
    ) {
        if (tokenAddress.length != priceFeedAddress.length) {
            revert DSCEngine__TokenAddressAndPriceFeedAddressMustBeSameLength();
        }

        for (uint256 i = 0; i < tokenAddress.length; i++) {
            s_priceFeeds[tokenAddress[i]] = priceFeedAddress[i]; // set token address to price feed address
            s_collateralTokens.push(tokenAddress[i]); // array of all collateral token
        }

        i_dsc = DecentralizedStablecoin(dscAddress);
    }


    ////////////////////////////////////
    //------ External Functions ------//
    ////////////////////////////////////
    
    /**
     * 
     * @param tokenCollateralAddress The address of the token to deposit as collateral
     * @param amountCollateral The amount of collateral to deposit
     * @param amountDscToMint  The amount of DSC to mint
     * @notice This function deposits collateral and mints DSC in one transaction
     */
    function depositCollateralAndMintDsc(address tokenCollateralAddress, uint256 amountCollateral, uint256 amountDscToMint) external {
        depositeCollateral(tokenCollateralAddress, amountCollateral);
        mintDsc(amountDscToMint);
    }

    /**
     * @notice follows CEI pattern (checks-effects-interactions)
     * @param tokenCollateralAddress The address of the token to deposit as collateral
     * @param amountCollateral The amount of collateral to deposit
     *
     * Modifier : Set a modifier  "moreThanZero" and pass amountCollateral
     * Modifier : Then we need to check if the token collateral is allowed or not
     *            for that we write modifier "isAllowedToken" and pass tokenCollateralAddress
     * Modifier : we additionaly add modifer call nonReentrant from openzepplein,
     *            when u are working with excternal contract then this might be consider making function nonReentrant (retratncy attack)
     *
     *  @notice : nonReentrant is gas intensive, if your func doesn't need that then remove while auditing
     *
     * Logic --> depositeCollateral
     *
     * 1. track how much money they deposited : mapping of user address to --> token address to amount
     * 2. Updated state so we need to emit event
     *
     *
     *
    */

    function depositeCollateral(address tokenCollateralAddress,uint256 amountCollateral) public moreThanZero(amountCollateral) isAllowedToken(tokenCollateralAddress) nonReentrant {

        // Effects 
        //internal record keeping
        s_collateralDeposited[msg.sender][tokenCollateralAddress] += amountCollateral; // updating state and when we update state we emit event
        
        // state updated : emit event
        emit collateralDeposited(msg.sender,tokenCollateralAddress,amountCollateral);

        //interactions
        bool success = IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), amountCollateral); // transfer token from user to this contract
        if(!success){
            revert DSCEngine__TransferFailed();
        }

    }
    
    /**
     * 
     * @param tokenCollateralAddress The address of the token to deposit as collateral
     * @param amountCollateral  The amount of collateral to redeem
     * @notice health factor must be greater than 1 after collateral pulled
     * DRY : Don't repeat yourself
     * CEI : checks-effects-interactions vialoted little bit bcz we need to check health factor before and after
     *  @notice our Third party user isn't the one with bad debt. we need to redeem random person collateral
     * so we are writing another redeemCollateral private function, where somebody can nliquidate amountcollateral address from account and transfer it address TO account. 
     */
    function  redeemCollateral(address tokenCollateralAddress, uint256 amountCollateral) public moreThanZero(amountCollateral) nonReentrant {
        
        _redeemCollateral(msg.sender, msg.sender,tokenCollateralAddress, amountCollateral);
        _revertIfHealthFactorIsBroken(msg.sender); // if dosen't need then remove while auditing
    }
    
    
    /**
     * 
     * @param tokenCollateralAddress collateral address to redeem
     * @param amountCollateral amount of collateral to redeem
     * @param amountDscToBurn  amount of DSC to burn
     * This function burns DSC and redeems collateral in one transaction
     * 
     */
    function redeemCollateralForDsc(address tokenCollateralAddress, uint256 amountCollateral, uint256 amountDscToBurn) external {
        burnDsc(amountDscToBurn);
        redeemCollateral(tokenCollateralAddress, amountCollateral);
        // redeem collateral has alredy checks health factor so we don't need to check again
    }

    /**
     * @notice follows CEI pattern (checks-effects-interactions)
     * @param amountDscToMint The amount of decentralized stablecoin to mint
     * @notice nonReentrant is gas intensive, if your func doesn't need that then remove while auditing
     * @notice they must have more collateral value than the minimum collateralization ratio (Threshold) 
     * checks ?
     * - check if the collateral value > DSC amount
     * 
     * Logic --> mintDsc func 
     * keep track of how much DSC they minted
     * 
     */

    function mintDsc(uint256 amountDscToMint) public moreThanZero(amountDscToMint) nonReentrant {

        s_dscMinted[msg.sender] += amountDscToMint;

        // if they minted too much DSC then revert, so check the health factor
        _revertIfHealthFactorIsBroken(msg.sender);

        // to mint dsc we have CatStableCoin contract that has functionalities to mint DSC but the owner of that contract can only mint it 
        //  function mint(address _to, uint256 _amount) external onlyOwner returns (bool)

        bool minted = i_dsc.mint(msg.sender,amountDscToMint );
        if(!minted){
            revert DSCEngine__MintFailed();
        }


    }
    
    /**
     * 
     * @param amount amount of DSC to burn
     *
     */
    function burnDsc(uint256 amount) public moreThanZero(amount)  {
        _burnDsc(amount, msg.sender, msg.sender);
        _revertIfHealthFactorIsBroken(msg.sender); // if dosen't need then remove while auditing
    }
     
    
    // Liquidate function is key that hold the whole system together
    // If we do start nearing undercollateralized, then we need someone to come in and liquidate us
    // $100 ETH backing $50 DSC
    // if price of ETH goes down to $20 ETH backing $50 DSC then isn't worth $1 anymore.
    // we can't let this happen. so befor that we need to liquidate

    // If someone is almost undercollateralized, we will pay you to liquidate them
    // $75 ETH backing $50 DSC : this is way lower than our 50% threshold, so we are gonna let liquidator 75$ and pays(burn) of $50 DSC
    // The only way you get bonus when system is over colateraliized($20 ETH backing $50 DSC : you can't give 50$ DSC for 20$ ETH)
    // they able to track the users and thier position by listening to the events

    /**
     * 
     * @param collateral The address of the ERC20 collateral to liquidate
     * @param user  The address of the user to liquidate
     * @param debtToCover  The amount of debt (DSC) you want to burn to improve the users health factor
     * @notice u can partially liquidate a user
     * @notice u will get liquidation bonus for taking users fund
     * @notice THis function works when the protocol will be roughly 200% over collateralized in order to work this
     * @notice A known bug would be if the were 100% or less collaterlized, then we wouldn't be able to incentivice liquidators
     * For example, if the price of collateral plummeted befor anyone could be liquidated, then we would be in trouble
     * 
     * Follows CEI pattern (checks-effects-interactions)
     */

    function liquidate(address collateral, address user,uint256 debtToCover) external moreThanZero(debtToCover) nonReentrant{

        // need to check the health factor of the user
        uint256 startingUserHealthFactor = _healthFactor(user);
        if(startingUserHealthFactor >= MIN_HEALTH_FACTOR){
            revert DSCEngine__UserHealthy();
        }

        // we want to burn thier DSC "Debt"
        // and take thier collateral
        // Bad USer :  $140 ETH - $100 DSC : it healthFactor is less than 1 (MIN_HEALTH_FACTOR)
        // So i will pay $100 DSC to burn thier $100 DSC and take thier $140 ETH : i got 40$ bonus
        // $100 of DSC == ?? ETH? (i need to know how much of $100 DSc Toekn is worth in ETH for $100 of debt

        // if price 2000$/ ETH then
        // return (usdAmountInWei * PRECISION) / (uint256(price) * ADDITIONAL_FEED_PRECISION);
        // (100e18 * 1e18)/ (2000e8 * 1e10) = 0.05
        // 100$ DSC == 0.05 ETH

        uint256 tokenAmountFromDebtCoverd = getTokenAmountFromUsd(collateral, debtToCover);
        // give them a 10% bonus to user 
        // so we will pay 110$ DSC to burn thier $100 DSC and take thier $140 ETH : i got 30$ bonus
        // liquidators needs to pay in eth to burn thier $100 DSC(which is 0.05 eth). 
        // but you ar giving giving 10% bonus to then , you need to pay $110 DSC (which is 0.055 eth ) to burn thier $100 DSC


        uint256 bonusCollateral = (tokenAmountFromDebtCoverd * LIQUIDATION_BONUS) / LIQUIDATION_PRECISION;

        // Actual amount in eth to pay to burn dsc($100) = 0.05 ETH
        // after 10 % bonus = (0.05 *0.1 = 0.005) = 0.005+0.05 = 0.055 ETH to pay to burn $100 DSC

        uint256 totalCollateralToRedeem = tokenAmountFromDebtCoverd + bonusCollateral; 

        // now we need to redeem the collateral from the user (totalCollateralToRedeem)--> go to redeemCollateral function and make same internal function 
        _redeemCollateral(user, msg.sender,collateral, totalCollateralToRedeem);

        // burn DSC --> go to burnDsc function and make same internal function
        // _ burnDsc(uint256 amountDscTOBurn, address onBehalfOf, address dscFrom)
        _burnDsc(debtToCover, user, msg.sender);

        uint256 endingUserHealthFactor = _healthFactor(user);
        if(endingUserHealthFactor <= startingUserHealthFactor){
            revert DSCEngine__HealthFactorNotImproved();
        }

        _revertIfHealthFactorIsBroken(msg.sender);


       


    }

    function getHealthFactor() external {}


    //////////////////////////////////////////////
    //------ Private & Internal Functions ------//
    //////////////////////////////////////////////
    
    /**
     * @dev low level internal function, do not call unless the function it is checking for health factor being broken
     * @param amountDscTOBurn  amount of DSC to burn
     * @param onBehalfOf  address of the Bad debt user 
     * @param dscFrom  address of where we are getting dsc from
     */
    function _burnDsc(uint256 amountDscTOBurn, address onBehalfOf, address dscFrom) private {

        // mapping our dsc in s_dscMinted, we need to burn it or reduce it
        s_dscMinted[onBehalfOf] -= amountDscTOBurn;
        bool succes = i_dsc.transferFrom( dscFrom, address(this), amountDscTOBurn);
        if(!succes){
            revert DSCEngine__TransferFailed();
            // we almost can't revert here bcz we already reduced the amount
        }

        i_dsc.burn(amountDscTOBurn);
        

    }



    function _redeemCollateral(address from, address to, address tokenCollateralAddress, uint256 amountCollateral ) private {

        
        // remove collateral from Bad Debt user(address from) and give it to liquidator(address to)
        s_collateralDeposited[from][tokenCollateralAddress] -= amountCollateral;

        // state chnage : emit event
        emit CollateralRedeemed(from, to ,tokenCollateralAddress,amountCollateral);

        // return collateral to liquidator
        bool succes = IERC20(tokenCollateralAddress).transfer(to, amountCollateral);
        if(!succes){
            revert DSCEngine__TransferFailed();
        }
        _revertIfHealthFactorIsBroken(msg.sender); // if dosen't need then remove while auditing

    }


    /**
     * 
     * @param user The address of the user to check the health factor for
     * check health factor (do they have enough collateral to mint DSC)
     * revert if they don't have enough collateral
     */

    function _revertIfHealthFactorIsBroken(address user) internal view{

        uint256 userHealthFactor = _healthFactor(user);
        if(userHealthFactor < MIN_HEALTH_FACTOR){
            revert DSC__BreakHealthFactor(userHealthFactor);
        }

    }
     
    /**
     * 
     * @param user The address of the user to check the health factor for
     * @return The health factor of the user
     * if the user goes below 1, then they can get liquidated
     * 
     * * What we need for check?
     * - Total dsc minted
     * - Total collateral deposited VALUE
     * 
     *   check healthFactor : $100/ 100 dsc = 1 , now we go down less than $100 then we will go in undercollateralized
     *   so we need to be always overcollateralized , so you need to set thresold ( atleats $150/ 100 dsc): you need to create thresold
     *   $150 ETH / 100 dsc = 1.5 --> but now 150*50 = 7500, 7500/100 = 75, 75/100 <1
     *   $1000 ETH * 50 = 50,000, 50,000 /100 = 500, 500/100 >1 
     */
    function _healthFactor(address user) private view returns(uint256){

        (uint256 totalDscMinted, uint256 collateralValueInUsd) = _getAccountInformation(user);

        // check healthFactor : $100/ 100 dsc = 1 , now we go down less than $100 then we will go in undercollateralized
        // so we need to be always overcollateralized , so you need to set thresold ( atleats $150/ 100 dsc): you need to create thresold
        // $150 ETH / 100 dsc = 1.5 --> but now 150*50 = 7500, 7500/100 = 75, 75/100 <1
        // $1000 ETH * 50 = 50,000, 50,000 /100 = 500, 500/100 >1 

        uint256 collateralAdjustedForThresold = (collateralValueInUsd * LIQUIDATION_THRESHOLD)/LIQUIDATION_PRECISION ;

        return (collateralAdjustedForThresold * PRECISION)/ totalDscMinted ;
    }

    function _getAccountInformation(address user) private view returns(uint256 totalDscMinted, uint256 collateralValueInUsd){

        // to get total Dsc minted, you can get from mapping that we have created: s_dscMinted

        totalDscMinted = s_dscMinted[user];
        collateralValueInUsd = getAccountCollateralValueInUsd(user); // public function to get collateral value in USD
    }

    //////////////////////////////////////////////
    //------ Public & External Functions ------//
    //////////////////////////////////////////////

    function getTokenAmountFromUsd(address token, uint256 usdAmountInWei) public view returns(uint256) {
        
        // Price of ETH (token)
        // ($/ETH) : price of eth is 2000$/ETH, then what is the amount of eth i can get in $10? = 0.0050000000 eth

        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (,int256 price,,,) = priceFeed.latestRoundData();
         
        // ($10e18 * 1e18) / ($2000e8 *1e10) = 0.005000000000000000 eth
        return (usdAmountInWei * PRECISION) / (uint256(price) * ADDITIONAL_FEED_PRECISION);
    }

    function getAccountCollateralValueInUsd(address user) public view returns(uint256 totalCollateralValueInUsd){

        // loop through all the collateral token, get the amount they have deposited and map it to
        // the price, to get the USD value : we have mapping of s_priceFeed
        // we are going to be that more agnostic, so any amount of token you can deposite --> make state variable of address array s_collateralToken

        for(uint256 i=0; i < s_collateralTokens.length; i++ ){

            address token = s_collateralTokens[i];
            uint256 amount = s_collateralDeposited[user][token];

            totalCollateralValueInUsd += getUsdValue(token, amount);


        }
        return totalCollateralValueInUsd;
    }
    
    // this is where we get real price using PriceFeed by chainlink
    function getUsdValue(address token, uint256 amount) public view returns(uint256){
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (,int256 price,,,) = priceFeed.latestRoundData();
        
        // 1 ETH = $1000
        // The returned value from CL will be 1000 * 1e8;
        return ((uint256(price)* ADDITIONAL_FEED_PRECISION) * amount)/PRECISION; // ((1000 * 1e8 *(1e10)) * 1000 * 1e18)/1e18

    }

    
}
