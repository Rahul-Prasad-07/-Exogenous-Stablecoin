pragma solidity ^0.8.18;

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
 * **/

 contract DSCEngine {

    function depositCollateralAndMintDsc() external {}

    function depositeCollateral() external {}

    function redeemCollateralForDsc() external {}

    function redeemCollateral() external {}

    function mintDsc() external {}
    
    function burnDsc() external {}

    function liquidate() external {}

    function getHealthFactor() external {}

 }