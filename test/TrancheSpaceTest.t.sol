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

    uint256 constant FORK_BLOCK_NUMBER = 24517782;
    uint256 constant VAULT_ID = uint256(keccak256("vault"));

    string constant TRANCHE_SPACE_FILE_PATH = "src/tranche/tranche-space.rain";

    IERC20 constant RED_TOKEN = IERC20(0xE38D92733203E6f93C634304b777490e67Dc4Bdf);
    IERC20 constant BLUE_TOKEN = IERC20(0x40D44abeC30288BFcd400200BA65FBD05daA5321);

    function selectFlareFork() internal {
        uint256 fork = vm.createFork(vm.envString("RPC_URL_FLARE"));
        vm.selectFork(fork);
        vm.rollFork(FORK_BLOCK_NUMBER);
    }

    function setUp() public {
        selectFlareFork();

        PARSER = IParserV1(0x001B302095D66b777C04cd4d64b86CCe16de55A1);
        ORDERBOOK = IOrderBookV3(0xb06202aA3Fe7d85171fB7aA5f17011d17E63f382);
        ARB_INSTANCE = IOrderBookV3ArbOrderTaker(0x56394785a22b3BE25470a0e03eD9E0a939C47b9b);
        EXPRESSION_DEPLOYER = IExpressionDeployerV3(0x8ceC9e3Ec2F8838000b91CfB97403A6Bb0F4036A);
        ROUTE_PROCESSOR = IRouteProcessor(address(0x0bB72B4C7c0d47b2CaED07c804D9243C1B8a0728)); 
        EXTERNAL_EOA = address(0x654FEf5Fb8A1C91ad47Ba192F7AA81dd3C821427);
        APPROVED_EOA = address(0x669845c29D9B1A64FFF66a55aA13EB4adB889a88);
        ORDER_OWNER = address(0x19f95a84aa1C48A2c6a7B2d5de164331c86D030C);
    }

    function flareRedIo() internal pure returns (IO memory) {
        return IO(address(RED_TOKEN), 18, VAULT_ID);
    }

    function flareBlueIo() internal pure returns (IO memory) {
        return IO(address(BLUE_TOKEN), 18, VAULT_ID);
    }

    function testTrancheSpaceShynessExternalFlare() public {

        // Input vaults
        IO[] memory inputVaults = new IO[](1);
        inputVaults[0] = flareRedIo();

        // Output vaults
        IO[] memory outputVaults = new IO[](1);
        outputVaults[0] = flareBlueIo();

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
            TRANCHE_SPACE_FILE_PATH,
            "flare-red-blue-tranches.buy.initialized.test-shy-tranche",
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

    function testSuccessiveTranchesFlare() public {

        // Input vaults
        IO[] memory inputVaults = new IO[](1);
        inputVaults[0] = flareRedIo();

        // Output vaults
        IO[] memory outputVaults = new IO[](1);
        outputVaults[0] = flareBlueIo();

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
            TRANCHE_SPACE_FILE_PATH,
            "flare-red-blue-tranches.buy.initialized.prod",
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

    function testTrancheSpaceOrderMinimumRevertFlare() public {
        // Input vaults
        IO[] memory inputVaults = new IO[](1);
        inputVaults[0] = flareRedIo();

        // Output vaults
        IO[] memory outputVaults = new IO[](1);
        outputVaults[0] = flareBlueIo();

        uint256 expectedRatio = 1e18;
        uint256 expectedAmountOutputMax = 1e18;

        // Minimum Revert Amount = expectedAmountOutputMax * 10% = 1e17
        uint256 minimumRevertAmount = 1e17;

        LibStrategyDeployment.StrategyDeployment memory strategy = LibStrategyDeployment.StrategyDeployment(
            getEncodedRedToBlueRoute(address(ARB_INSTANCE)),
            getEncodedBlueToRedRoute(address(ARB_INSTANCE)),
            0,
            0,
            10e18,
            minimumRevertAmount,
            expectedRatio,
            expectedAmountOutputMax,
            TRANCHE_SPACE_FILE_PATH,
            "flare-red-blue-tranches.buy.initialized.prod",
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

    function testTrancheSpaceOrderExternalFlare() public {

        // Input vaults
        IO[] memory inputVaults = new IO[](1);
        inputVaults[0] = flareRedIo();

        // Output vaults
        IO[] memory outputVaults = new IO[](1);
        outputVaults[0] = flareBlueIo();

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
            TRANCHE_SPACE_FILE_PATH,
            "flare-red-blue-tranches.buy.initialized.prod",
            "./lib/h20.test-std/lib/rain.orderbook",
            "./lib/h20.test-std/lib/rain.orderbook/Cargo.toml",
            inputVaults,
            outputVaults
        );

        // OrderBook 'takeOrder'
        checkStrategyCalculations(strategy);
    }

    function testTrancheSpaceOrderArbFlare() public {
        // Input vaults
        IO[] memory inputVaults = new IO[](1);
        inputVaults[0] = flareRedIo();

        // Output vaults
        IO[] memory outputVaults = new IO[](1);
        outputVaults[0] = flareBlueIo();

        uint256 expectedRatio = 1e18;
        uint256 expectedAmountOutputMax = 1e18;

        LibStrategyDeployment.StrategyDeployment memory strategy = LibStrategyDeployment.StrategyDeployment(
            getEncodedRedToBlueRoute(address(ARB_INSTANCE)),
            getEncodedBlueToRedRoute(address(ARB_INSTANCE)),
            0,
            0,
            10e18,
            1e18,
            expectedRatio,
            expectedAmountOutputMax,
            TRANCHE_SPACE_FILE_PATH,
            "flare-red-blue-tranches.buy.initialized.prod",
            "./lib/h20.test-std/lib/rain.orderbook",
            "./lib/h20.test-std/lib/rain.orderbook/Cargo.toml",
            inputVaults,
            outputVaults
        );

        // OrderBook 'takeOrder'
        checkStrategyCalculationsArbOrder(strategy);

    }
    

    function getEncodedRedToBlueRoute(address toAddress) internal pure returns (bytes memory) {
        bytes memory RED_TO_BLUE_ROUTE_PRELUDE =
            hex"02"
            hex"E38D92733203E6f93C634304b777490e67Dc4Bdf"
            hex"01"
            hex"ffff"
            hex"00"
            hex"03585a45Af10963838e435601487516F97B18aF7"
            hex"00";

        return abi.encode(bytes.concat(RED_TO_BLUE_ROUTE_PRELUDE, abi.encodePacked(address(toAddress))));
    }

    // Inheriting contract defines the route for the strategy.
    function getEncodedBlueToRedRoute(address toAddress) internal pure returns (bytes memory) {
        bytes memory BLUE_TO_RED_ROUTE_PRELUDE =
            hex"02"
            hex"40D44abeC30288BFcd400200BA65FBD05daA5321"
            hex"01"
            hex"ffff"
            hex"00"
            hex"03585a45Af10963838e435601487516F97B18aF7"
            hex"01";

        return abi.encode(bytes.concat(BLUE_TO_RED_ROUTE_PRELUDE, abi.encodePacked(address(toAddress))));
    }
}