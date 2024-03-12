// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.19;

import {Vm} from "forge-std/Vm.sol";
import {Test, console2} from "forge-std/Test.sol";
import {IParserV1} from "rain.interpreter.interface/interface/IParserV1.sol";
import {IInterpreterV2} from "rain.interpreter.interface/interface/IInterpreterV2.sol";
import {IInterpreterStoreV2} from "rain.interpreter.interface/interface/IInterpreterStoreV2.sol";
import {ISubParserV2} from "rain.interpreter.interface/interface/ISubParserV2.sol";
import {IExpressionDeployerV3} from "rain.interpreter.interface/interface/IExpressionDeployerV3.sol";
import {SafeERC20, IERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";
import "rain.math.fixedpoint/lib/LibFixedPointDecimalArithmeticOpenZeppelin.sol";
import "rain.math.fixedpoint/lib/LibFixedPointDecimalScale.sol";
import "rain.interpreter.interface/lib/caller/LibEncodedDispatch.sol";
import "rain.interpreter.interface/lib/ns/LibNamespace.sol";
import "src/lib/LibTrendTrade.sol";

// Strategy Params
address constant TOKEN_ADDRESS = address(0x692AC1e363ae34b6B489148152b12e2785a3d8d6);
address constant RESERVE_ADDRESS = address(0xc2132D05D31c914a87C6611C10748AEb04B58e8F);
// TRADE token holder.
address constant POLYGON_TRADE_HOLDER = 0xD6216fC19DB775Df9774a6E33526131dA7D19a2c;
// USDT token holder.
address constant POLYGON_USDT_HOLDER = 0xF977814e90dA44bFA03b6295A0616a897441aceC; 

uint256 constant TOKEN_DECIMALS = 18;
uint256 constant RESERVE_DECIMALS = 6;
uint256 constant MEAN_COOLDOWN = 1440;
uint256 constant BOUNTY = 8e16;
uint256 constant JITTERY_BINOMIAL_BITS = 20;
uint256 constant TWAP_SHORT_TIME = 1800;
uint256 constant TWAP_LONG_TIME = 14400;
uint256 constant TWAP_TREND_RATIO_FEE = 10000;

// Buy Order
uint256 constant BUY_MEAN_AMOUNT = 160e18;
uint256 constant BUY_TREND_UP_FACTOR = 3e18;
uint256 constant BUY_TREND_DOWN_FACTOR = 33e16;

// Sell Order
uint256 constant SELL_MEAN_AMOUNT = 150e18;
uint256 constant SELL_TREND_UP_FACTOR = 33e16;
uint256 constant SELL_TREND_DOWN_FACTOR = 3e18;

function getSushiV2TradeSellRoute(address toAddress)  pure returns (bytes memory){
    bytes memory ROUTE_PRELUDE = 
    hex"02692AC1e363ae34b6B489148152b12e2785a3d8d601ffff006777DBf38f67B448174412bAaF21F38e058b1f4B01";
    return abi.encode(bytes.concat(ROUTE_PRELUDE, abi.encodePacked(toAddress)));
}

function getSushiV2TradeBuyRoute(address toAddress)  pure returns (bytes memory){
    bytes memory ROUTE_PRELUDE = 
    hex"02c2132d05d31c914a87c6611c10748aeb04b58e8f01ffff006777DBf38f67B448174412bAaF21F38e058b1f4B00";
    return abi.encode(bytes.concat(ROUTE_PRELUDE, abi.encodePacked(toAddress)));
}

function getUniV3TradeBuyRoute(address toAddress)  pure returns (bytes memory){
    bytes memory ROUTE_PRELUDE = 
    hex"02c2132D05D31c914a87C6611C10748AEb04B58e8F01ffff01362D0401ED74Db25219b6D02Ac1791cFE3542D6800";
    return abi.encode(bytes.concat(ROUTE_PRELUDE, abi.encodePacked(toAddress)));
    
}

function getUniV3TradeSellRoute(address toAddress) pure returns (bytes memory){
    bytes memory ROUTE_PRELUDE =
    hex"02692AC1e363ae34b6B489148152b12e2785a3d8d601ffff01362D0401ED74Db25219b6D02Ac1791cFE3542D6801";
    return abi.encode(bytes.concat(ROUTE_PRELUDE, abi.encodePacked(toAddress)));
}

interface IRouteProcessor {
    function processRoute(
        address tokenIn,
        uint256 amountIn,
        address tokenOut,
        uint256 amountOutMin,
        address to,
        bytes memory route
    ) external payable returns (uint256 amountOut);
}

contract TrancheSpreadTest is Test {
    using Strings for address;
    using Strings for uint256;

    using LibFixedPointDecimalArithmeticOpenZeppelin for uint256;
    using LibFixedPointDecimalScale for uint256;

    using SafeERC20 for IERC20;

    uint256 constant FORK_BLOCK_NUMBER = 54523727;
    uint256 constant CONTEXT_VAULT_IO_ROWS = 5;
    address constant ORDER_OWNER = address(0x19f95a84aa1C48A2c6a7B2d5de164331c86D030C);

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
        lastTime = uint32(bound(lastTime, 0, type(uint32).max / uint32(2)));
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
                trendNumerator.fixedPointDiv(trendDenominator,Math.Rounding.Down),
                SELL_MEAN_AMOUNT,
                SELL_TREND_UP_FACTOR,
                SELL_TREND_DOWN_FACTOR,
                BOUNTY
            );
            sellOrderRainlang =
                LibTrendTrade.getTestTrendOrder(vm, sellTestTrend, address(ORDERBOOK_SUPARSER), address(UNISWAP_WORDS));

            LibTrendTrade.TrendTradeTest memory buyTestTrend = LibTrendTrade.TrendTradeTest(
                RESERVE_ADDRESS,
                RESERVE_DECIMALS,
                lastTime,
                testNow,
                JITTERY_BINOMIAL_BITS,
                MEAN_COOLDOWN,
                trendDenominator.fixedPointDiv(trendNumerator,Math.Rounding.Down),
                BUY_MEAN_AMOUNT,
                BUY_TREND_UP_FACTOR,
                BUY_TREND_DOWN_FACTOR,
                BOUNTY
            );
            buyOrderRainlang =
                LibTrendTrade.getTestTrendOrder(vm, buyTestTrend, address(ORDERBOOK_SUPARSER), address(UNISWAP_WORDS));
        }

        {
            {
                (bytes memory bytecode, uint256[] memory constants) = PARSER.parse(buyOrderRainlang);
                (,, buyExpression,) = EXPRESSION_DEPLOYER.deployExpression2(bytecode, constants);
            }
            {
                (bytes memory bytecode, uint256[] memory constants) = PARSER.parse(sellOrderRainlang);
                (,, sellExpression,) = EXPRESSION_DEPLOYER.deployExpression2(bytecode, constants);
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
            sellStack[4].toString(),
            ",",
            buyStack[4].toString(),
            ",",
            sellStack[6].toString()
        ));
    } 

    function testUniswapV3TwapSource() public {

        FullyQualifiedNamespace namespace =
                LibNamespace.qualifyNamespace(StateNamespace.wrap(uint256(uint160(ORDER_OWNER))), address(this)); 

        uint256[][] memory sellOrderContext = getSellOrderContext(uint256(keccak256(abi.encode("sell order")))); 

        address twapSourceExp;
        {   
                bytes memory twapSource = LibTrendTrade.getTwapTrendSource(
                        vm,
                        address(ORDERBOOK_SUPARSER),
                        address(UNISWAP_WORDS),
                        TWAP_LONG_TIME,
                        TWAP_SHORT_TIME,
                        TWAP_TREND_RATIO_FEE
            );
            (bytes memory bytecode, uint256[] memory constants) = PARSER.parse(twapSource);
            (,,twapSourceExp,) = EXPRESSION_DEPLOYER.deployExpression2(bytecode, constants);
        }
        {   
            uint256 sellTrend = 11e70;
            for(uint256 i = 0 ; i < 5; i++){            
                (uint256[] memory twapSourceStack,) = IInterpreterV2(INTERPRETER).eval2(
                    IInterpreterStoreV2(address(STORE)),
                    namespace,
                    LibEncodedDispatch.encode2(twapSourceExp, SourceIndexV2.wrap(0), type(uint16).max),
                    sellOrderContext,
                    new uint256[](0)
                );
                
                moveExternalPrice(
                    address(RESERVE_ADDRESS),
                    address(TOKEN_ADDRESS),
                    POLYGON_USDT_HOLDER,
                    100000e6,
                    getUniV3TradeBuyRoute(address(this))
                );
                vm.warp(block.timestamp + (MEAN_COOLDOWN*2) + 1);
                assertLe(twapSourceStack[0], sellTrend);
                sellTrend = twapSourceStack[0]; 
            }
        }
        {   
            uint256 sellTrend = 0;
            for(uint256 i = 0 ; i < 5; i++){            
                (uint256[] memory twapSourceStack,) = IInterpreterV2(INTERPRETER).eval2(
                    IInterpreterStoreV2(address(STORE)),
                    namespace,
                    LibEncodedDispatch.encode2(twapSourceExp, SourceIndexV2.wrap(0), type(uint16).max),
                    sellOrderContext,
                    new uint256[](0)
                );
                console2.log(twapSourceStack[0]);
                moveExternalPrice(
                    address(TOKEN_ADDRESS),
                    address(RESERVE_ADDRESS),
                    POLYGON_TRADE_HOLDER,
                    100000e18,
                    getUniV3TradeSellRoute(address(this))
                );
                vm.warp(block.timestamp + (MEAN_COOLDOWN*2) + 1);
                assertGe(twapSourceStack[0], sellTrend);
                sellTrend = twapSourceStack[0]; 
            }

        }
    } 

    function testCardanoCheck() public {

        address sellExpression;
        FullyQualifiedNamespace namespace =
            LibNamespace.qualifyNamespace(StateNamespace.wrap(uint256(uint160(ORDER_OWNER))), address(this));

        uint256[][] memory sellOrderContext = getSellOrderContext(uint256(keccak256(abi.encode("sell order"))));

        bytes memory sellOrderRainlang;
        {
            LibTrendTrade.TrendTrade memory sellTestTrend = LibTrendTrade.TrendTrade(
                RESERVE_ADDRESS,
                RESERVE_DECIMALS,
                JITTERY_BINOMIAL_BITS,
                MEAN_COOLDOWN,
                TWAP_LONG_TIME,
                TWAP_SHORT_TIME,
                TWAP_TREND_RATIO_FEE,
                SELL_MEAN_AMOUNT,
                SELL_TREND_UP_FACTOR,
                SELL_TREND_DOWN_FACTOR,
                BOUNTY
            );
            sellOrderRainlang =
                LibTrendTrade.getTrendOrder(vm, sellTestTrend, address(ORDERBOOK_SUPARSER), address(UNISWAP_WORDS)); 
        }
        {
            (bytes memory bytecode, uint256[] memory constants) = PARSER.parse(sellOrderRainlang);
            (,, sellExpression,) = EXPRESSION_DEPLOYER.deployExpression2(bytecode, constants);
        }
        //Move external market
        moveExternalPrice(
                    address(RESERVE_ADDRESS),
                    address(TOKEN_ADDRESS),
                    POLYGON_USDT_HOLDER,
                    100e6,
                    getSushiV2TradeBuyRoute(address(this))
        );
        // Revert if price change within same block.
        {   
            vm.expectRevert(bytes("Price change in same block."));
            IInterpreterV2(INTERPRETER).eval2(
                IInterpreterStoreV2(address(STORE)),
                namespace,
                LibEncodedDispatch.encode2(sellExpression, SourceIndexV2.wrap(0), type(uint16).max),
                sellOrderContext,
                new uint256[](0)
            ); 
        }
        // Evals when block time increase, i.e new block is mined.
        {   
            vm.warp(block.timestamp + 1);
            IInterpreterV2(INTERPRETER).eval2(
                IInterpreterStoreV2(address(STORE)),
                namespace,
                LibEncodedDispatch.encode2(sellExpression, SourceIndexV2.wrap(0), type(uint16).max),
                sellOrderContext,
                new uint256[](0)
            ); 
        }
        
    } 

    function testCooldown() public {

        FullyQualifiedNamespace namespace =
            LibNamespace.qualifyNamespace(StateNamespace.wrap(uint256(uint160(ORDER_OWNER))), address(this));

        address ensureCoolDown;
        {
            (bytes memory bytecode, uint256[] memory constants) = PARSER.parse(
                LibTrendTrade.getEnsureCooldownSource(
                    vm,
                    address(ORDERBOOK_SUPARSER),
                    address(UNISWAP_WORDS),
                    MEAN_COOLDOWN,
                    JITTERY_BINOMIAL_BITS
                )
            );
            (,, ensureCoolDown,) = EXPRESSION_DEPLOYER.deployExpression2(bytecode, constants);
        }
        // Immediately after cooldown is triggered.
        {
            uint256[] memory inputs = new uint256[](2);
            inputs[0] = block.timestamp; //now
            inputs[1] = block.timestamp; //last-time

            vm.expectRevert(bytes("Trade cooldown."));
            IInterpreterV2(INTERPRETER).eval2(
                IInterpreterStoreV2(address(STORE)),
                namespace,
                LibEncodedDispatch.encode2(ensureCoolDown, SourceIndexV2.wrap(0), type(uint16).max),
                new uint256[][](0),
                inputs
            );
        }
        // Less than the cooldown spread.
        {
            uint256[] memory inputs = new uint256[](2);
            inputs[0] = block.timestamp + (MEAN_COOLDOWN/2); //now
            inputs[1] = block.timestamp; //last-time

            vm.expectRevert(bytes("Trade cooldown."));
            IInterpreterV2(INTERPRETER).eval2(
                IInterpreterStoreV2(address(STORE)),
                namespace,
                LibEncodedDispatch.encode2(ensureCoolDown, SourceIndexV2.wrap(0), type(uint16).max),
                new uint256[][](0),
                inputs
            );
        }
        // Mean cooldown
        {
            uint256[] memory inputs = new uint256[](2);
            inputs[0] = block.timestamp + MEAN_COOLDOWN; //now
            inputs[1] = block.timestamp; //last-time

            IInterpreterV2(INTERPRETER).eval2(
                IInterpreterStoreV2(address(STORE)),
                namespace,
                LibEncodedDispatch.encode2(ensureCoolDown, SourceIndexV2.wrap(0), type(uint16).max),
                new uint256[][](0),
                inputs
            );
        }
        
    } 

    function testHandleIO(uint256 outputVaultBalanceDecrease, uint256 calculatedOutputMax) public {

        FullyQualifiedNamespace namespace =
            LibNamespace.qualifyNamespace(StateNamespace.wrap(uint256(uint160(ORDER_OWNER))), address(this));

        address handleIoExpression;
        {
            (bytes memory bytecode, uint256[] memory constants) = PARSER.parse(
                LibTrendTrade.getHandleIo(
                    vm,
                    address(ORDERBOOK_SUPARSER),
                    address(UNISWAP_WORDS)
                )
            );
            (,, handleIoExpression,) = EXPRESSION_DEPLOYER.deployExpression2(bytecode, constants);
        }
        // Sell Order
        {   
            uint256[][] memory sellOrderContext = getSellOrderContext(uint256(keccak256(abi.encode("sell order"))));
            sellOrderContext[4][4] = outputVaultBalanceDecrease;
            sellOrderContext[2][0] = calculatedOutputMax;

            if(outputVaultBalanceDecrease < calculatedOutputMax)
                vm.expectRevert(bytes("Partial trade."));

            IInterpreterV2(INTERPRETER).eval2(
                IInterpreterStoreV2(address(STORE)),
                namespace,
                LibEncodedDispatch.encode2(handleIoExpression, SourceIndexV2.wrap(0), type(uint16).max),
                sellOrderContext,
                new uint256[](0)
            );
        }
        // Buy Order
        {
            uint256[][] memory buyOrderContext = getBuyOrderContext(uint256(keccak256(abi.encode("buy order"))));
            buyOrderContext[4][4] = outputVaultBalanceDecrease;
            buyOrderContext[2][0] = calculatedOutputMax;

            if(outputVaultBalanceDecrease < calculatedOutputMax.scaleN(RESERVE_DECIMALS,0))
                vm.expectRevert(bytes("Partial trade."));

            IInterpreterV2(INTERPRETER).eval2(
                IInterpreterStoreV2(address(STORE)),
                namespace,
                LibEncodedDispatch.encode2(handleIoExpression, SourceIndexV2.wrap(0), type(uint16).max),
                buyOrderContext,
                new uint256[](0)
            );
        }
    }

    function moveExternalPrice(
        address inputToken,
        address outputToken,
        address tokenHolder,
        uint256 amountIn,
        bytes memory encodedRoute
    ) public {
        //Router processor
        IRouteProcessor ROUTE_PROCESSOR = IRouteProcessor(0xE7eb31f23A5BefEEFf76dbD2ED6AdC822568a5d2);
        // An External Account
        address EXTERNAL_EOA = address(0x654FEf5Fb8A1C91ad47Ba192F7AA81dd3C821427);
        {
            giveTestAccountsTokens(IERC20(inputToken), tokenHolder, EXTERNAL_EOA, amountIn);
        }
        vm.startPrank(EXTERNAL_EOA);

        IERC20(inputToken).approve(address(ROUTE_PROCESSOR), amountIn);

        bytes memory decodedRoute = abi.decode(encodedRoute, (bytes));

        ROUTE_PROCESSOR.processRoute(inputToken, amountIn, outputToken, 0, EXTERNAL_EOA, decodedRoute);
        vm.stopPrank();
    }

    function getSellOrderContext(uint256 orderHash) internal pure returns (uint256[][] memory context) {
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

    function getBuyOrderContext(uint256 orderHash) internal pure returns (uint256[][] memory context) {
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

    function giveTestAccountsTokens(IERC20 token, address from, address to, uint256 amount) internal {
        vm.startPrank(from);
        token.safeTransfer(to, amount);
        vm.stopPrank();
    }
    
}
