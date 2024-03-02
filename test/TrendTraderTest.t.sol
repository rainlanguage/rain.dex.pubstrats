// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.19;

import {Vm} from "forge-std/Vm.sol";
import {Test, console2} from "forge-std/Test.sol";
import {IParserV1} from "rain.interpreter.interface/interface/IParserV1.sol";
import {IInterpreterV2} from "rain.interpreter.interface/interface/unstable/IInterpreterV2.sol";
import {IInterpreterStoreV2} from "rain.interpreter.interface/interface/unstable/IInterpreterStoreV2.sol";
import {ISubParserV2} from "rain.interpreter.interface/interface/unstable/ISubParserV2.sol";
import {IExpressionDeployerV3} from "rain.interpreter.interface/interface/unstable/IExpressionDeployerV3.sol";
import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";
import "rain.math.fixedpoint/lib/LibFixedPointDecimalArithmeticOpenZeppelin.sol";
import "rain.math.fixedpoint/lib/LibFixedPointDecimalScale.sol";
import "src/lib/LibEncodedDispatch.sol";
import "src/lib/LibNamespace.sol";
import "src/lib/LibTrendTrade.sol";


contract TrancheSpreadTest is Test {
    using Strings for address;
    using Strings for uint256;

    using LibFixedPointDecimalArithmeticOpenZeppelin for uint256;
    using LibFixedPointDecimalScale for uint256;

    uint256 constant FORK_BLOCK_NUMBER = 54173338;
    uint256 constant CONTEXT_VAULT_IO_ROWS = 5;
    address constant ORDER_OWNER = address(0x19f95a84aa1C48A2c6a7B2d5de164331c86D030C);

    // Strategy Params
    address constant TOKEN_ADDRESS = address(0x692AC1e363ae34b6B489148152b12e2785a3d8d6);
    address constant RESERVE_ADDRESS = address(0xc2132D05D31c914a87C6611C10748AEb04B58e8F);
    uint256 constant TOKEN_DECIMALS = 18;
    uint256 constant RESERVE_DECIMALS = 6;
    uint256 constant MEAN_COOLDOWN = 1440;
    uint256 constant BOUNTY = 8e16;
    uint256 constant JITTERY_BINOMIAL_BITS = 10;
    uint256 constant TWAP_SHORT_TIME = 1800;
    uint256 constant TWAP_LONG_TIME = 14400;

    // Buy Order
    uint256 constant BUY_MEAN_AMOUNT = 160e18;
    uint256 constant BUY_TREND_UP_FACTOR = 3e18;
    uint256 constant BUY_TREND_DOWN_FACTOR = 33e16;

    // Sell Order
    uint256 constant SELL_MEAN_AMOUNT = 150e18;
    uint256 constant SELL_TREND_UP_FACTOR = 33e16;
    uint256 constant SELL_TREND_DOWN_FACTOR = 3e18;


    IParserV1 public PARSER;
    IInterpreterV2 public INTERPRETER;
    IInterpreterStoreV2 public STORE;
    IExpressionDeployerV3 public EXPRESSION_DEPLOYER;
    ISubParserV2 public ORDERBOOK_SUPARSER;
    ISubParserV2 public UNISWAP_WORDS;


    function selectPolygonFork() internal {
        uint256 fork = vm.createFork(vm.envString("RPC_URL_POLYGON"));
        vm.selectFork(fork);
        vm.rollFork(FORK_BLOCK_NUMBER);
    }

    function setUp() public {
        selectPolygonFork();

        PARSER = IParserV1(0xbe7eF1c2E86cd36642Be685715a089ecc1a15f5C);
        STORE = IInterpreterStoreV2(0xCCe6D0653B6DAC3B5fAd3F2A8E47cCE537126aD0);
        INTERPRETER = IInterpreterV2(0x8bb0e1Ade233f386668f6e3c11762f18bF8293b3);
        EXPRESSION_DEPLOYER = IExpressionDeployerV3(0xB16bbF12ECE3414af72F660aB63F4dDa1D7250FA);
        ORDERBOOK_SUPARSER = ISubParserV2(0x14c5D39dE54D498aFD3C803D3B5c88bbEcadcc48);
        UNISWAP_WORDS = ISubParserV2(0xA679357534Ec68c61009d69382E21bF0e8C1d45c);
    }

    function testModelTrendTrader(uint256 lastTime,uint256 trendNumerator) public {

        lastTime = uint32(bound(lastTime, 0, type(uint32).max/uint32(2)));
        trendNumerator = bound(trendNumerator, 3e17, 2e18);
        uint256 trendDenominator = 1e18;
        uint256 testNow = type(uint32).max;


        address buyExpression;
        address sellExpression;
        FullyQualifiedNamespace namespace =
                LibNamespace.qualifyNamespace(StateNamespace.wrap(uint256(uint160(ORDER_OWNER))), address(this));
        uint256[][] memory context = new uint256[][](0);

        bytes memory sellOrderRainlang;
        bytes memory buyOrderRainlang;

        {
            LibTrendTrade.TrendTradeTest memory sellTestTrend = LibTrendTrade.TrendTradeTest(
                address(ORDERBOOK_SUPARSER),
                address(UNISWAP_WORDS),
                100e18,
                lastTime,
                testNow,
                trendNumerator,
                trendDenominator,
                SELL_TREND_UP_FACTOR,
                SELL_TREND_DOWN_FACTOR,
                MEAN_COOLDOWN,
                JITTERY_BINOMIAL_BITS
            );
            sellOrderRainlang = LibTrendTrade.getTestTrendOrder(
                    vm, 
                    sellTestTrend
            );
            LibTrendTrade.TrendTradeTest memory buyTestTrend = LibTrendTrade.TrendTradeTest(
                address(ORDERBOOK_SUPARSER),
                address(UNISWAP_WORDS),
                200e18,
                lastTime,
                testNow,
                trendDenominator,
                trendNumerator,
                BUY_TREND_UP_FACTOR,
                BUY_TREND_DOWN_FACTOR,
                MEAN_COOLDOWN,
                JITTERY_BINOMIAL_BITS
            );
            buyOrderRainlang = LibTrendTrade.getTestTrendOrder(
                    vm, 
                    buyTestTrend
            );
        }

        {
            {
                (bytes memory bytecode, uint256[] memory constants) = PARSER.parse(buyOrderRainlang);
                (,,buyExpression,) = EXPRESSION_DEPLOYER.deployExpression2(bytecode, constants);
            }
            {
                (bytes memory bytecode, uint256[] memory constants) = PARSER.parse(sellOrderRainlang);
                (,,sellExpression,) = EXPRESSION_DEPLOYER.deployExpression2(bytecode, constants);
            }
        }
        (uint256[] memory sellStack,) = IInterpreterV2(INTERPRETER).eval2(
            IInterpreterStoreV2(address(STORE)),
            namespace,
            LibEncodedDispatch.encode2(sellExpression, SourceIndexV2.wrap(0), type(uint16).max),
            context,
            new uint256[](0)
        );

        (uint256[] memory buyStack,) = IInterpreterV2(INTERPRETER).eval2(
            IInterpreterStoreV2(address(STORE)),
            namespace,
            LibEncodedDispatch.encode2(buyExpression, SourceIndexV2.wrap(0), type(uint16).max),
            context,
            new uint256[](0)
        );

        string memory file = string.concat("./test/csvs/sell-trend-diff", ".csv");

        vm.writeLine(file, string.concat(
            sellStack[0].toString(),
            ",",
            buyStack[0].toString(),
            ",",
            sellStack[3].toString()
        )); 


        
    }
    
    function testHandleIo() public {

        FullyQualifiedNamespace namespace =
                LibNamespace.qualifyNamespace(StateNamespace.wrap(uint256(uint160(ORDER_OWNER))), address(this)); 

        address sellExpression;
        address buyExpression;
        {   
            LibTrendTrade.TrendTrade memory buyOrderRainlang = LibTrendTrade.TrendTrade(
                address(ORDERBOOK_SUPARSER),
                address(UNISWAP_WORDS),
                TOKEN_ADDRESS,
                TOKEN_DECIMALS,
                RESERVE_ADDRESS,
                RESERVE_DECIMALS,
                BUY_MEAN_AMOUNT,
                MEAN_COOLDOWN,
                BOUNTY,
                JITTERY_BINOMIAL_BITS,
                TWAP_SHORT_TIME,
                TWAP_LONG_TIME,
                BUY_TREND_UP_FACTOR,
                BUY_TREND_DOWN_FACTOR  
            );
            (bytes memory bytecode, uint256[] memory constants) = PARSER.parse(
                LibTrendTrade.getTrendBuyOrder(
                    vm, 
                    buyOrderRainlang
                )
            );
            (,, buyExpression,) = EXPRESSION_DEPLOYER.deployExpression2(bytecode, constants);
        }
        {   
            LibTrendTrade.TrendTrade memory sellOrderRainlang = LibTrendTrade.TrendTrade(
                address(ORDERBOOK_SUPARSER),
                address(UNISWAP_WORDS),
                TOKEN_ADDRESS,
                TOKEN_DECIMALS,
                RESERVE_ADDRESS,
                RESERVE_DECIMALS,
                SELL_MEAN_AMOUNT,
                MEAN_COOLDOWN,
                BOUNTY,
                JITTERY_BINOMIAL_BITS,
                TWAP_SHORT_TIME,
                TWAP_LONG_TIME,
                SELL_TREND_UP_FACTOR,
                SELL_TREND_DOWN_FACTOR 
            );
            (bytes memory bytecode, uint256[] memory constants) = PARSER.parse(
                LibTrendTrade.getTrendSellOrder(
                    vm, 
                    sellOrderRainlang
                )
            );
            (,, sellExpression,) = EXPRESSION_DEPLOYER.deployExpression2(bytecode, constants);
        }
        {       
            uint256[][] memory sellOrderContext = getSellOrderContext(uint256(keccak256("sellOrder"))); 
            {
                sellOrderContext[2][0] = 1;
                sellOrderContext[4][4] = 0;

                vm.expectRevert(bytes("Partial sell."));
                (uint256[] memory sellStack,) = IInterpreterV2(INTERPRETER).eval2(
                    IInterpreterStoreV2(address(STORE)),
                    namespace,
                    LibEncodedDispatch.encode2(sellExpression, SourceIndexV2.wrap(1), type(uint16).max),
                    sellOrderContext,
                    new uint256[](0)
                );
            }
            {
                sellOrderContext[2][0] = 1;
                sellOrderContext[4][4] = 1;
                IInterpreterV2(INTERPRETER).eval2(
                    IInterpreterStoreV2(address(STORE)),
                    namespace,
                    LibEncodedDispatch.encode2(sellExpression, SourceIndexV2.wrap(1), type(uint16).max),
                    sellOrderContext,
                    new uint256[](0)
                );
            }
        }
        {       
            uint256[][] memory buyOrderContext = getBuyOrderContext(uint256(keccak256("buyOrder"))); 
            {
                buyOrderContext[2][0] = 1;
                buyOrderContext[4][4] = 0;
                vm.expectRevert(bytes("Partial buy."));
                (uint256[] memory sellStack,) = IInterpreterV2(INTERPRETER).eval2(
                    IInterpreterStoreV2(address(STORE)),
                    namespace,
                    LibEncodedDispatch.encode2(buyExpression, SourceIndexV2.wrap(1), type(uint16).max),
                    buyOrderContext,
                    new uint256[](0)
                );
            }
            {
                buyOrderContext[2][0] = 1e6;
                buyOrderContext[4][4] = 1e18;
                (uint256[] memory sellStack,) = IInterpreterV2(INTERPRETER).eval2(
                    IInterpreterStoreV2(address(STORE)),
                    namespace,
                    LibEncodedDispatch.encode2(buyExpression, SourceIndexV2.wrap(1), type(uint16).max),
                    buyOrderContext,
                    new uint256[](0)
                );
            }
        }
    } 

    function testSellCooldownCheck() public {
        FullyQualifiedNamespace namespace =
            LibNamespace.qualifyNamespace(StateNamespace.wrap(uint256(uint160(ORDER_OWNER))), address(this));
        
        address sellExpression;
        {   
            LibTrendTrade.TrendTrade memory sellOrderRainlang = LibTrendTrade.TrendTrade(
                address(ORDERBOOK_SUPARSER),
                address(UNISWAP_WORDS),
                TOKEN_ADDRESS,
                TOKEN_DECIMALS,
                RESERVE_ADDRESS,
                RESERVE_DECIMALS,
                SELL_MEAN_AMOUNT,
                MEAN_COOLDOWN,
                BOUNTY,
                JITTERY_BINOMIAL_BITS,
                TWAP_SHORT_TIME,
                TWAP_LONG_TIME,
                SELL_TREND_UP_FACTOR,
                SELL_TREND_DOWN_FACTOR 
            );
            (bytes memory bytecode, uint256[] memory constants) = PARSER.parse(
                LibTrendTrade.getTrendSellOrder(
                    vm, 
                    sellOrderRainlang
                )
            );
            (,, sellExpression,) = EXPRESSION_DEPLOYER.deployExpression2(bytecode, constants);
        }
        {       
            uint256[][] memory sellOrderContext = getSellOrderContext(uint256(keccak256("sellOrder"))); 
            (uint256[] memory sellStack,uint256[] memory sellKvs) = IInterpreterV2(INTERPRETER).eval2(
                IInterpreterStoreV2(address(STORE)),
                namespace,
                LibEncodedDispatch.encode2(sellExpression, SourceIndexV2.wrap(0), type(uint16).max),
                sellOrderContext,
                new uint256[](0)
            );
            STORE.set(
                StateNamespace.wrap(uint256(uint160(ORDER_OWNER))),
                sellKvs
            ); 
            vm.expectRevert(bytes("Trade cooldown."));
            IInterpreterV2(INTERPRETER).eval2(
                IInterpreterStoreV2(address(STORE)),
                namespace,
                LibEncodedDispatch.encode2(sellExpression, SourceIndexV2.wrap(0), type(uint16).max),
                sellOrderContext,
                new uint256[](0)
            );
            vm.warp(block.timestamp + MEAN_COOLDOWN + 1);
            IInterpreterV2(INTERPRETER).eval2(
                IInterpreterStoreV2(address(STORE)),
                namespace,
                LibEncodedDispatch.encode2(sellExpression, SourceIndexV2.wrap(0), type(uint16).max),
                sellOrderContext,
                new uint256[](0)
            );
        }
    }

    function testBuyCooldownCheck() public {
        FullyQualifiedNamespace namespace =
            LibNamespace.qualifyNamespace(StateNamespace.wrap(uint256(uint160(ORDER_OWNER))), address(this));
        
        address buyExpression;
        {   
            LibTrendTrade.TrendTrade memory buyOrderRainlang = LibTrendTrade.TrendTrade(
                address(ORDERBOOK_SUPARSER),
                address(UNISWAP_WORDS),
                TOKEN_ADDRESS,
                TOKEN_DECIMALS,
                RESERVE_ADDRESS,
                RESERVE_DECIMALS,
                BUY_MEAN_AMOUNT,
                MEAN_COOLDOWN,
                BOUNTY,
                JITTERY_BINOMIAL_BITS,
                TWAP_SHORT_TIME,
                TWAP_LONG_TIME,
                BUY_TREND_UP_FACTOR,
                BUY_TREND_DOWN_FACTOR  
            );
            (bytes memory bytecode, uint256[] memory constants) = PARSER.parse(
                LibTrendTrade.getTrendBuyOrder(
                    vm, 
                    buyOrderRainlang
                )
            );
            (,, buyExpression,) = EXPRESSION_DEPLOYER.deployExpression2(bytecode, constants);
        }
        {       
            uint256[][] memory buyOrderContext = getBuyOrderContext(uint256(keccak256("buyOrder"))); 
            (uint256[] memory buyStack,uint256[] memory buyKvs) = IInterpreterV2(INTERPRETER).eval2(
                IInterpreterStoreV2(address(STORE)),
                namespace,
                LibEncodedDispatch.encode2(buyExpression, SourceIndexV2.wrap(0), type(uint16).max),
                buyOrderContext,
                new uint256[](0)
            );
            STORE.set(
                StateNamespace.wrap(uint256(uint160(ORDER_OWNER))),
                buyKvs
            ); 
            vm.expectRevert(bytes("Trade cooldown."));
            IInterpreterV2(INTERPRETER).eval2(
                IInterpreterStoreV2(address(STORE)),
                namespace,
                LibEncodedDispatch.encode2(buyExpression, SourceIndexV2.wrap(0), type(uint16).max),
                buyOrderContext,
                new uint256[](0)
            );
            vm.warp(block.timestamp + MEAN_COOLDOWN + 1);
            IInterpreterV2(INTERPRETER).eval2(
                IInterpreterStoreV2(address(STORE)),
                namespace,
                LibEncodedDispatch.encode2(buyExpression, SourceIndexV2.wrap(0), type(uint16).max),
                buyOrderContext,
                new uint256[](0)
            );
        }

    } 

    function getSellOrderContext(uint256 orderHash) internal view returns (uint256[][] memory context) {
        // Sell Order Context
        context = new uint256[][](5);
        {
            {
                uint256[] memory baseContext = new uint256[](2);
                context[0] = baseContext;
            }
            {
                uint256[] memory callingContext = new uint256[](3);
                // order hash
                callingContext[0] = orderHash;
                context[1] = callingContext;
            }
            {
                uint256[] memory calculationsContext = new uint256[](2);
                context[2] = calculationsContext;
            }
            {
                uint256[] memory inputsContext = new uint256[](CONTEXT_VAULT_IO_ROWS);
                inputsContext[0] = uint256(uint160(RESERVE_ADDRESS));
                context[3] = inputsContext;
            }
            {
                uint256[] memory outputsContext = new uint256[](CONTEXT_VAULT_IO_ROWS);
                outputsContext[0] = uint256(uint160(TOKEN_ADDRESS));
                context[4] = outputsContext;
            }
        }
    }

    function getBuyOrderContext(uint256 orderHash) internal view returns (uint256[][] memory context) {
        // Sell Order Context
        context = new uint256[][](5);
        {
            {
                uint256[] memory baseContext = new uint256[](2);
                context[0] = baseContext;
            }
            {
                uint256[] memory callingContext = new uint256[](3);
                // order hash
                callingContext[0] = orderHash;
                context[1] = callingContext;
            }
            {
                uint256[] memory calculationsContext = new uint256[](2);
                context[2] = calculationsContext;
            }
            {
                uint256[] memory inputsContext = new uint256[](CONTEXT_VAULT_IO_ROWS);
                inputsContext[0] = uint256(uint160(TOKEN_ADDRESS));
                context[3] = inputsContext;
            }
            {
                uint256[] memory outputsContext = new uint256[](CONTEXT_VAULT_IO_ROWS);
                outputsContext[0] = uint256(uint160(RESERVE_ADDRESS));
                context[4] = outputsContext;
            }
        }
    }
    
}