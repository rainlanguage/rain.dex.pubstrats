// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.19;

import {Vm} from "forge-std/Vm.sol";
import {Test, console2} from "forge-std/Test.sol";
import {IParserV1} from "rain.interpreter.interface/interface/IParserV1.sol";
import {IInterpreterV2} from "rain.interpreter.interface/interface/IInterpreterV2.sol";
import {IInterpreterStoreV2} from "rain.interpreter.interface/interface/IInterpreterStoreV2.sol";
import {ISubParserV2} from "rain.interpreter.interface/interface/ISubParserV2.sol";
import {IExpressionDeployerV3} from "rain.interpreter.interface/interface/IExpressionDeployerV3.sol";
import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";
import "rain.math.fixedpoint/lib/LibFixedPointDecimalArithmeticOpenZeppelin.sol";
import "rain.math.fixedpoint/lib/LibFixedPointDecimalScale.sol";
import "rain.interpreter.interface/lib/caller/LibEncodedDispatch.sol";
import "rain.interpreter.interface/lib/ns/LibNamespace.sol";
import "src/lib/LibTrendTrade.sol";



contract TrancheSpreadTest is Test {
    using Strings for address;
    using Strings for uint256;

    using LibFixedPointDecimalArithmeticOpenZeppelin for uint256;
    using LibFixedPointDecimalScale for uint256;

    uint256 constant FORK_BLOCK_NUMBER = 54523727;
    uint256 constant CONTEXT_VAULT_IO_ROWS = 5;
    address constant ORDER_OWNER = address(0x19f95a84aa1C48A2c6a7B2d5de164331c86D030C);

    // Strategy Params
    address constant TOKEN_ADDRESS = address(0x692AC1e363ae34b6B489148152b12e2785a3d8d6);
    address constant RESERVE_ADDRESS = address(0xc2132D05D31c914a87C6611C10748AEb04B58e8F);
    uint256 constant TOKEN_DECIMALS = 18;
    uint256 constant RESERVE_DECIMALS = 6;
    uint256 constant MEAN_COOLDOWN = 1440;
    uint256 constant BOUNTY = 1e16;
    uint256 constant JITTERY_BINOMIAL_BITS = 10;
    uint256 constant TWAP_SHORT_TIME = 1800;
    uint256 constant TWAP_LONG_TIME = 14400;
    uint256 constant TWAP_TREND_RATIO_FEE = 500;

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

        PARSER = IParserV1(0x42354C16c8FcFf044c5ee73798F250138ef0A813);
        STORE = IInterpreterStoreV2(0x9Ba76481F8cF7F52e440B13981e0003De474A9f7);
        INTERPRETER = IInterpreterV2(0xbbe5a04A9a20c47b1A93e755aE712cb84538cd5a);
        EXPRESSION_DEPLOYER = IExpressionDeployerV3(0xc64B01aB4b5549dE91e5A4425883Dff87Ceaaf29);
        ORDERBOOK_SUPARSER = ISubParserV2(0x14c5D39dE54D498aFD3C803D3B5c88bbEcadcc48);
        UNISWAP_WORDS = ISubParserV2(0x42758Ca92093f6dc94afD33c03C79D9c5221d933);
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

        uint256[][] memory sellOrderContext = getSellOrderContext(uint256(keccak256(abi.encode("sell order"))));
        uint256[][] memory buyOrderContext = getBuyOrderContext(uint256(keccak256(abi.encode("buy order"))));


        bytes memory sellOrderRainlang;
        bytes memory buyOrderRainlang;

        {
            LibTrendTrade.TrendTradeTest memory sellTestTrend = LibTrendTrade.TrendTradeTest(
                RESERVE_ADDRESS,
                RESERVE_DECIMALS,
                lastTime,
                testNow,
                JITTERY_BINOMIAL_BITS,
                MEAN_COOLDOWN,
                TWAP_SHORT_TIME,
                TWAP_LONG_TIME,
                TWAP_TREND_RATIO_FEE,
                SELL_MEAN_AMOUNT,
                SELL_TREND_UP_FACTOR,
                SELL_TREND_DOWN_FACTOR,
                BOUNTY
            );
            sellOrderRainlang = LibTrendTrade.getTestTrendOrder(
                    vm, 
                    sellTestTrend,
                    address(ORDERBOOK_SUPARSER),
                    address(UNISWAP_WORDS)
            );
            LibTrendTrade.TrendTradeTest memory buyTestTrend = LibTrendTrade.TrendTradeTest(
                RESERVE_ADDRESS,
                RESERVE_DECIMALS,
                lastTime,
                testNow,
                JITTERY_BINOMIAL_BITS,
                MEAN_COOLDOWN,
                TWAP_SHORT_TIME,
                TWAP_LONG_TIME,
                TWAP_TREND_RATIO_FEE,
                BUY_MEAN_AMOUNT,
                BUY_TREND_UP_FACTOR,
                BUY_TREND_DOWN_FACTOR,
                BOUNTY
            );
            buyOrderRainlang = LibTrendTrade.getTestTrendOrder(
                    vm, 
                    buyTestTrend,
                    address(ORDERBOOK_SUPARSER),
                    address(UNISWAP_WORDS)
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

        (uint256[] memory buyStack,) = IInterpreterV2(INTERPRETER).eval2(
            IInterpreterStoreV2(address(STORE)),
            namespace,
            LibEncodedDispatch.encode2(buyExpression, SourceIndexV2.wrap(0), type(uint16).max),
            buyOrderContext,
            new uint256[](0)
        );

        (uint256[] memory sellStack,) = IInterpreterV2(INTERPRETER).eval2(
            IInterpreterStoreV2(address(STORE)),
            namespace,
            LibEncodedDispatch.encode2(sellExpression, SourceIndexV2.wrap(0), type(uint16).max),
            sellOrderContext,
            new uint256[](0)
        ); 
        
        string memory file = string.concat("./test/csvs/trend-trader", ".csv");

        vm.writeLine(file, string.concat(
            sellStack[0].toString(),
            ",",
            buyStack[0].toString(),
            ",",
            sellStack[6].toString()
        ));
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
                inputsContext[1] = RESERVE_DECIMALS;
                context[3] = inputsContext;
            }
            {
                uint256[] memory outputsContext = new uint256[](CONTEXT_VAULT_IO_ROWS);
                outputsContext[0] = uint256(uint160(TOKEN_ADDRESS));
                outputsContext[1] = TOKEN_DECIMALS;
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
                inputsContext[1] = TOKEN_DECIMALS;
                context[3] = inputsContext;
            }
            {
                uint256[] memory outputsContext = new uint256[](CONTEXT_VAULT_IO_ROWS);
                outputsContext[0] = uint256(uint160(RESERVE_ADDRESS));
                outputsContext[1] = RESERVE_DECIMALS;
                context[4] = outputsContext;
            }
        }
    }
    
}