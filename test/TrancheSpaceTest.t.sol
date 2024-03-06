// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.19;

import {Vm} from "forge-std/Vm.sol";
import {Test, console2} from "forge-std/Test.sol";
import {IParserV1} from "rain.interpreter.interface/interface/IParserV1.sol";
import {IInterpreterV2,SourceIndexV2} from "rain.interpreter.interface/interface/IInterpreterV2.sol";
import {IInterpreterStoreV2} from "rain.interpreter.interface/interface/IInterpreterStoreV2.sol";
import {ISubParserV2} from "rain.interpreter.interface/interface/ISubParserV2.sol";
import {IExpressionDeployerV3} from "rain.interpreter.interface/interface/IExpressionDeployerV3.sol";
import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";
import "rain.math.saturating/src/SaturatingMath.sol";
import "src/lib/LibTrancheSpaceOrders.sol";
import "rain.math.fixedpoint/lib/LibFixedPointDecimalArithmeticOpenZeppelin.sol";
import "rain.math.fixedpoint/lib/LibFixedPointDecimalScale.sol";
import "rain.interpreter.interface/lib/caller/LibEncodedDispatch.sol";
import "rain.interpreter.interface/lib/ns/LibNamespace.sol";
 


contract TrancheSpaceTest is Test {
    using Strings for address;
    using Strings for uint256;

    using LibFixedPointDecimalArithmeticOpenZeppelin for uint256;
    using LibFixedPointDecimalScale for uint256; 

    IParserV1 public PARSER;
    IInterpreterV2 public INTERPRETER;
    IInterpreterStoreV2 public STORE;
    IExpressionDeployerV3 public EXPRESSION_DEPLOYER;
    ISubParserV2 public ORDERBOOK_SUPARSER;

    uint256 constant FORK_BLOCK_NUMBER = 54342303;
    uint256 constant CONTEXT_VAULT_IO_ROWS = 5;

    uint256 constant REFERENCE_RESERVE_DECIMALS = 18;
    uint256 constant REFERENCE_STABLE_DECIMALS = 6;
    address constant REFERENCE_RESERVE = 0xd0e9c8f5Fae381459cf07Ec506C1d2896E8b5df6;
    address constant REFERENCE_STABLE = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;
    address constant ORDER_OWNER = address(0x19f95a84aa1C48A2c6a7B2d5de164331c86D030C);

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
    } 

    function testSpaceModelling() public {
        string memory file = "./test/csvs/tranche-space.csv";
        if (vm.exists(file)) vm.removeFile(file);

        FullyQualifiedNamespace namespace =
            LibNamespace.qualifyNamespace(StateNamespace.wrap(uint256(uint160(ORDER_OWNER))), address(this));

        uint256[][] memory sellOrderContext = getSellOrderContext(11223344);

        for (uint256 i = 0; i < 200; i++) {
            uint256 trancheSpace = uint256(1e17 * i);
            address expression;
            {
                LibTrancheSpaceOrders.TestTrancheSpaceOrder memory testTrancheSpaceOrderConfig = LibTrancheSpaceOrders.TestTrancheSpaceOrder(
                    TRANCHE_SPACE_PER_SECOND,
                    TRANCHE_SPACE_RECHARGE_DELAY,
                    TRANCHE_SIZE_BASE,
                    TRANCHE_SIZE_GROWTH,
                    IO_RATIO_BASE,
                    IO_RATIO_GROWTH,
                    MIN_TRANCHE_SPACE_DIFF,
                    TRANCHE_SNAP_THRESHOLD,
                    AMOUNT_IS_OUTPUT,
                    REFERENCE_STABLE_DECIMALS,
                    REFERENCE_RESERVE_DECIMALS,
                    trancheSpace,
                    block.timestamp,
                    block.timestamp + 1,
                    REFERENCE_STABLE,
                    REFERENCE_RESERVE
                );
                (bytes memory bytecode, uint256[] memory constants) =  PARSER.parse(
                        LibTrancheSpaceOrders.getTestTrancheSpaceOrder(
                        vm,
                        address(ORDERBOOK_SUPARSER),
                        testTrancheSpaceOrderConfig
                    )
                );
                (,, expression,) = EXPRESSION_DEPLOYER.deployExpression2(bytecode, constants); 
            }
            (uint256[] memory sellStack,) = IInterpreterV2(INTERPRETER).eval2(
                IInterpreterStoreV2(address(STORE)),
                namespace,
                LibEncodedDispatch.encode2(expression, SourceIndexV2.wrap(0), type(uint32).max),
                sellOrderContext,
                new uint256[](0)
            );

            string memory line = string.concat(trancheSpace.toString(), ",", sellStack[1].toString(), ",", sellStack[0].toString());

            vm.writeLine(file, line); 
        } 

    } 

    function testCalculateTranche(uint256 trancheSpaceBefore, uint256 delay) public {
        trancheSpaceBefore = bound(trancheSpaceBefore, 0, 100e18);
        delay = bound(delay, 1, 86400);
        uint256 lastTimeUpdate = block.timestamp;

        FullyQualifiedNamespace namespace =
            LibNamespace.qualifyNamespace(StateNamespace.wrap(uint256(uint160(ORDER_OWNER))), address(this));

        uint256[][] memory sellOrderContext = getSellOrderContext(11223344);
        
        address expression;
        {

            (bytes memory bytecode, uint256[] memory constants) =  PARSER.parse(
                    LibTrancheSpaceOrders.getCalculateTranche(
                    vm,
                    address(ORDERBOOK_SUPARSER),
                    trancheSpaceBefore,
                    lastTimeUpdate,
                    lastTimeUpdate + delay
                )
            );
            (,, expression,) = EXPRESSION_DEPLOYER.deployExpression2(bytecode, constants); 
        }
        (uint256[] memory stack,) = IInterpreterV2(INTERPRETER).eval2(
            IInterpreterStoreV2(address(STORE)),
            namespace,
            LibEncodedDispatch.encode2(expression, SourceIndexV2.wrap(0), type(uint32).max),
            sellOrderContext,
            new uint256[](0)
        );
        assertEq(stack[2], SaturatingMath.saturatingSub(trancheSpaceBefore, stack[4]));
        assertEq(stack[3], lastTimeUpdate + delay);

    } 

    function testHandleIo(uint256 outputTokenTraded, uint256 trancheSpaceBefore, uint256 delay) public {
        outputTokenTraded = bound(outputTokenTraded, 1e18, 1000000e18);
        trancheSpaceBefore = bound(trancheSpaceBefore, 0, 100e18);
        delay = bound(delay, 1, 86400);
        uint256 lastTimeUpdate = block.timestamp;

        FullyQualifiedNamespace namespace =
            LibNamespace.qualifyNamespace(StateNamespace.wrap(uint256(uint160(ORDER_OWNER))), address(this));

        uint256[][] memory sellOrderContext = getSellOrderContext(12345);

        {
            address calculateTrancheExpression;
            {

                (bytes memory calculateTrancheBytecode, uint256[] memory calculateTrancheConstants) =  PARSER.parse(
                        LibTrancheSpaceOrders.getCalculateTranche(
                        vm,
                        address(ORDERBOOK_SUPARSER),
                        trancheSpaceBefore,
                        lastTimeUpdate,
                        lastTimeUpdate + delay
                    )
                );
                (,, calculateTrancheExpression,) = EXPRESSION_DEPLOYER.deployExpression2(calculateTrancheBytecode, calculateTrancheConstants); 
            }
            (uint256[] memory calculateTrancheStack,) = IInterpreterV2(INTERPRETER).eval2(
                IInterpreterStoreV2(address(STORE)),
                namespace,
                LibEncodedDispatch.encode2(calculateTrancheExpression, SourceIndexV2.wrap(0), type(uint32).max),
                sellOrderContext,
                new uint256[](0)
            );

            (bytes memory bytecode, uint256[] memory constants) = PARSER.parse(
                LibTrancheSpaceOrders.getHandleIo(
                    vm,
                    address(ORDERBOOK_SUPARSER),
                    trancheSpaceBefore,
                    lastTimeUpdate,
                    lastTimeUpdate + delay
                )
            );
            (,, address handleIoExpression,) = EXPRESSION_DEPLOYER.deployExpression2(bytecode, constants);

            sellOrderContext[4][4] = outputTokenTraded;
            uint256 trancheSpaceAfter =
                trancheSpaceBefore + outputTokenTraded.fixedPointDiv(calculateTrancheStack[0], Math.Rounding.Down);

            if (trancheSpaceAfter < (trancheSpaceBefore + MIN_TRANCHE_SPACE_DIFF)) {
                vm.expectRevert(bytes("Minimum trade size not met."));
            }

            IInterpreterV2(INTERPRETER).eval2(
                IInterpreterStoreV2(address(STORE)),
                namespace,
                LibEncodedDispatch.encode2(handleIoExpression, SourceIndexV2.wrap(0), type(uint16).max),
                sellOrderContext,
                new uint256[](0)
            );
        }
        
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
                uint256[] memory calculationsContext = new uint256[](0);
                context[2] = calculationsContext;
            }
            {
                uint256[] memory inputsContext = new uint256[](CONTEXT_VAULT_IO_ROWS);
                inputsContext[0] = uint256(uint160(REFERENCE_STABLE));
                inputsContext[1] = REFERENCE_STABLE_DECIMALS;
                context[3] = inputsContext;
            }
            {
                uint256[] memory outputsContext = new uint256[](CONTEXT_VAULT_IO_ROWS);
                outputsContext[0] = uint256(uint160(REFERENCE_RESERVE));
                outputsContext[1] = REFERENCE_RESERVE_DECIMALS;
                context[4] = outputsContext;
            }
        }
    } 


    
}