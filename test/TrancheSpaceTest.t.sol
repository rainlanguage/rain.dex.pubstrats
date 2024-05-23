// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.19;

import {Vm} from "forge-std/Vm.sol";
import {Test, console2} from "forge-std/Test.sol";
import {
    IOrderBookV3,
    IO,
    OrderV2,
    OrderConfigV2,
    TakeOrderConfigV2,
    TakeOrdersConfigV2
} from "rain.orderbook.interface/interface/IOrderBookV3.sol";
import {IParserV1} from "rain.interpreter.interface/interface/IParserV1.sol";
import {IOrderBookV3ArbOrderTaker} from "rain.orderbook.interface/interface/IOrderBookV3ArbOrderTaker.sol";
import {IInterpreterV2, SourceIndexV2} from "rain.interpreter.interface/interface/IInterpreterV2.sol";
import {IInterpreterStoreV2} from "rain.interpreter.interface/interface/IInterpreterStoreV2.sol";
import {ISubParserV2} from "rain.interpreter.interface/interface/ISubParserV2.sol";
import {IExpressionDeployerV3} from "rain.interpreter.interface/interface/IExpressionDeployerV3.sol";
import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {StrategyTests, IRouteProcessor, LibStrategyDeployment} from "h20.test-std/StrategyTests.sol";
import "rain.math.saturating/SaturatingMath.sol";
import "src/lib/LibTrancheSpaceOrders.sol";
import "rain.math.fixedpoint/lib/LibFixedPointDecimalArithmeticOpenZeppelin.sol";
import "rain.math.fixedpoint/lib/LibFixedPointDecimalScale.sol";
import "rain.interpreter.interface/lib/caller/LibEncodedDispatch.sol";
import "rain.interpreter.interface/lib/ns/LibNamespace.sol";

