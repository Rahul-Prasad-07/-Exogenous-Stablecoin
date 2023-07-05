// SPDX-License-Identifier: MIT

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

pragma solidity ^0.8.18;

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/*
* @title DecentralizedStablecoin
* @author Rahul Prasad
* Minting : Exogenous ( xGold, xSilver, ETH, BTC, etc. )
* Relative Stablity : Pegged to USD 

* this is the contract meant to be governd by DSCEngine. This contract is just the ERC20 implementation of our stablecoin system.
* we are inheriting ERC20Burnable contract from openzeppelin library. This contract is ERC20 implementation with burn functionality.
* since we want that our token is own by our logic contract, we are inheriting Ownable contract in our ERC20 contract.
*/


contract DecentralizedStablecoin is ERC20Burnable, Ownable{

    error  DecentralizedStablecoin_MustBeMoreThanZero();
    error DecentralizedStablecoin_BurnAmountExceedBalance();
    error DecentralizedStablecoin_NotZeroAddress();

    
    constructor() ERC20("DecentralizedStablecoin","DSC"){}

    function burn(uint _amount) public override onlyOwner{
        uint256 balance = balanceOf(msg.sender);

        if(_amount <= 0){
            revert DecentralizedStablecoin_MustBeMoreThanZero();
        }
        if(balance < _amount){
            revert DecentralizedStablecoin_BurnAmountExceedBalance();
        }
        super.burn(_amount);
    }

    function mint(address _to, uint256 _amount) external onlyOwner returns (bool){
        if(_to ==address(0)){
            revert DecentralizedStablecoin_NotZeroAddress();
        }
        if(_amount <= 0){
            revert DecentralizedStablecoin_MustBeMoreThanZero();
        }
        _mint(_to, _amount);
        return true;
    }

}