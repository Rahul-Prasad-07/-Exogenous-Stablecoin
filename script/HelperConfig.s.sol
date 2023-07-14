// SPDX-License-Identifier:MIT

pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";

// mocks for price feeds
import {MockV3Aggregator} from "../test/mocks/MockV3Aggregator.sol";

// mocks for Erc20 tokens form openzeppelin
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";

contract HelperConfig is Script {

    struct NetworkConfig {
        address wethUsdPriceFeed;
        address wbtcUsdPriceFeed;
        address weth;
        address wbtc;
        uint256 deployerKey;
    }
    
    uint8 public constant DECIMALS =8;      
    int256 public constant ETH_USD_PRICE = 2000e8;
    int256 public constant BTC_USD_PRICE = 1000e8;
    uint256 public DEFAULT_ANVIL_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80; //we need to store this on env

    NetworkConfig public activeNetworkConfig;
    
    
    /**
     * @notice This function will set the activeNetworkConfig variable.
     * It will check the chain id and based on that it will set the activeNetworkConfig variable.
     */
    constructor() {
        if(block.chainid ==  11155111){
            activeNetworkConfig = getSepoliaEthConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilEthConfig();
        }
    }

    function getSepoliaEthConfig() public view returns(NetworkConfig memory){
        
        return NetworkConfig ({
            wethUsdPriceFeed : 0x694AA1769357215DE4FAC081bf1f309aDC325306,
            wbtcUsdPriceFeed : 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43,
            weth: 0xdd13E55209Fd76AfE204dBda4007C227904f0a81,
            wbtc: 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063,
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
    }
    
    /**
     * @notice This function will create the config for the anvil network.
     * @notice constructor of MockV3Aggregator is taking two arguments : decimals and price --> (DECIMALS, ETH_USD_PRICE/BTC_USD_PRICE)
     * 
     * 1. Deploy the mock price feeds for eth and btc.
     * 2. Deploy the mock erc20 tokens for eth and btc.
     * 3. return the mock price feeds and mock erc20 tokens address.
     */
    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory){
        
        // if we don't put this check then it will create the config & Deploy contracts everytime we call this function.
        if(activeNetworkConfig.wethUsdPriceFeed != address(0)){
            return activeNetworkConfig;
        }

        // now we are going to do broadcasting.we need couple of mocks of price feeds and ERC20 tokens
        vm.startBroadcast();
    
        // for eth
        MockV3Aggregator ethUsdPriceFeed = new MockV3Aggregator(
            DECIMALS,
            ETH_USD_PRICE
    
        );

        ERC20Mock wethMock = new ERC20Mock("WETH", "WETH", msg.sender, 1000e8);

        // for btc
        MockV3Aggregator btcUsdPriceFeed = new MockV3Aggregator(
           DECIMALS,
           BTC_USD_PRICE
    
        );

        ERC20Mock wbtcMock = new ERC20Mock("WBTC", "WBTC", msg.sender, 1000e8);

        vm.stopBroadcast();

         return NetworkConfig({
            wethUsdPriceFeed: address(ethUsdPriceFeed),
            wbtcUsdPriceFeed: address(btcUsdPriceFeed),
            weth: address(wethMock),
            wbtc: address(wbtcMock),
            deployerKey: DEFAULT_ANVIL_KEY
        });

    }
    
 

}