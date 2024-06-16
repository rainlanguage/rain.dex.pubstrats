// SPDX-License-Identifier: CAL
pragma solidity =0.8.19;
import {console2, Test} from "forge-std/Test.sol";
import {
    IOrderBookV3,
    IO,
    OrderV2,
    OrderConfigV2,
    TakeOrderConfigV2,
    TakeOrdersConfigV2
} from "rain.orderbook.interface/interface/IOrderBookV3.sol";
import {IOrderBookV3ArbOrderTaker} from "rain.orderbook.interface/interface/IOrderBookV3ArbOrderTaker.sol";
import {IParserV1} from "rain.interpreter.interface/interface/IParserV1.sol";
import {IExpressionDeployerV3} from "rain.interpreter.interface/interface/IExpressionDeployerV3.sol";
import { EvaluableConfigV3, SignedContextV1} from "rain.interpreter.interface/interface/IInterpreterCallerV2.sol";
import {IInterpreterV2,SourceIndexV2} from "rain.interpreter.interface/interface/IInterpreterV2.sol";
import {IInterpreterStoreV2} from "rain.interpreter.interface/interface/IInterpreterStoreV2.sol";
import {StrategyTests, IRouteProcessor, LibStrategyDeployment, LibComposeOrders} from "h20.test-std/StrategyTests.sol";
import {LibEncodedDispatch} from "rain.interpreter.interface/lib/caller/LibEncodedDispatch.sol";
import {StateNamespace, LibNamespace, FullyQualifiedNamespace} from "rain.interpreter.interface/lib/ns/LibNamespace.sol";
import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";
import {SafeERC20, IERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "h20.test-std/lib/LibProcessStream.sol";

uint256 constant VAULT_ID = uint256(keccak256("vault"));

string constant FIXED_TRADER = "src/wip/fixed-trader.rain";
string constant FIXED_TRADER_BUY_PROD = "polygon-red-fixed-price.buy.deviation.prod";
string constant FIXED_TRADER_SELL_PROD = "polygon-red-fixed-price.sell.deviation.prod";


/// @dev https://polygonscan.com/address/0x222789334D44bB5b2364939477E15A6c981Ca165
IERC20 constant POLYGON_RED = IERC20(0x222789334D44bB5b2364939477E15A6c981Ca165); 

/// @dev https://polygonscan.com/address/0x6d3AbB80c3CBAe0f60ba274F36137298D8571Fbe
IERC20 constant POLYGON_BLUE = IERC20(0x6d3AbB80c3CBAe0f60ba274F36137298D8571Fbe);

function polygonRedIo() pure returns (IO memory) {
    return IO(address(POLYGON_RED), 18, VAULT_ID);
}

function polygonBlueIo() pure returns (IO memory) {
    return IO(address(POLYGON_BLUE), 18, VAULT_ID);
}

contract FixedTraderTest is StrategyTests {

    using SafeERC20 for IERC20;
    using Strings for address;

    uint256 constant FORK_BLOCK_NUMBER = 58147039;
   
    
    function selectFork() internal {
        uint256 fork = vm.createFork(vm.envString("RPC_URL_POLYGON"));
        vm.selectFork(fork);
        vm.rollFork(FORK_BLOCK_NUMBER);
    }

    function getNamespace() public view returns (FullyQualifiedNamespace) {
        return LibNamespace.qualifyNamespace(StateNamespace.wrap(0), address(this));
    }

    function setUp() public {
        selectFork();
        
        PARSER = IParserV1(0x7A44459893F99b9d9a92d488eb5d16E4090f0545);
        INTERPRETER = IInterpreterV2(0x762adD85a30A83722feF2e029087C9D110B6a7b3); 
        STORE = IInterpreterStoreV2(0x59401C9302E79Eb8AC6aea659B8B3ae475715e86); 
        EXPRESSION_DEPLOYER = IExpressionDeployerV3(0xB3aC858bEAf7814892d3946A8C109A7D701DF8E7); 
        ORDERBOOK = IOrderBookV3(0xc95A5f8eFe14d7a20BD2E5BAFEC4E71f8Ce0B9A6); 
        ARB_INSTANCE = IOrderBookV3ArbOrderTaker(0x9a8545FA798A7be7F8E1B8DaDD79c9206357C015);
        ROUTE_PROCESSOR = IRouteProcessor(address(0xE7eb31f23A5BefEEFf76dbD2ED6AdC822568a5d2)); 
        EXTERNAL_EOA = address(0x654FEf5Fb8A1C91ad47Ba192F7AA81dd3C821427);
        APPROVED_EOA = address(0x669845c29D9B1A64FFF66a55aA13EB4adB889a88);
        ORDER_OWNER = address(0x19f95a84aa1C48A2c6a7B2d5de164331c86D030C);
    }

    function testBuyRedHappyPath() public {

        IO[] memory inputVaults = new IO[](1);
        inputVaults[0] = polygonRedIo();

        IO[] memory outputVaults = new IO[](1);
        outputVaults[0] = polygonBlueIo();

        uint256 expectedRatio = 826018037965693561;
        uint256 expectedAmountOutputMax = 1085303707401124384;

        LibStrategyDeployment.StrategyDeployment memory strategy = LibStrategyDeployment.StrategyDeployment(
            "",
            getEncodedBlueRedRoute(address(ARB_INSTANCE)),
            0,
            0,
            1e18,
            10e18,
            expectedRatio,
            expectedAmountOutputMax,
            FIXED_TRADER,
            FIXED_TRADER_BUY_PROD,
            "./lib/h20.test-std/lib/rain.orderbook",
            "./lib/h20.test-std/lib/rain.orderbook/Cargo.toml",
            inputVaults,
            outputVaults
        );

        OrderV2 memory order = addOrderDepositOutputTokens(strategy);
        {
            vm.recordLogs();
            takeArbOrder(order, strategy.takerRoute, strategy.inputTokenIndex, strategy.outputTokenIndex);
            Vm.Log[] memory entries = vm.getRecordedLogs();
            (uint256 strategyAmount, uint256 strategyRatio) = getCalculationContext(entries);
            assertEq(strategyRatio, strategy.expectedRatio);
            assertEq(strategyAmount, strategy.expectedAmount);
        }
    }

    function testSellRedHappyPath() public {

        IO[] memory inputVaults = new IO[](1);
        inputVaults[0] = polygonBlueIo();

        IO[] memory outputVaults = new IO[](1);
        outputVaults[0] = polygonRedIo();

        uint256 expectedRatio = 812954898051806664;
        uint256 expectedAmountOutputMax = 1212002916474629021;

        LibStrategyDeployment.StrategyDeployment memory strategy = LibStrategyDeployment.StrategyDeployment(
            "",
            getEncodedRedBlueRoute(address(ARB_INSTANCE)),
            0,
            0,
            1e18,
            10e18,
            expectedRatio,
            expectedAmountOutputMax,
            FIXED_TRADER,
            FIXED_TRADER_SELL_PROD,
            "./lib/h20.test-std/lib/rain.orderbook",
            "./lib/h20.test-std/lib/rain.orderbook/Cargo.toml",
            inputVaults,
            outputVaults
        );

        OrderV2 memory order = addOrderDepositOutputTokens(strategy);
        {
            vm.recordLogs();
            takeArbOrder(order, strategy.takerRoute, strategy.inputTokenIndex, strategy.outputTokenIndex);
            Vm.Log[] memory entries = vm.getRecordedLogs();
            (uint256 strategyAmount, uint256 strategyRatio) = getCalculationContext(entries);
            assertEq(strategyRatio, strategy.expectedRatio);
            assertEq(strategyAmount, strategy.expectedAmount);
        }

    }

    function testCooldown() public {

        IO[] memory inputVaults = new IO[](1);
        inputVaults[0] = polygonRedIo();

        IO[] memory outputVaults = new IO[](1);
        outputVaults[0] = polygonBlueIo();

        LibStrategyDeployment.StrategyDeployment memory strategy = LibStrategyDeployment.StrategyDeployment(
            "",
            getEncodedBlueRedRoute(address(ARB_INSTANCE)),
            0,
            0,
            0,
            10e18,
            0,
            0,
            FIXED_TRADER,
            FIXED_TRADER_BUY_PROD,
            "./lib/h20.test-std/lib/rain.orderbook",
            "./lib/h20.test-std/lib/rain.orderbook/Cargo.toml",
            inputVaults,
            outputVaults
        );

        OrderV2 memory order = addOrderDepositOutputTokens(strategy);
        {   
            takeArbOrder(order, strategy.takerRoute, strategy.inputTokenIndex, strategy.outputTokenIndex);
        }

        // Check cooldown
        {   
            vm.warp(block.timestamp + 59);
            vm.expectRevert("cooldown");
            takeArbOrder(order, strategy.takerRoute, strategy.inputTokenIndex, strategy.outputTokenIndex);
        }
        // Cooldown succeeds
        {   
            vm.warp(block.timestamp + 1);
            takeArbOrder(order, strategy.takerRoute, strategy.inputTokenIndex, strategy.outputTokenIndex);
        }
    }

    function testBountyAuction() public {

        IO[] memory inputVaults = new IO[](1);
        inputVaults[0] = polygonBlueIo();

        IO[] memory outputVaults = new IO[](1);
        outputVaults[0] = polygonRedIo();

        LibStrategyDeployment.StrategyDeployment memory strategy = LibStrategyDeployment.StrategyDeployment(
            getEncodedBlueRedRoute(address(ARB_INSTANCE)),
            getEncodedRedBlueRoute(address(ARB_INSTANCE)),
            0,
            0,
            3e18,
            10e18,
            0,
            0,
            FIXED_TRADER,
            FIXED_TRADER_SELL_PROD,
            "./lib/h20.test-std/lib/rain.orderbook",
            "./lib/h20.test-std/lib/rain.orderbook/Cargo.toml",
            inputVaults,
            outputVaults
        );

        OrderV2 memory order = addOrderDepositOutputTokens(strategy);
        {   
            moveExternalPrice(
                strategy.inputVaults[strategy.inputTokenIndex].token,
                strategy.outputVaults[strategy.outputTokenIndex].token,
                strategy.makerAmount,
                strategy.makerRoute
            );

            vm.recordLogs();
            takeArbOrder(order, strategy.takerRoute, strategy.inputTokenIndex, strategy.outputTokenIndex);
            Vm.Log[] memory entries = vm.getRecordedLogs();
            (uint256 inputTokenBounty,) = getBounty(entries);

            // Assert greater than max bounty.
            assertGe(inputTokenBounty, 0.1e18);
        }

        // Cooldown
        uint256 cooldownTime = 60;
        vm.warp(block.timestamp + cooldownTime); 
        {
            vm.recordLogs();
            takeArbOrder(order, strategy.takerRoute, strategy.inputTokenIndex, strategy.outputTokenIndex);
            Vm.Log[] memory entries = vm.getRecordedLogs();
            (uint256 inputTokenBounty,) = getBounty(entries);

            // Assert greater than min-bounty + (bounty-units * time-since-cooldown)
            // 0.01 + (0.01 * 0)
            assertGe(inputTokenBounty, 0.01e18);
        }

        // 10 seconds after cooldown
        vm.warp(block.timestamp + cooldownTime + 10); 
        {
            vm.recordLogs();
            takeArbOrder(order, strategy.takerRoute, strategy.inputTokenIndex, strategy.outputTokenIndex);
            Vm.Log[] memory entries = vm.getRecordedLogs();
            (uint256 inputTokenBounty,) = getBounty(entries);

            // Assert greater than min-bounty + (bounty-units * time-since-cooldown)
            // 0.01 + ((0.01/60) * 10)
            assertGe(inputTokenBounty, 0.0116e18);
        }
    } 

    function testBuyTwapCheck() public {

        IO[] memory inputVaults = new IO[](1);
        inputVaults[0] = polygonRedIo();

        IO[] memory outputVaults = new IO[](1);
        outputVaults[0] = polygonBlueIo();

        uint256 expectedRatio = 986015399172305425;
        uint256 expectedAmountOutputMax = 1085303707401124384;

        LibStrategyDeployment.StrategyDeployment memory strategy = LibStrategyDeployment.StrategyDeployment(
            getEncodedRedBlueRoute(address(ARB_INSTANCE)),
            getEncodedBlueRedRoute(address(ARB_INSTANCE)),
            0,
            0,
            0,
            10e18,
            expectedRatio,
            expectedAmountOutputMax,
            FIXED_TRADER,
            "polygon-red-fixed-price.buy.test",
            "./lib/h20.test-std/lib/rain.orderbook",
            "./lib/h20.test-std/lib/rain.orderbook/Cargo.toml",
            inputVaults,
            outputVaults
        );

        OrderV2 memory order = addOrderDepositOutputTokens(strategy);

        // No guard if the BLUE/RED price decreases
        {
            moveExternalPrice(
                    strategy.inputVaults[strategy.inputTokenIndex].token,
                    strategy.outputVaults[strategy.outputTokenIndex].token,
                    3e18,
                    strategy.makerRoute
            );
            takeArbOrder(order, strategy.takerRoute, strategy.inputTokenIndex, strategy.outputTokenIndex);
        }

        // Guard if the BLUE/RED price increases
        {
            moveExternalPrice(
                    strategy.outputVaults[strategy.outputTokenIndex].token,
                    strategy.inputVaults[strategy.inputTokenIndex].token,
                    3e18,
                    strategy.takerRoute
            );
            vm.expectRevert("twap check");
            takeArbOrder(order, strategy.takerRoute, strategy.inputTokenIndex, strategy.outputTokenIndex);
        }

    }

    function testSellTwapCheck() public {

        IO[] memory inputVaults = new IO[](1);
        inputVaults[0] = polygonBlueIo();

        IO[] memory outputVaults = new IO[](1);
        outputVaults[0] = polygonRedIo();

        uint256 expectedRatio = 989440598897252335;
        uint256 expectedAmountOutputMax = 995818959217219726;

        LibStrategyDeployment.StrategyDeployment memory strategy = LibStrategyDeployment.StrategyDeployment(
            getEncodedBlueRedRoute(address(ARB_INSTANCE)),
            getEncodedRedBlueRoute(address(ARB_INSTANCE)),
            0,
            0,
            0,
            10e18,
            expectedRatio,
            expectedAmountOutputMax,
            FIXED_TRADER,
            "polygon-red-fixed-price.sell.test",
            "./lib/h20.test-std/lib/rain.orderbook",
            "./lib/h20.test-std/lib/rain.orderbook/Cargo.toml",
            inputVaults,
            outputVaults
        ); 

        OrderV2 memory order = addOrderDepositOutputTokens(strategy);

        // No guard if the BLUE/RED price increases
        {
            moveExternalPrice(
                    strategy.inputVaults[strategy.inputTokenIndex].token,
                    strategy.outputVaults[strategy.outputTokenIndex].token,
                    3e18,
                    strategy.makerRoute
            );

            
            takeArbOrder(order, strategy.takerRoute, strategy.inputTokenIndex, strategy.outputTokenIndex);
        }

        // Guard if the BLUE/RED price decreases
        {
            moveExternalPrice(
                strategy.outputVaults[strategy.outputTokenIndex].token,
                strategy.inputVaults[strategy.inputTokenIndex].token,
                4e18,
                strategy.takerRoute
            );
            vm.expectRevert("twap check");
            takeArbOrder(order, strategy.takerRoute, strategy.inputTokenIndex, strategy.outputTokenIndex);
        }
    } 
    
    function testMinPrice() public {

        IO[] memory inputVaults = new IO[](1);
        inputVaults[0] = polygonRedIo();

        IO[] memory outputVaults = new IO[](1);
        outputVaults[0] = polygonBlueIo();

        uint256 expectedRatio = 986015399172305425;
        uint256 expectedAmountOutputMax = 1085303707401124384;

        LibStrategyDeployment.StrategyDeployment memory strategy = LibStrategyDeployment.StrategyDeployment(
            getEncodedRedBlueRoute(address(ARB_INSTANCE)),
            getEncodedBlueRedRoute(address(ARB_INSTANCE)),
            0,
            0,
            0,
            10e18,
            expectedRatio,
            expectedAmountOutputMax,
            FIXED_TRADER,
            FIXED_TRADER_BUY_PROD,
            "./lib/h20.test-std/lib/rain.orderbook",
            "./lib/h20.test-std/lib/rain.orderbook/Cargo.toml",
            inputVaults,
            outputVaults
        );

        OrderV2 memory order = addOrderDepositOutputTokens(strategy);

        // Move price below min price
        {   
            moveExternalPrice(
                strategy.inputVaults[strategy.inputTokenIndex].token,
                strategy.outputVaults[strategy.outputTokenIndex].token,
                5e18,
                strategy.makerRoute
            );
            vm.expectRevert("min price");
            takeArbOrder(order, strategy.takerRoute, strategy.inputTokenIndex, strategy.outputTokenIndex);
        }
    }

    function getBounty(Vm.Log[] memory entries)
        public
        view
        returns (uint256 inputTokenBounty, uint256 outputTokenBounty)
    {   
        // Array of length 2 to store the input and ouput token bounties.
        uint256[] memory bounties = new uint256[](2);

        // Count the number of bounties found.
        uint256 bountyCount = 0;
        for (uint256 j = 0; j < entries.length; j++) { 
            if (
                entries[j].topics[0] == keccak256("Transfer(address,address,uint256)") && 
                address(ARB_INSTANCE) == abi.decode(abi.encodePacked(entries[j].topics[1]), (address)) &&
                address(APPROVED_EOA) == abi.decode(abi.encodePacked(entries[j].topics[2]), (address))
            ) {
                bounties[bountyCount] = abi.decode(entries[j].data, (uint256));
                bountyCount++;
            }   
        }
        return (bounties[0], bounties[1]);
    } 

    function getEncodedRedBlueRoute(address toAddress) internal pure returns (bytes memory) {
        bytes memory ROUTE_PRELUDE =
            hex"02222789334D44bB5b2364939477E15A6c981Ca16501ffff011eb6dAf263324A47a193b74ab0FB8a9ded68c5bb01";
            
        return abi.encode(bytes.concat(ROUTE_PRELUDE, abi.encodePacked(address(toAddress))));
    }

    function getEncodedBlueRedRoute(address toAddress) internal pure returns (bytes memory) {
        bytes memory ROUTE_PRELUDE =
            hex"026d3AbB80c3CBAe0f60ba274F36137298D8571Fbe01ffff011eb6dAf263324A47a193b74ab0FB8a9ded68c5bb00";
            
        return abi.encode(bytes.concat(ROUTE_PRELUDE, abi.encodePacked(address(toAddress))));
    }


}