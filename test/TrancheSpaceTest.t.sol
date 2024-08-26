// SPDX-License-Identifier: CAL
pragma solidity =0.8.25;
import {console2, Test} from "forge-std/Test.sol";

import {
    IOrderBookV3,
    IO
} from "rain.orderbook.interface/interface/deprecated/v3/IOrderBookV3.sol";
import {
    IOrderBookV4,
    OrderV3,
    OrderConfigV3,
    TakeOrderConfigV3,
    TakeOrdersConfigV3,
    TaskV1,
    EvaluableV3,
    SignedContextV1
} from "rain.orderbook.interface/interface/IOrderBookV4.sol";
import {IParserV2} from "rain.interpreter.interface/interface/IParserV2.sol";
import {IOrderBookV4ArbOrderTakerV2} from "rain.orderbook.interface/interface/unstable/IOrderBookV4ArbOrderTakerV2.sol";
import {IExpressionDeployerV3} from "rain.interpreter.interface/interface/deprecated/IExpressionDeployerV3.sol";
import {IInterpreterV3} from "rain.interpreter.interface/interface/IInterpreterV3.sol";
import {IInterpreterStoreV2} from "rain.interpreter.interface/interface/IInterpreterStoreV2.sol";
import {StrategyTests, IRouteProcessor, LibStrategyDeployment, LibComposeOrders,IInterpreterV3,FullyQualifiedNamespace,LibNamespace,StateNamespace} from "h20.test-std/StrategyTests.sol";
import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";
import {SafeERC20, IERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "h20.test-std/lib/LibProcessStream.sol"; 

contract TrancheSpaceTest is StrategyTests {
    using Strings for address;
    using Strings for uint256;

    uint256 constant FORK_BLOCK_NUMBER = 28712894;

    function selectFlareFork() internal {
        uint256 fork = vm.createFork(vm.envString("RPC_URL_FLARE"));
        vm.selectFork(fork);
        vm.rollFork(FORK_BLOCK_NUMBER);
    }

    function setUp() public {
        selectFlareFork();
        
        iArbInstance = IOrderBookV4ArbOrderTakerV2(0xd752E60110C72e39637029665bee4Ae081FE1799);
        iRouteProcessor = IRouteProcessor(address(0x839453563dbdbcfb5D34e99061308c38Fa1321Ed)); 
        EXTERNAL_EOA = address(0x654FEf5Fb8A1C91ad47Ba192F7AA81dd3C821427);
        APPROVED_EOA = address(0x669845c29D9B1A64FFF66a55aA13EB4adB889a88);
        ORDER_OWNER = address(0x19f95a84aa1C48A2c6a7B2d5de164331c86D030C);

        bytes memory orderBook = LibComposeOrders.getOrderOrderBook(
            vm,
            "src/tranche/tranche-space.rain",
            "src/settings.yml",
            "flare-buy",
            "./lib/h20.test-std/lib/rain.orderbook",
            "./lib/h20.test-std/lib/rain.orderbook/Cargo.toml"
        );
        iOrderBook = IOrderBookV4(address(uint160(bytes20(orderBook))));
    }

    function testSuccessiveInitTranches() public {

        LibStrategyDeployment.StrategyDeploymentV4 memory strategy = LibStrategyDeployment.StrategyDeploymentV4(
            "",
            "",
            0,
            0,
            10e18,
            10e18,
            0,
            0,
            "src/tranche/tranche-space.rain",
            "src/settings.yml",
            "",
            "flare-sell",
            "./lib/h20.test-std/lib/rain.orderbook",
            "./lib/h20.test-std/lib/rain.orderbook/Cargo.toml"
        );

        OrderV3 memory order = addOrderDepositOutputTokens(strategy);


        // Tranche 0
        {
            vm.recordLogs();
            takeExternalOrder(order, strategy.inputTokenIndex, strategy.outputTokenIndex, new SignedContextV1[](0));

            Vm.Log[] memory entries = vm.getRecordedLogs();
            (uint256 strategyAmount, uint256 strategyRatio) = getCalculationContext(entries);

            uint256 expectedTrancheAmount = 102009999999999997;
            uint256 expectedTrancheRatio = 10e18;

            assertEq(strategyAmount, expectedTrancheAmount);
            assertEq(strategyRatio, expectedTrancheRatio);
        }

        // Tranche 1
        {
            vm.recordLogs();
            takeExternalOrder(order, strategy.inputTokenIndex, strategy.outputTokenIndex, new SignedContextV1[](0));

            Vm.Log[] memory entries = vm.getRecordedLogs();
            (uint256 strategyAmount, uint256 strategyRatio) = getCalculationContext(entries);

            uint256 expectedTrancheAmount = 98123904761904758;
            uint256 expectedTrancheRatio = 10.5e18;

            assertEq(strategyAmount, expectedTrancheAmount);
            assertEq(strategyRatio, expectedTrancheRatio);
        }

        // Tranche 2
        {
            vm.recordLogs();
            takeExternalOrder(order, strategy.inputTokenIndex, strategy.outputTokenIndex, new SignedContextV1[](0));

            Vm.Log[] memory entries = vm.getRecordedLogs();
            (uint256 strategyAmount, uint256 strategyRatio) = getCalculationContext(entries);

            uint256 expectedTrancheAmount = 94600364545454541;
            uint256 expectedTrancheRatio = 11e18;

            assertEq(strategyAmount, expectedTrancheAmount);
            assertEq(strategyRatio, expectedTrancheRatio);
        }
    }

    function testTrancheSpaceShynessExternalFlare() public {

        uint256 expectedRatio = 1e18;
        uint256 expectedAmountOutputMax = 1e18;

        LibStrategyDeployment.StrategyDeploymentV4 memory strategy = LibStrategyDeployment.StrategyDeploymentV4(
            "",
            "",
            0,
            0,
            0,
            10e18,
            expectedRatio,
            expectedAmountOutputMax,
            "src/tranche/tranche-space.rain",
            "src/settings.yml",
            "",
            "flare-test-shyness",
            "./lib/h20.test-std/lib/rain.orderbook",
            "./lib/h20.test-std/lib/rain.orderbook/Cargo.toml"
        );

        OrderV3 memory orderMinimumTrade = addOrderDepositOutputTokens(strategy);

        //Tranche 0- Full Tranche
        {
            vm.recordLogs();
            takeExternalOrder(orderMinimumTrade, strategy.inputTokenIndex, strategy.outputTokenIndex, new SignedContextV1[](0));

            Vm.Log[] memory entries = vm.getRecordedLogs();
            (uint256 strategyAmount, uint256 strategyRatio) = getCalculationContext(entries);

            // 1 * (1 + 0.01) ^ 0 = 1
            uint256 expectedTrancheAmount = 1e18;

            // 1 + (0.05 * 0) = 1
            uint256 expectedTrancheRatio = 1e18;

            assertEq(strategyAmount, expectedTrancheAmount);
            assertEq(strategyRatio, expectedTrancheRatio);

        }

        // Tranche 1 - Shy Tranche
        {
            vm.recordLogs();
            takeExternalOrder(orderMinimumTrade, strategy.inputTokenIndex, strategy.outputTokenIndex, new SignedContextV1[](0));

            Vm.Log[] memory entries = vm.getRecordedLogs();
            (uint256 strategyAmount, uint256 strategyRatio) = getCalculationContext(entries);

            // 1 * (1 + 0.01) ^ 1 = 1.01
            uint256 expectedTrancheAmount = 1.01e18;

            // 10% of the expectedTrancheAmount
            uint256 expectedShyTrancheAmount = expectedTrancheAmount / 10;

            // 1 + (0.05 * 1) = 1.05
            uint256 expectedTrancheRatio = 1.05e18;

            assertEq(strategyAmount, expectedShyTrancheAmount);
            assertEq(strategyRatio, expectedTrancheRatio);
        }
    }

    function testSuccessiveTranchesFlare() public {

        uint256 expectedRatio = 1e18;
        uint256 expectedAmountOutputMax = 1e18;

        LibStrategyDeployment.StrategyDeploymentV4 memory strategy = LibStrategyDeployment.StrategyDeploymentV4(
            "",
            "",
            0,
            0,
            0,
            10e18,
            expectedRatio,
            expectedAmountOutputMax,
            "src/tranche/tranche-space.rain",
            "src/settings.yml",
            "",
            "flare-buy",
            "./lib/h20.test-std/lib/rain.orderbook",
            "./lib/h20.test-std/lib/rain.orderbook/Cargo.toml"
        );

        OrderV3 memory orderMinimumTrade = addOrderDepositOutputTokens(strategy);

        // Asserting for tranche ratios and amounts

        // base = 1
        // tranche-amount-rate = 0.01
        // tranche-ratio-rate = 0.05
        // Expected Amount = base * (1 + tranche-amount-rate) ^ t
        // Expected Ratio = base + (tranche-ratio-rate * t)

        // Tranche 0
        {
            vm.recordLogs();
            takeExternalOrder(orderMinimumTrade, strategy.inputTokenIndex, strategy.outputTokenIndex, new SignedContextV1[](0));

            Vm.Log[] memory entries = vm.getRecordedLogs();
            (uint256 strategyAmount, uint256 strategyRatio) = getCalculationContext(entries);

            // 1 * (1 + 0.01) ^ 0 = 1
            uint256 expectedTrancheAmount = 1e18;

            // 1 + (0.05 * 0) = 1
            uint256 expectedTrancheRatio = 1e18;

            assertEq(strategyAmount, expectedTrancheAmount);
            assertEq(strategyRatio, expectedTrancheRatio);

        }

        // Tranche 1
        {
            vm.recordLogs();
            takeExternalOrder(orderMinimumTrade, strategy.inputTokenIndex, strategy.outputTokenIndex, new SignedContextV1[](0));

            Vm.Log[] memory entries = vm.getRecordedLogs();
            (uint256 strategyAmount, uint256 strategyRatio) = getCalculationContext(entries);

            // 1 * (1 + 0.01) ^ 1 = 1.01
            uint256 expectedTrancheAmount = 1.01e18;

            // 1 + (0.05 * 1) = 1.05
            uint256 expectedTrancheRatio = 1.05e18;

            assertEq(strategyAmount, expectedTrancheAmount);
            assertEq(strategyRatio, expectedTrancheRatio);
        }

        // Tranche 2
        {
            vm.recordLogs();
            takeExternalOrder(orderMinimumTrade, strategy.inputTokenIndex, strategy.outputTokenIndex, new SignedContextV1[](0));

            Vm.Log[] memory entries = vm.getRecordedLogs();
            (uint256 strategyAmount, uint256 strategyRatio) = getCalculationContext(entries);

            // 1 * (1 + 0.01) ^ 2 = 1.0201
            uint256 expectedTrancheAmount = 1.02e18 + 0.000099999999999978e18;

            // 1 + (0.05 * 2) = 1.1
            uint256 expectedTrancheRatio = 1.1e18;

            assertEq(strategyAmount, expectedTrancheAmount);
            assertEq(strategyRatio, expectedTrancheRatio);

        }

    }

    function testTrancheSpaceOrderMinimumRevertFlare() public {
    
        uint256 expectedRatio = 1e18;
        uint256 expectedAmountOutputMax = 1e18;

        // Minimum Revert Amount = expectedAmountOutputMax * 10% = 1e17
        uint256 minimumRevertAmount = 1e17;

        LibStrategyDeployment.StrategyDeploymentV4 memory strategy = LibStrategyDeployment.StrategyDeploymentV4(
            getEncodedRedToBlueRoute(),
            getEncodedBlueToRedRoute(),
            0,
            0,
            10e18,
            minimumRevertAmount,
            expectedRatio,
            expectedAmountOutputMax,
            "src/tranche/tranche-space.rain",
            "src/settings.yml",
            "",
            "flare-buy",
            "./lib/h20.test-std/lib/rain.orderbook",
            "./lib/h20.test-std/lib/rain.orderbook/Cargo.toml"
        );

        // Order succeeds with minumum trade size
        {
            OrderV3 memory orderMinimumTrade = addOrderDepositOutputTokens(strategy);

            moveExternalPrice(
                orderMinimumTrade.validInputs[strategy.inputTokenIndex].token,
                orderMinimumTrade.validOutputs[strategy.outputTokenIndex].token,
                strategy.makerAmount,
                strategy.makerRoute
            );

            takeArbOrder(orderMinimumTrade,strategy.takerRoute, strategy.inputTokenIndex, strategy.outputTokenIndex, new SignedContextV1[](0));
        }

        // Order fails with less than minimum trade size
        {
            strategy.takerAmount = minimumRevertAmount - 1;
            OrderV3 memory orderMinimumTrade = addOrderDepositOutputTokens(strategy);

            moveExternalPrice(
                orderMinimumTrade.validInputs[strategy.inputTokenIndex].token,
                orderMinimumTrade.validOutputs[strategy.outputTokenIndex].token,
                strategy.makerAmount,
                strategy.makerRoute
            );

            vm.expectRevert(bytes("Minimum trade size not met."));
            takeArbOrder(orderMinimumTrade, strategy.takerRoute, strategy.inputTokenIndex, strategy.outputTokenIndex, new SignedContextV1[](0));
        }
    } 

    function testTrancheSpaceOrderExternalFlare() public {

        uint256 expectedRatio = 1e18;
        uint256 expectedAmountOutputMax = 1e18;

        LibStrategyDeployment.StrategyDeploymentV4 memory strategy = LibStrategyDeployment.StrategyDeploymentV4(
            "",
            "",
            0,
            0,
            5e17,
            2e18,
            expectedRatio,
            expectedAmountOutputMax,
            "src/tranche/tranche-space.rain",
            "src/settings.yml",
            "",
            "flare-buy",
            "./lib/h20.test-std/lib/rain.orderbook",
            "./lib/h20.test-std/lib/rain.orderbook/Cargo.toml"
        );

        // OrderBook 'takeOrder'
        checkStrategyCalculations(strategy);
    }

    function testTrancheSpaceOrderArbFlare() public {

        uint256 expectedRatio = 1e18;
        uint256 expectedAmountOutputMax = 1e18;

        LibStrategyDeployment.StrategyDeploymentV4 memory strategy = LibStrategyDeployment.StrategyDeploymentV4(
            getEncodedRedToBlueRoute(),
            getEncodedBlueToRedRoute(),
            0,
            0,
            10e18,
            1e18,
            expectedRatio,
            expectedAmountOutputMax,
            "src/tranche/tranche-space.rain",
            "src/settings.yml",
            "",
            "flare-buy",
            "./lib/h20.test-std/lib/rain.orderbook",
            "./lib/h20.test-std/lib/rain.orderbook/Cargo.toml"
        );

        // OrderBook 'takeOrder'
        checkStrategyCalculationsArbOrder(strategy);

    }
    

    function getEncodedRedToBlueRoute() internal pure returns (bytes memory) {
        bytes memory RED_TO_BLUE_ROUTE =
            hex"02"
            hex"E38D92733203E6f93C634304b777490e67Dc4Bdf"
            hex"01"
            hex"ffff"
            hex"00"
            hex"03585a45Af10963838e435601487516F97B18aF7"
            hex"00"
            hex"d752E60110C72e39637029665bee4Ae081FE1799"
            hex"000bb8";

        return abi.encode(RED_TO_BLUE_ROUTE);
    }

    function getEncodedBlueToRedRoute() internal pure returns (bytes memory) {
        bytes memory BLUE_TO_RED_ROUTE =
            hex"02"
            hex"40D44abeC30288BFcd400200BA65FBD05daA5321"
            hex"01"
            hex"ffff"
            hex"00"
            hex"03585a45Af10963838e435601487516F97B18aF7"
            hex"01"
            hex"d752E60110C72e39637029665bee4Ae081FE1799"
            hex"000bb8";

        return abi.encode(BLUE_TO_RED_ROUTE);
    }
}