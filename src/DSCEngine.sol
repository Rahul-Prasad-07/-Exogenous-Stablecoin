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
    uint256 private constant MIN_HEALTH_FACTOR = 1;  

    ////////////////////////
    //------ Events ------//
    ///////////////////////

    event collateralDeposited(address indexed user, address indexed token, uint256 amount);

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

    function depositCollateralAndMintDsc() external {}

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

    function depositeCollateral(address tokenCollateralAddress,uint256 amountCollateral) external moreThanZero(amountCollateral) isAllowedToken(tokenCollateralAddress) nonReentrant {

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

    function redeemCollateralForDsc() external {}

    function redeemCollateral() external {}

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

    function mintDsc(uint256 amountDscToMint) external moreThanZero(amountDscToMint) nonReentrant {

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

    function burnDsc() external {}

    function liquidate() external {}

    function getHealthFactor() external {}


    //////////////////////////////////////////////
    //------ Private & Internal Functions ------//
    //////////////////////////////////////////////

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
