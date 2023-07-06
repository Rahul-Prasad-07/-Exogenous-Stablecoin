pragma solidity ^0.8.18;

import {DecentralizedStablecoin} from "./CatStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

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
 * - as you procced with actual proccess, you need to add deposite. Yes then start with depositeCollateral func.
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

    /////////////////////////////////
    //------ State Variables ------//
    /////////////////////////////////

    // we are mapping the token address to the price feed address bcz we need to know the price of the token
    // so we have list of s_priceFeeds(these are allowed token) : where we are going to set it ? --> In constructor
    mapping(address token => address priceFeed) private s_priceFeeds;
    mapping(address user => mapping(address token => uint256 amount))
        private s_collateralDeposited;

    DecentralizedStablecoin private immutable i_dsc;

    ////////////////////////
    //------ Events ------//
    ///////////////////////

    event collateralDeposited(
        address indexed user,
        address indexed token,
        uint256 amount
    );

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
    function depositeCollateral(
        address tokenCollateralAddress,
        uint256 amountCollateral
    )
        external
        moreThanZero(amountCollateral)
        isAllowedToken(tokenCollateralAddress)
        nonReentrant
    {  
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

    function mintDsc() external {}

    function burnDsc() external {}

    function liquidate() external {}

    function getHealthFactor() external {}
}
