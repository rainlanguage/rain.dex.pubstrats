// SPDX-License-Identifier: CAL
pragma solidity =0.8.19;

import {Vm} from "forge-std/Vm.sol";
import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";

// STRATEGY PARAMS
uint256 constant TRANCHE_SPACE_PER_SECOND = 0;
uint256 constant TRANCHE_SPACE_RECHARGE_DELAY = 0;
uint256 constant TRANCHE_SIZE_BASE = 5000e18;
uint256 constant TRANCHE_SIZE_GROWTH = 1e18;
uint256 constant IO_RATIO_BASE = 6e18;
uint256 constant IO_RATIO_GROWTH = 1e17;
uint256 constant MIN_TRANCHE_SPACE_DIFF = 1e17;
uint256 constant TRANCHE_SNAP_THRESHOLD = 1e16;
uint256 constant AMOUNT_IS_OUTPUT = 0;

library LibTrancheSpaceOrders {
    using Strings for address;
    using Strings for uint256;

    struct TrancheSpaceOrder {
        uint256 trancheSpacePerSecond;
        uint256 trancheSpaceRechargeDelay;
        uint256 trancheSizeBase;
        uint256 trancheSizeGrowth;
        uint256 ioRatioBase;
        uint256 ioRatioGrowth;
        uint256 minTrancheSpaceDiff;
        uint256 trancheSpaceSnapThreshold;
        uint256 amountIsOutput;
        uint256 referenceStableDecimals;
        uint256 referenceReserveDecimals;
        address referenceStable;
        address referenceReserve;
    }

    struct TestTrancheSpaceOrder {
        uint256 trancheSpacePerSecond;
        uint256 trancheSpaceRechargeDelay;
        uint256 trancheSizeBase;
        uint256 trancheSizeGrowth;
        uint256 ioRatioBase;
        uint256 ioRatioGrowth;
        uint256 minTrancheSpaceDiff;
        uint256 trancheSpaceSnapThreshold;
        uint256 amountIsOutput;
        uint256 referenceStableDecimals;
        uint256 referenceReserveDecimals;
        uint256 testTrancheSpaceBefore;
        uint256 testLastTimeUpdate;
        uint256 testNow;
        address referenceStable;
        address referenceReserve;
    }

    function getTrancheSpaceOrder(Vm vm, address orderBookSubparser, TrancheSpaceOrder memory trancheSpaceOrderConfig)
        internal
        returns (bytes memory trancheSpaceOrder)
    {
        string[] memory ffi = new string[](45);
        ffi[0] = "rain";
        ffi[1] = "dotrain";
        ffi[2] = "compose";
        ffi[3] = "-i";
        ffi[4] = "src/tranche-space.rain";
        ffi[5] = "--entrypoint";
        ffi[6] = "calculate-io";
        ffi[7] = "--entrypoint";
        ffi[8] = "handle-io";
        ffi[9] = "--bind";
        ffi[10] = string.concat("tranche-space-per-second=", trancheSpaceOrderConfig.trancheSpacePerSecond.toString());
        ffi[11] = "--bind";
        ffi[12] =
            string.concat("tranche-space-recharge-delay=", trancheSpaceOrderConfig.trancheSpaceRechargeDelay.toString());
        ffi[13] = "--bind";
        ffi[14] = "tranche-size-expr='constant-growth";
        ffi[15] = "--bind";
        ffi[16] = string.concat("tranche-size-base=", trancheSpaceOrderConfig.trancheSizeBase.toString());
        ffi[17] = "--bind";
        ffi[18] = string.concat("tranche-size-growth=", trancheSpaceOrderConfig.trancheSizeGrowth.toString());
        ffi[19] = "--bind";
        ffi[20] = "io-ratio-expr='linear-growth";
        ffi[21] = "--bind";
        ffi[22] = string.concat("io-ratio-base=", trancheSpaceOrderConfig.ioRatioBase.toString());
        ffi[23] = "--bind";
        ffi[24] = string.concat("io-ratio-growth=", trancheSpaceOrderConfig.ioRatioGrowth.toString());
        ffi[25] = "--bind";
        ffi[26] = string.concat("reference-stable=", trancheSpaceOrderConfig.referenceStable.toHexString());
        ffi[27] = "--bind";
        ffi[28] =
            string.concat("reference-stable-decimals=", trancheSpaceOrderConfig.referenceStableDecimals.toString());
        ffi[29] = "--bind";
        ffi[30] = string.concat("reference-reserve=", trancheSpaceOrderConfig.referenceReserve.toHexString());
        ffi[31] = "--bind";
        ffi[32] =
            string.concat("reference-reserve-decimals=", trancheSpaceOrderConfig.referenceReserveDecimals.toString());
        ffi[33] = "--bind";
        ffi[34] = string.concat("min-tranche-space-diff=", trancheSpaceOrderConfig.minTrancheSpaceDiff.toString());
        ffi[35] = "--bind";
        ffi[36] =
            string.concat("tranche-space-snap-threshold=", trancheSpaceOrderConfig.trancheSpaceSnapThreshold.toString());
        ffi[37] = "--bind";
        ffi[38] = string.concat("amount-is-output=", trancheSpaceOrderConfig.amountIsOutput.toString());
        ffi[39] = "--bind";
        ffi[40] = "get-last-tranche='get-real-last-tranche";
        ffi[41] = "--bind";
        ffi[42] = "set-last-tranche='set-real-last-tranche";
        ffi[43] = "--bind";
        ffi[44] = "io-ratio-multiplier='io-ratio-multiplier-identity";

        trancheSpaceOrder = bytes.concat(getSubparserPrelude(orderBookSubparser), vm.ffi(ffi));
    }

    function getTestTrancheSpaceOrder(
        Vm vm,
        address orderBookSubparser,
        TestTrancheSpaceOrder memory testTrancheSpaceOrderConfig
    ) internal returns (bytes memory testTrancheSpaceOrder) {
        string[] memory ffi = new string[](51);
        ffi[0] = "rain";
        ffi[1] = "dotrain";
        ffi[2] = "compose";
        ffi[3] = "-i";
        ffi[4] = "src/tranche-space.rain";
        ffi[5] = "--entrypoint";
        ffi[6] = "calculate-io";
        ffi[7] = "--entrypoint";
        ffi[8] = "handle-io";
        ffi[9] = "--bind";
        ffi[10] =
            string.concat("tranche-space-per-second=", testTrancheSpaceOrderConfig.trancheSpacePerSecond.toString());
        ffi[11] = "--bind";
        ffi[12] = string.concat(
            "tranche-space-recharge-delay=", testTrancheSpaceOrderConfig.trancheSpaceRechargeDelay.toString()
        );
        ffi[13] = "--bind";
        ffi[14] = "tranche-size-expr='constant-growth";
        ffi[15] = "--bind";
        ffi[16] = string.concat("tranche-size-base=", testTrancheSpaceOrderConfig.trancheSizeBase.toString());
        ffi[17] = "--bind";
        ffi[18] = string.concat("tranche-size-growth=", testTrancheSpaceOrderConfig.trancheSizeGrowth.toString());
        ffi[19] = "--bind";
        ffi[20] = "io-ratio-expr='linear-growth";
        ffi[21] = "--bind";
        ffi[22] = string.concat("io-ratio-base=", testTrancheSpaceOrderConfig.ioRatioBase.toString());
        ffi[23] = "--bind";
        ffi[24] = string.concat("io-ratio-growth=", testTrancheSpaceOrderConfig.ioRatioGrowth.toString());
        ffi[25] = "--bind";
        ffi[26] = string.concat("reference-stable=", testTrancheSpaceOrderConfig.referenceStable.toHexString());
        ffi[27] = "--bind";
        ffi[28] =
            string.concat("reference-stable-decimals=", testTrancheSpaceOrderConfig.referenceStableDecimals.toString());
        ffi[29] = "--bind";
        ffi[30] = string.concat("reference-reserve=", testTrancheSpaceOrderConfig.referenceReserve.toHexString());
        ffi[31] = "--bind";
        ffi[32] = string.concat(
            "reference-reserve-decimals=", testTrancheSpaceOrderConfig.referenceReserveDecimals.toString()
        );
        ffi[33] = "--bind";
        ffi[34] = string.concat("min-tranche-space-diff=", testTrancheSpaceOrderConfig.minTrancheSpaceDiff.toString());
        ffi[35] = "--bind";
        ffi[36] = string.concat(
            "tranche-space-snap-threshold=", testTrancheSpaceOrderConfig.trancheSpaceSnapThreshold.toString()
        );
        ffi[37] = "--bind";
        ffi[38] = string.concat("amount-is-output=", testTrancheSpaceOrderConfig.amountIsOutput.toString());
        ffi[39] = "--bind";
        ffi[40] = "get-last-tranche='get-test-last-tranche";
        ffi[41] = "--bind";
        ffi[42] = "set-last-tranche='set-test-last-tranche";
        ffi[43] = "--bind";
        ffi[44] = "io-ratio-multiplier='io-ratio-multiplier-identity";
        ffi[45] = "--bind";
        ffi[46] =
            string.concat("test-tranche-space-before=", testTrancheSpaceOrderConfig.testTrancheSpaceBefore.toString());
        ffi[47] = "--bind";
        ffi[48] = string.concat("test-last-update-time=", testTrancheSpaceOrderConfig.testLastTimeUpdate.toString());
        ffi[49] = "--bind";
        ffi[50] = string.concat("test-now=", testTrancheSpaceOrderConfig.testNow.toString());

        testTrancheSpaceOrder = bytes.concat(getSubparserPrelude(orderBookSubparser), vm.ffi(ffi));
    }

    function getCalculateTranche(
        Vm vm,
        address orderBookSubparser,
        uint256 testTrancheSpaceBefore,
        uint256 testLastTimeUpdate,
        uint256 testNow
    ) internal returns (bytes memory calculateTranche) {
        string[] memory ffi = new string[](25);
        ffi[0] = "rain";
        ffi[1] = "dotrain";
        ffi[2] = "compose";
        ffi[3] = "-i";
        ffi[4] = "src/tranche-space.rain";
        ffi[5] = "--entrypoint";
        ffi[6] = "calculate-tranche";
        ffi[7] = "--bind";
        ffi[8] = string.concat("tranche-space-per-second=", TRANCHE_SPACE_PER_SECOND.toString());
        ffi[9] = "--bind";
        ffi[10] = string.concat("tranche-space-recharge-delay=", TRANCHE_SPACE_RECHARGE_DELAY.toString());
        ffi[11] = "--bind";
        ffi[12] = "tranche-size-expr='constant-growth";
        ffi[13] = "--bind";
        ffi[14] = string.concat("tranche-size-base=", TRANCHE_SIZE_BASE.toString());
        ffi[15] = "--bind";
        ffi[16] = string.concat("tranche-size-growth=", TRANCHE_SIZE_GROWTH.toString());
        ffi[17] = "--bind";
        ffi[18] = "get-last-tranche='get-test-last-tranche";
        ffi[19] = "--bind";
        ffi[20] = string.concat("test-tranche-space-before=", testTrancheSpaceBefore.toString());
        ffi[21] = "--bind";
        ffi[22] = string.concat("test-last-update-time=", testLastTimeUpdate.toString());
        ffi[23] = "--bind";
        ffi[24] = string.concat("test-now=", testNow.toString());

        calculateTranche = bytes.concat(getSubparserPrelude(orderBookSubparser), vm.ffi(ffi));
    }

    function getHandleIo(
        Vm vm,
        address orderBookSubparser,
        uint256 testTrancheSpaceBefore,
        uint256 testLastTimeUpdate,
        uint256 testNow
    ) internal returns (bytes memory calculateTranche) {
        string[] memory ffi = new string[](33);
        ffi[0] = "rain";
        ffi[1] = "dotrain";
        ffi[2] = "compose";
        ffi[3] = "-i";
        ffi[4] = "src/tranche-space.rain";
        ffi[5] = "--entrypoint";
        ffi[6] = "handle-io";
        ffi[7] = "--bind";
        ffi[8] = string.concat("tranche-space-per-second=", TRANCHE_SPACE_PER_SECOND.toString());
        ffi[9] = "--bind";
        ffi[10] = string.concat("tranche-space-recharge-delay=", TRANCHE_SPACE_RECHARGE_DELAY.toString());
        ffi[11] = "--bind";
        ffi[12] = "tranche-size-expr='constant-growth";
        ffi[13] = "--bind";
        ffi[14] = string.concat("tranche-size-base=", TRANCHE_SIZE_BASE.toString());
        ffi[15] = "--bind";
        ffi[16] = string.concat("tranche-size-growth=", TRANCHE_SIZE_GROWTH.toString());
        ffi[17] = "--bind";
        ffi[18] = string.concat("min-tranche-space-diff=", MIN_TRANCHE_SPACE_DIFF.toString());
        ffi[19] = "--bind";
        ffi[20] = string.concat("tranche-space-snap-threshold=", TRANCHE_SNAP_THRESHOLD.toString());
        ffi[21] = "--bind";
        ffi[22] = "get-last-tranche='get-test-last-tranche";
        ffi[23] = "--bind";
        ffi[24] = "set-last-tranche='set-test-last-tranche";
        ffi[25] = "--bind";
        ffi[26] = string.concat("test-tranche-space-before=", testTrancheSpaceBefore.toString());
        ffi[27] = "--bind";
        ffi[28] = string.concat("test-last-update-time=", testLastTimeUpdate.toString());
        ffi[29] = "--bind";
        ffi[30] = string.concat("test-now=", testNow.toString());
        ffi[31] = "--bind";
        ffi[32] = string.concat("amount-is-output=", AMOUNT_IS_OUTPUT.toString());

        calculateTranche = bytes.concat(getSubparserPrelude(orderBookSubparser), vm.ffi(ffi));
    }

    function getSubparserPrelude(address obSubparser) internal pure returns (bytes memory) {
        bytes memory RAINSTRING_OB_SUBPARSER = bytes(string.concat("using-words-from ", obSubparser.toHexString(), " "));
        return RAINSTRING_OB_SUBPARSER;
    }
}