contract TrancheSpaceTest is StrategyTests {
    using Strings for address;
    using Strings for uint256;

    using LibFixedPointDecimalArithmeticOpenZeppelin for uint256;
    using LibFixedPointDecimalScale for uint256;

    uint256 constant FORK_BLOCK_NUMBER = 201303042;
    uint256 constant VAULT_ID = uint256(keccak256("vault"));

    IERC20 constant RED_TOKEN = IERC20(0x6d3AbB80c3CBAe0f60ba274F36137298D8571Fbe);
    IERC20 constant BLUE_TOKEN = IERC20(0x667f41fF7D9c06D2dd18511b32041fC6570Dc468);

    function selectPolygonFork() internal {
        uint256 fork = vm.createFork(vm.envString("RPC_URL_ARBITRUM"));
        vm.selectFork(fork);
        vm.rollFork(FORK_BLOCK_NUMBER);
    }

    function setUp() public {
        selectPolygonFork();

        PARSER = IParserV1(0x22410e2a46261a1B1e3899a072f303022801C764);
        ORDERBOOK = IOrderBookV3(0x90CAF23eA7E507BB722647B0674e50D8d6468234);
        ARB_INSTANCE = IOrderBookV3ArbOrderTaker(0xf382cbF44901cD26D14B247F4EA7260ee8041157);
        EXPRESSION_DEPLOYER = IExpressionDeployerV3(0x2AeE87D75CD000583DAEC7A28db103B1c0c18b76);
        ROUTE_PROCESSOR = IRouteProcessor(address(0x09bD2A33c47746fF03b86BCe4E885D03C74a8E8C));
        EXTERNAL_EOA = address(0x654FEf5Fb8A1C91ad47Ba192F7AA81dd3C821427);
        APPROVED_EOA = address(0x669845c29D9B1A64FFF66a55aA13EB4adB889a88);
        ORDER_OWNER = address(0x19f95a84aa1C48A2c6a7B2d5de164331c86D030C);
    }

    function arbRedIo() internal pure returns (IO memory) {
        return IO(address(RED_TOKEN), 18, VAULT_ID);
    }

    function arbBlueIo() internal pure returns (IO memory) {
        return IO(address(BLUE_TOKEN), 18, VAULT_ID);
    }

    function testTrancheSpaceShyness() public {

        // Input vaults
        IO[] memory inputVaults = new IO[](1);
        inputVaults[0] = arbRedIo();

        // Output vaults
        IO[] memory outputVaults = new IO[](1);
        outputVaults[0] = arbBlueIo();

        uint256 expectedRatio = 1e18;
        uint256 expectedAmountOutputMax = 1e18;

        LibStrategyDeployment.StrategyDeployment memory strategy = LibStrategyDeployment.StrategyDeployment(
            "",
            "",
            0,
            0,
            0,
            10e18,
            expectedRatio,
            expectedAmountOutputMax,
            "src/tranche/tranche-space.rain",
            "arb-red-blue-tranches.buy.initialized.test-shy-tranche",
            "./lib/h20.test-std/lib/rain.orderbook",
            "./lib/h20.test-std/lib/rain.orderbook/Cargo.toml",
            inputVaults,
            outputVaults
        );

        OrderV2 memory orderMinimumTrade = addOrderDepositOutputTokens(strategy);

        //Tranche 0- Full Tranche
        {
            vm.recordLogs();
            takeExternalOrder(orderMinimumTrade, strategy.inputTokenIndex, strategy.outputTokenIndex);

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
            takeExternalOrder(orderMinimumTrade, strategy.inputTokenIndex, strategy.outputTokenIndex);

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

    function testSuccessiveTranches() public {

        // Input vaults
        IO[] memory inputVaults = new IO[](1);
        inputVaults[0] = arbRedIo();

        // Output vaults
        IO[] memory outputVaults = new IO[](1);
        outputVaults[0] = arbBlueIo();

        uint256 expectedRatio = 1e18;
        uint256 expectedAmountOutputMax = 1e18;

        LibStrategyDeployment.StrategyDeployment memory strategy = LibStrategyDeployment.StrategyDeployment(
            "",
            "",
            0,
            0,
            0,
            10e18,
            expectedRatio,
            expectedAmountOutputMax,
            "src/tranche/tranche-space.rain",
            "arb-red-blue-tranches.buy.initialized.prod",
            "./lib/h20.test-std/lib/rain.orderbook",
            "./lib/h20.test-std/lib/rain.orderbook/Cargo.toml",
            inputVaults,
            outputVaults
        );

        OrderV2 memory orderMinimumTrade = addOrderDepositOutputTokens(strategy);

        // Asserting for tranche ratios and amounts

        // base = 1
        // tranche-amount-rate = 0.01
        // tranche-ratio-rate = 0.05
        // Expected Amount = base * (1 + tranche-amount-rate) ^ t
        // Expected Ratio = base + (tranche-ratio-rate * t)

        // Tranche 0
        {
            vm.recordLogs();
            takeExternalOrder(orderMinimumTrade, strategy.inputTokenIndex, strategy.outputTokenIndex);

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
            takeExternalOrder(orderMinimumTrade, strategy.inputTokenIndex, strategy.outputTokenIndex);

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
            takeExternalOrder(orderMinimumTrade, strategy.inputTokenIndex, strategy.outputTokenIndex);

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

    function testTrancheSpaceOrderMinimumRevert() public {
        // Input vaults
        IO[] memory inputVaults = new IO[](1);
        inputVaults[0] = arbRedIo();

        // Output vaults
        IO[] memory outputVaults = new IO[](1);
        outputVaults[0] = arbBlueIo();

        uint256 expectedRatio = 1e18;
        uint256 expectedAmountOutputMax = 1e18;

        // Minimum Revert Amount = expectedAmountOutputMax * 10% = 1e17
        uint256 minimumRevertAmount = 1e17;

        LibStrategyDeployment.StrategyDeployment memory strategy = LibStrategyDeployment.StrategyDeployment(
            getEncodedRedToBlueRoute(address(ARB_INSTANCE)),
            getEncodedBlueToRedRoute(address(ARB_INSTANCE)),
            0,
            0,
            1e18,
            minimumRevertAmount,
            expectedRatio,
            expectedAmountOutputMax,
            "src/tranche/tranche-space.rain",
            "arb-red-blue-tranches.buy.initialized.prod",
            "./lib/h20.test-std/lib/rain.orderbook",
            "./lib/h20.test-std/lib/rain.orderbook/Cargo.toml",
            inputVaults,
            outputVaults
        );

        // Order succeeds with minumum trade size
        {
            OrderV2 memory orderMinimumTrade = addOrderDepositOutputTokens(strategy);

            moveExternalPrice(
                strategy.inputVaults[strategy.inputTokenIndex].token,
                strategy.outputVaults[strategy.outputTokenIndex].token,
                strategy.makerAmount,
                strategy.makerRoute
            );

            takeArbOrder(orderMinimumTrade,strategy.takerRoute, strategy.inputTokenIndex, strategy.outputTokenIndex);
        }

        // Order fails with less than minimum trade size
        {
            strategy.takerAmount = minimumRevertAmount - 1;
            OrderV2 memory orderMinimumTradeRevert = addOrderDepositOutputTokens(strategy);

            moveExternalPrice(
                strategy.inputVaults[strategy.inputTokenIndex].token,
                strategy.outputVaults[strategy.outputTokenIndex].token,
                strategy.makerAmount,
                strategy.makerRoute
            );

            vm.expectRevert(bytes("Minimum trade size not met."));
            takeArbOrder(orderMinimumTradeRevert,strategy.takerRoute, strategy.inputTokenIndex, strategy.outputTokenIndex);
        }
    }

    function testTrancheSpaceOrderExternal() public {
        // Input vaults
        IO[] memory inputVaults = new IO[](1);
        inputVaults[0] = arbRedIo();

        // Output vaults
        IO[] memory outputVaults = new IO[](1);
        outputVaults[0] = arbBlueIo();

        uint256 expectedRatio = 1e18;
        uint256 expectedAmountOutputMax = 1e18;

        LibStrategyDeployment.StrategyDeployment memory strategy = LibStrategyDeployment.StrategyDeployment(
            "",
            "",
            0,
            0,
            5e17,
            2e18,
            expectedRatio,
            expectedAmountOutputMax,
            "src/tranche/tranche-space.rain",
            "arb-red-blue-tranches.buy.initialized.prod",
            "./lib/h20.test-std/lib/rain.orderbook",
            "./lib/h20.test-std/lib/rain.orderbook/Cargo.toml",
            inputVaults,
            outputVaults
        );

        // OrderBook 'takeOrder'
        checkStrategyCalculations(strategy);

    }

    function testTrancheSpaceOrderArb() public {
        // Input vaults
        IO[] memory inputVaults = new IO[](1);
        inputVaults[0] = arbRedIo();

        // Output vaults
        IO[] memory outputVaults = new IO[](1);
        outputVaults[0] = arbBlueIo();

        uint256 expectedRatio = 1e18;
        uint256 expectedAmountOutputMax = 1e18;

        LibStrategyDeployment.StrategyDeployment memory strategy = LibStrategyDeployment.StrategyDeployment(
            getEncodedRedToBlueRoute(address(ARB_INSTANCE)),
            getEncodedBlueToRedRoute(address(ARB_INSTANCE)),
            0,
            0,
            1e18,
            1e18,
            expectedRatio,
            expectedAmountOutputMax,
            "src/tranche/tranche-space.rain",
            "arb-red-blue-tranches.buy.initialized.prod",
            "./lib/h20.test-std/lib/rain.orderbook",
            "./lib/h20.test-std/lib/rain.orderbook/Cargo.toml",
            inputVaults,
            outputVaults
        );

        // OrderBook 'takeOrder'
        checkStrategyCalculationsArbOrder(strategy);

    }

    // Inheriting contract defines the route for the strategy.
    function getEncodedRedToBlueRoute(address toAddress) internal pure returns (bytes memory) {
        bytes memory RED_TO_BLUE_ROUTE_PRELUDE =
            hex"02"
            hex"6d3AbB80c3CBAe0f60ba274F36137298D8571Fbe"
            hex"01"
            hex"ffff"
            hex"00"
            hex"96ef2820731E4bd25c0E1809a2C62B18dAa90794"
            hex"00";

        return abi.encode(bytes.concat(RED_TO_BLUE_ROUTE_PRELUDE, abi.encodePacked(address(toAddress))));
    }

    // Inheriting contract defines the route for the strategy.
    function getEncodedBlueToRedRoute(address toAddress) internal pure returns (bytes memory) {
        bytes memory BLUE_TO_RED_ROUTE_PRELUDE =
            hex"02"
            hex"667f41fF7D9c06D2dd18511b32041fC6570Dc468"
            hex"01"
            hex"ffff"
            hex"00"
            hex"96ef2820731E4bd25c0E1809a2C62B18dAa90794"
            hex"01";

        return abi.encode(bytes.concat(BLUE_TO_RED_ROUTE_PRELUDE, abi.encodePacked(address(toAddress))));
    }



}