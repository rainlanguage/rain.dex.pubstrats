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

contract TrancheSpreadTest is Test {
    using Strings for address;
    using Strings for uint256;

    using LibFixedPointDecimalArithmeticOpenZeppelin for uint256;
    using LibFixedPointDecimalScale for uint256;

    // Strategy Params
    uint256 TRANCHE_RESERVE_BASE_AMOUNT = 1000e18;
    uint256 TRANCHE_RESERVE_BASE_IO_RATIO = 327e18;
    uint256 SPREAD_RATIO = 101e16;
    uint256 TRANCHE_EDGE_THRESHOLD = 2e17;
    uint256 INITIAL_TRANCHE_SPACE = 1e18;
    uint256 TRANCHE_SPACE_SNAP_THRESHOLD = 1e12;

    uint256 constant FORK_BLOCK_NUMBER = 54062608;
    uint256 constant CONTEXT_VAULT_IO_ROWS = 5;

    address constant DISTRIBUTOR_TOKEN = 0xd0e9c8f5Fae381459cf07Ec506C1d2896E8b5df6;
    address constant RESERVE_TOKEN = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;
    address constant ORDER_OWNER = address(0x19f95a84aa1C48A2c6a7B2d5de164331c86D030C);

    IParserV1 public PARSER;
    IInterpreterV2 public INTERPRETER;
    IInterpreterStoreV2 public STORE;
    IExpressionDeployerV3 public EXPRESSION_DEPLOYER;
    ISubParserV2 public ORDERBOOK_SUPARSER;

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
    }

    function testTrancheSnapThreshold() public {
        FullyQualifiedNamespace namespace =
            LibNamespace.qualifyNamespace(StateNamespace.wrap(uint256(uint160(ORDER_OWNER))), address(this));

        uint256[][] memory sellOrderContext = getSellOrderContext(11223344);

        address expression;
        {
            (bytes memory bytecode, uint256[] memory constants) =
                PARSER.parse(getTrancheTestSpreadOrder(vm, address(ORDERBOOK_SUPARSER), 0, 101e16));
            (,, expression,) = EXPRESSION_DEPLOYER.deployExpression2(bytecode, constants);
        }
        // Eval above snap threshold
        {
            sellOrderContext[3][4] = 2000e18 + TRANCHE_SPACE_SNAP_THRESHOLD;
            (uint256[] memory calculateStack,) = IInterpreterV2(INTERPRETER).eval2(
                IInterpreterStoreV2(address(STORE)),
                namespace,
                LibEncodedDispatch.encode2(expression, SourceIndexV2.wrap(1), type(uint32).max),
                sellOrderContext,
                new uint256[](0)
            );
            // Assert snapped amount
            assertEq(calculateStack[0], 2e18);
        }
        // Eval below snap threshold
        {
            sellOrderContext[3][4] = 2000e18 - TRANCHE_SPACE_SNAP_THRESHOLD;
            (uint256[] memory calculateStack,) = IInterpreterV2(INTERPRETER).eval2(
                IInterpreterStoreV2(address(STORE)),
                namespace,
                LibEncodedDispatch.encode2(expression, SourceIndexV2.wrap(1), type(uint32).max),
                sellOrderContext,
                new uint256[](0)
            );
            // Assert snapped amount
            assertEq(calculateStack[0], 2e18);
        }
    }

    function testTrancheSellToken() public {
        FullyQualifiedNamespace namespace =
            LibNamespace.qualifyNamespace(StateNamespace.wrap(uint256(uint160(ORDER_OWNER))), address(this));

        uint256[][] memory sellOrderContext = getSellOrderContext(11223344);

        address expression;
        {
            (bytes memory bytecode, uint256[] memory constants) =
                PARSER.parse(getTrancheTestSpreadOrder(vm, address(ORDERBOOK_SUPARSER), 0, 101e16));
            (,, expression,) = EXPRESSION_DEPLOYER.deployExpression2(bytecode, constants);
        }

        // Eval just below tranche limit : (0 + 0.199)
        {
            sellOrderContext[3][4] = 199e18;
            vm.expectRevert("Tranche threshold reached.");
            IInterpreterV2(INTERPRETER).eval2(
                IInterpreterStoreV2(address(STORE)),
                namespace,
                LibEncodedDispatch.encode2(expression, SourceIndexV2.wrap(1), type(uint32).max),
                sellOrderContext,
                new uint256[](0)
            );
        }
        // Eval just above tranche limit : : (0 + 0.2)
        {
            sellOrderContext[3][4] = 200e18;
            IInterpreterV2(INTERPRETER).eval2(
                IInterpreterStoreV2(address(STORE)),
                namespace,
                LibEncodedDispatch.encode2(expression, SourceIndexV2.wrap(1), type(uint32).max),
                sellOrderContext,
                new uint256[](0)
            );
        }
        // Eval just above headroom threshold : (0 + 0.801)
        {
            sellOrderContext[3][4] = 801e18;
            vm.expectRevert("Tranche threshold reached.");
            IInterpreterV2(INTERPRETER).eval2(
                IInterpreterStoreV2(address(STORE)),
                namespace,
                LibEncodedDispatch.encode2(expression, SourceIndexV2.wrap(1), type(uint32).max),
                sellOrderContext,
                new uint256[](0)
            );
        }
        // Eval just at headroom threshold : (0 + 0.8)
        {
            sellOrderContext[3][4] = 800e18;
            IInterpreterV2(INTERPRETER).eval2(
                IInterpreterStoreV2(address(STORE)),
                namespace,
                LibEncodedDispatch.encode2(expression, SourceIndexV2.wrap(1), type(uint32).max),
                sellOrderContext,
                new uint256[](0)
            );
        }
        // Eval at tranche end
        {
            sellOrderContext[3][4] = 1000e18;
            IInterpreterV2(INTERPRETER).eval2(
                IInterpreterStoreV2(address(STORE)),
                namespace,
                LibEncodedDispatch.encode2(expression, SourceIndexV2.wrap(1), type(uint32).max),
                sellOrderContext,
                new uint256[](0)
            );
        }
    }

    function testTrancheBuyToken() public {
        FullyQualifiedNamespace namespace =
            LibNamespace.qualifyNamespace(StateNamespace.wrap(uint256(uint160(ORDER_OWNER))), address(this));

        uint256[][] memory buyOrderContext = getBuyOrderContext(11223344);

        // tranche space 1.5
        address tranche0;
        // tranche space 2
        address tranche1;

        {
            (bytes memory bytecode, uint256[] memory constants) =
                PARSER.parse(getTrancheTestSpreadOrder(vm, address(ORDERBOOK_SUPARSER), 15e17, 101e16));
            (,, tranche0,) = EXPRESSION_DEPLOYER.deployExpression2(bytecode, constants);
        }
        {
            (bytes memory bytecode, uint256[] memory constants) =
                PARSER.parse(getTrancheTestSpreadOrder(vm, address(ORDERBOOK_SUPARSER), 2e18, 101e16));
            (,, tranche1,) = EXPRESSION_DEPLOYER.deployExpression2(bytecode, constants);
        }
        // Eval just below tranche threshold : (1.5 - 0.301)
        {
            buyOrderContext[4][4] = 301e18;
            vm.expectRevert("Tranche threshold reached.");
            IInterpreterV2(INTERPRETER).eval2(
                IInterpreterStoreV2(address(STORE)),
                namespace,
                LibEncodedDispatch.encode2(tranche0, SourceIndexV2.wrap(1), type(uint32).max),
                buyOrderContext,
                new uint256[](0)
            );
        }
        // Eval just above tranche threshold : (1.5 - 0.3)
        {
            buyOrderContext[4][4] = 300e18;
            IInterpreterV2(INTERPRETER).eval2(
                IInterpreterStoreV2(address(STORE)),
                namespace,
                LibEncodedDispatch.encode2(tranche0, SourceIndexV2.wrap(1), type(uint32).max),
                buyOrderContext,
                new uint256[](0)
            );
        }
        // Eval just below above headroom threshold : (2 - 0.199)
        {
            buyOrderContext[4][4] = 199e18;
            vm.expectRevert("Tranche threshold reached.");
            IInterpreterV2(INTERPRETER).eval2(
                IInterpreterStoreV2(address(STORE)),
                namespace,
                LibEncodedDispatch.encode2(tranche1, SourceIndexV2.wrap(1), type(uint32).max),
                buyOrderContext,
                new uint256[](0)
            );
        }
        // Eval just at headroom threshold : (2 - 0.2)
        {
            buyOrderContext[4][4] = 200e18;
            IInterpreterV2(INTERPRETER).eval2(
                IInterpreterStoreV2(address(STORE)),
                namespace,
                LibEncodedDispatch.encode2(tranche1, SourceIndexV2.wrap(1), type(uint32).max),
                buyOrderContext,
                new uint256[](0)
            );
        }
        // Eval just at tranche end : (2 - 1)
        {
            buyOrderContext[4][4] = 1000e18;
            IInterpreterV2(INTERPRETER).eval2(
                IInterpreterStoreV2(address(STORE)),
                namespace,
                LibEncodedDispatch.encode2(tranche1, SourceIndexV2.wrap(1), type(uint32).max),
                buyOrderContext,
                new uint256[](0)
            );
        }
    }

    function testTranche0SellBuy() public {
        FullyQualifiedNamespace namespace =
            LibNamespace.qualifyNamespace(StateNamespace.wrap(uint256(uint160(ORDER_OWNER))), address(this));

        uint256[][] memory sellOrderContext = getSellOrderContext(11223344);
        uint256[][] memory buyOrderContext = getBuyOrderContext(11223344);

        // Sell Order
        uint256 distributedTokenOut;
        uint256 reserveTokenIn;
        {
            address expression;
            {
                (bytes memory bytecode, uint256[] memory constants) =
                    PARSER.parse(getTrancheTestSpreadOrder(vm, address(ORDERBOOK_SUPARSER), 0, 101e16));
                (,, expression,) = EXPRESSION_DEPLOYER.deployExpression2(bytecode, constants);
            }
            (uint256[] memory calculateStack,) = IInterpreterV2(INTERPRETER).eval2(
                IInterpreterStoreV2(address(STORE)),
                namespace,
                LibEncodedDispatch.encode2(expression, SourceIndexV2.wrap(0), type(uint32).max),
                sellOrderContext,
                new uint256[](0)
            );
            // Output Tokens offered by order owner
            sellOrderContext[4][4] = calculateStack[1];
            sellOrderContext[3][4] = calculateStack[1].fixedPointMul(calculateStack[0], Math.Rounding.Up);

            distributedTokenOut = sellOrderContext[4][4];
            reserveTokenIn = sellOrderContext[3][4];

            (uint256[] memory handleStack,) = IInterpreterV2(INTERPRETER).eval2(
                IInterpreterStoreV2(address(STORE)),
                namespace,
                LibEncodedDispatch.encode2(expression, SourceIndexV2.wrap(1), type(uint32).max),
                sellOrderContext,
                new uint256[](0)
            );
            assertEq(handleStack[0], 1e18);
        }

        // Buy Order
        uint256 distributedTokenIn;
        {
            address expression;
            {
                (bytes memory bytecode, uint256[] memory constants) =
                    PARSER.parse(getTrancheTestSpreadOrder(vm, address(ORDERBOOK_SUPARSER), 1e18, 101e16));
                (,, expression,) = EXPRESSION_DEPLOYER.deployExpression2(bytecode, constants);
            }
            (uint256[] memory calculateStack,) = IInterpreterV2(INTERPRETER).eval2(
                IInterpreterStoreV2(address(STORE)),
                namespace,
                LibEncodedDispatch.encode2(expression, SourceIndexV2.wrap(0), type(uint32).max),
                buyOrderContext,
                new uint256[](0)
            );
            // Output Tokens offered by order owner
            buyOrderContext[4][4] = reserveTokenIn;
            buyOrderContext[3][4] = reserveTokenIn.fixedPointMul(calculateStack[0], Math.Rounding.Up);
            distributedTokenIn = buyOrderContext[3][4];

            (uint256[] memory handleStack,) = IInterpreterV2(INTERPRETER).eval2(
                IInterpreterStoreV2(address(STORE)),
                namespace,
                LibEncodedDispatch.encode2(expression, SourceIndexV2.wrap(1), type(uint32).max),
                buyOrderContext,
                new uint256[](0)
            );

            assertEq(handleStack[0], 0);
        }

        console2.log("distributedTokenOut : ", distributedTokenOut);
        console2.log("distributedTokenIn : ", distributedTokenIn);

        assertGe(distributedTokenIn, distributedTokenOut);
    }

    function testTrancheNSellBuy() public {
        FullyQualifiedNamespace namespace =
            LibNamespace.qualifyNamespace(StateNamespace.wrap(uint256(uint160(ORDER_OWNER))), address(this));

        uint256[][] memory sellOrderContext = getSellOrderContext(11223344);
        uint256[][] memory buyOrderContext = getBuyOrderContext(11223344);

        for (uint256 i = 0; i < 10; i++) {
            uint256 trancheSpaceBefore = (i + 1) * 1e18;
            uint256 trancheSpaceAfter = (i + 2) * 1e18;

            // Sell Order
            uint256 distributedTokenOut;
            uint256 reserveTokenIn;
            {
                address expression;
                {
                    (bytes memory bytecode, uint256[] memory constants) = PARSER.parse(
                        getTrancheTestSpreadOrder(vm, address(ORDERBOOK_SUPARSER), trancheSpaceBefore, 101e16)
                    );
                    (,, expression,) = EXPRESSION_DEPLOYER.deployExpression2(bytecode, constants);
                }
                (uint256[] memory calculateStack,) = IInterpreterV2(INTERPRETER).eval2(
                    IInterpreterStoreV2(address(STORE)),
                    namespace,
                    LibEncodedDispatch.encode2(expression, SourceIndexV2.wrap(0), type(uint32).max),
                    sellOrderContext,
                    new uint256[](0)
                );
                // Output Tokens offered by order owner
                sellOrderContext[4][4] = calculateStack[1];
                sellOrderContext[3][4] = calculateStack[1].fixedPointMul(calculateStack[0], Math.Rounding.Up);

                distributedTokenOut = sellOrderContext[4][4];
                reserveTokenIn = sellOrderContext[3][4];

                (uint256[] memory handleStack,) = IInterpreterV2(INTERPRETER).eval2(
                    IInterpreterStoreV2(address(STORE)),
                    namespace,
                    LibEncodedDispatch.encode2(expression, SourceIndexV2.wrap(1), type(uint32).max),
                    sellOrderContext,
                    new uint256[](0)
                );

                assertEq(handleStack[0], trancheSpaceAfter);
            }

            // Buy Order
            uint256 distributedTokenIn;
            {
                address expression;
                {
                    (bytes memory bytecode, uint256[] memory constants) = PARSER.parse(
                        getTrancheTestSpreadOrder(vm, address(ORDERBOOK_SUPARSER), trancheSpaceAfter, 101e16)
                    );
                    (,, expression,) = EXPRESSION_DEPLOYER.deployExpression2(bytecode, constants);
                }
                (uint256[] memory calculateStack,) = IInterpreterV2(INTERPRETER).eval2(
                    IInterpreterStoreV2(address(STORE)),
                    namespace,
                    LibEncodedDispatch.encode2(expression, SourceIndexV2.wrap(0), type(uint32).max),
                    buyOrderContext,
                    new uint256[](0)
                );
                // Output Tokens offered by order owner
                buyOrderContext[4][4] = reserveTokenIn;
                buyOrderContext[3][4] = reserveTokenIn.fixedPointMul(calculateStack[0], Math.Rounding.Up);
                distributedTokenIn = buyOrderContext[3][4];

                (uint256[] memory handleStack,) = IInterpreterV2(INTERPRETER).eval2(
                    IInterpreterStoreV2(address(STORE)),
                    namespace,
                    LibEncodedDispatch.encode2(expression, SourceIndexV2.wrap(1), type(uint32).max),
                    buyOrderContext,
                    new uint256[](0)
                );
                assertEq(handleStack[0], trancheSpaceBefore);
            }
            assertGe(distributedTokenIn, distributedTokenOut);
        }
    }

    function testIntialTrancheSpace() public {
        FullyQualifiedNamespace namespace =
            LibNamespace.qualifyNamespace(StateNamespace.wrap(uint256(uint160(ORDER_OWNER))), address(this));

        uint256[][] memory sellOrderContext = getSellOrderContext(11223344);
        uint256[][] memory buyOrderContext = getBuyOrderContext(11223344);

        address expression;
        {
            (bytes memory bytecode, uint256[] memory constants) =
                PARSER.parse(getTrancheSpreadOrder(vm, address(ORDERBOOK_SUPARSER)));
            (,, expression,) = EXPRESSION_DEPLOYER.deployExpression2(bytecode, constants);
        }
        sellOrderContext[3][4] = TRANCHE_RESERVE_BASE_AMOUNT;
        buyOrderContext[4][4] = TRANCHE_RESERVE_BASE_AMOUNT;

        // Sell Orders
        for (uint256 i = 0; i < 10; i++) {
            uint256 trancheSpaceBefore = INITIAL_TRANCHE_SPACE * (i + 1);
            uint256 trancheSpaceAfter = INITIAL_TRANCHE_SPACE * (i + 2);

            (uint256[] memory handleStack, uint256[] memory handleKvs) = IInterpreterV2(INTERPRETER).eval2(
                IInterpreterStoreV2(address(STORE)),
                namespace,
                LibEncodedDispatch.encode2(expression, SourceIndexV2.wrap(1), type(uint32).max),
                sellOrderContext,
                new uint256[](0)
            );
            assertEq(handleStack[handleStack.length - 1], trancheSpaceBefore);
            assertEq(handleStack[0], trancheSpaceAfter);
            STORE.set(StateNamespace.wrap(uint256(uint160(ORDER_OWNER))), handleKvs);
        }
        // Buy Orders
        for (uint256 i = 10; i > 0; i--) {
            uint256 trancheSpaceBefore = INITIAL_TRANCHE_SPACE * (i + 1);
            uint256 trancheSpaceAfter = INITIAL_TRANCHE_SPACE * i;

            (uint256[] memory handleStack, uint256[] memory handleKvs) = IInterpreterV2(INTERPRETER).eval2(
                IInterpreterStoreV2(address(STORE)),
                namespace,
                LibEncodedDispatch.encode2(expression, SourceIndexV2.wrap(1), type(uint32).max),
                buyOrderContext,
                new uint256[](0)
            );
            assertEq(handleStack[handleStack.length - 1], trancheSpaceBefore);
            assertEq(handleStack[0], trancheSpaceAfter);
            STORE.set(StateNamespace.wrap(uint256(uint160(ORDER_OWNER))), handleKvs);
        }
    }

    function getTrancheSpreadOrder(Vm vm, address orderBookSubparser) internal returns (bytes memory trancheRefill) {
        string[] memory ffi = new string[](33);
        ffi[0] = "rain";
        ffi[1] = "dotrain";
        ffi[2] = "compose";
        ffi[3] = "-i";
        ffi[4] = "src/tranche-spread.rain";
        ffi[5] = "--entrypoint";
        ffi[6] = "calculate-io";
        ffi[7] = "--entrypoint";
        ffi[8] = "handle-io";
        ffi[9] = "--bind";
        ffi[10] = "distribution-token=0xd0e9c8f5Fae381459cf07Ec506C1d2896E8b5df6";
        ffi[11] = "--bind";
        ffi[12] = "reserve-token=0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270";
        ffi[13] = "--bind";
        ffi[14] = "get-tranche-space='get-real-tranche-space";
        ffi[15] = "--bind";
        ffi[16] = "set-tranche-space='set-real-tranche-space";
        ffi[17] = "--bind";
        ffi[18] = "tranche-reserve-amount-growth='tranche-reserve-amount-growth-constant";
        ffi[19] = "--bind";
        ffi[20] = string.concat("tranche-reserve-amount-base=", TRANCHE_RESERVE_BASE_AMOUNT.toString());
        ffi[21] = "--bind";
        ffi[22] = "tranche-reserve-io-ratio-growth='tranche-reserve-io-ratio-linear";
        ffi[23] = "--bind";
        ffi[24] = string.concat("tranche-reserve-io-ratio-base=", TRANCHE_RESERVE_BASE_IO_RATIO.toString());
        ffi[25] = "--bind";
        ffi[26] = string.concat("spread-ratio=", SPREAD_RATIO.toString());
        ffi[27] = "--bind";
        ffi[28] = string.concat("tranche-space-edge-guard-threshold=", TRANCHE_EDGE_THRESHOLD.toString());
        ffi[29] = "--bind";
        ffi[30] = string.concat("initial-tranche-space=", INITIAL_TRANCHE_SPACE.toString());
        ffi[31] = "--bind";
        ffi[32] = string.concat("tranche-space-snap-threshold=", TRANCHE_SPACE_SNAP_THRESHOLD.toString());

        trancheRefill = bytes.concat(getSubparserPrelude(orderBookSubparser), vm.ffi(ffi));
    }

    function getTrancheTestSpreadOrder(Vm vm, address orderBookSubparser, uint256 testTrancheSpace, uint256 spreadRatio)
        internal
        returns (bytes memory trancheRefill)
    {
        string[] memory ffi = new string[](35);
        ffi[0] = "rain";
        ffi[1] = "dotrain";
        ffi[2] = "compose";
        ffi[3] = "-i";
        ffi[4] = "src/tranche-spread.rain";
        ffi[5] = "--entrypoint";
        ffi[6] = "calculate-io";
        ffi[7] = "--entrypoint";
        ffi[8] = "handle-io";
        ffi[9] = "--bind";
        ffi[10] = "distribution-token=0xd0e9c8f5Fae381459cf07Ec506C1d2896E8b5df6";
        ffi[11] = "--bind";
        ffi[12] = "reserve-token=0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270";
        ffi[13] = "--bind";
        ffi[14] = "get-tranche-space='get-test-tranche-space";
        ffi[15] = "--bind";
        ffi[16] = "set-tranche-space='set-test-tranche-space";
        ffi[17] = "--bind";
        ffi[18] = string.concat("test-tranche-space=", testTrancheSpace.toString());
        ffi[19] = "--bind";
        ffi[20] = "tranche-reserve-amount-growth='tranche-reserve-amount-growth-constant";
        ffi[21] = "--bind";
        ffi[22] = string.concat("tranche-reserve-amount-base=", TRANCHE_RESERVE_BASE_AMOUNT.toString());
        ffi[23] = "--bind";
        ffi[24] = "tranche-reserve-io-ratio-growth='tranche-reserve-io-ratio-linear";
        ffi[25] = "--bind";
        ffi[26] = string.concat("tranche-reserve-io-ratio-base=", TRANCHE_RESERVE_BASE_IO_RATIO.toString());
        ffi[27] = "--bind";
        ffi[28] = string.concat("spread-ratio=", spreadRatio.toString());
        ffi[29] = "--bind";
        ffi[30] = string.concat("tranche-space-edge-guard-threshold=", TRANCHE_EDGE_THRESHOLD.toString());
        ffi[31] = "--bind";
        ffi[32] = string.concat("initial-tranche-space=", INITIAL_TRANCHE_SPACE.toString());
        ffi[33] = "--bind";
        ffi[34] = string.concat("tranche-space-snap-threshold=", TRANCHE_SPACE_SNAP_THRESHOLD.toString());

        trancheRefill = bytes.concat(getSubparserPrelude(orderBookSubparser), vm.ffi(ffi));
    }

    function getSubparserPrelude(address obSubparser) internal pure returns (bytes memory) {
        bytes memory RAINSTRING_OB_SUBPARSER = bytes(string.concat("using-words-from ", obSubparser.toHexString(), " "));
        return RAINSTRING_OB_SUBPARSER;
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
                inputsContext[0] = uint256(uint160(RESERVE_TOKEN));
                inputsContext[1] = 18;
                context[3] = inputsContext;
            }
            {
                uint256[] memory outputsContext = new uint256[](CONTEXT_VAULT_IO_ROWS);
                outputsContext[0] = uint256(uint160(DISTRIBUTOR_TOKEN));
                outputsContext[1] = 18;
                context[4] = outputsContext;
            }
        }
    }

    function getBuyOrderContext(uint256 orderHash) internal pure returns (uint256[][] memory context) {
        // Buy Order Context
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
                inputsContext[0] = uint256(uint160(DISTRIBUTOR_TOKEN));
                inputsContext[1] = 18;
                context[3] = inputsContext;
            }
            {
                uint256[] memory outputsContext = new uint256[](CONTEXT_VAULT_IO_ROWS);
                outputsContext[0] = uint256(uint160(RESERVE_TOKEN));
                outputsContext[1] = 18;
                context[4] = outputsContext;
            }
        }
    }
}
