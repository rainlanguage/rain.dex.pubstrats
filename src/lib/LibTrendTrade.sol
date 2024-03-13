// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.19;

import {Vm} from "forge-std/Vm.sol";
import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";

library LibTrendTrade {
    using Strings for address;
    using Strings for uint256;

    struct TrendTradeTest {
        address reserveToken;
        uint256 reserveDecimals;
        uint256 testLastTime;
        uint256 testNow;
        uint256 jitteryBinomialBits;
        uint256 meanCooldown;
        uint256 testTrendRatioValue;
        uint256 meanReserveAmount18;
        uint256 trendUpFactor;
        uint256 trendDownFactor;
        uint256 bounty;
    }

    struct TrendTrade {
        address reserveToken;
        uint256 reserveDecimals;
        uint256 jitteryBinomialBits;
        uint256 meanCooldown;
        uint256 twapTrendRatioLongTime;
        uint256 twapTrendRatioShortTime;
        uint256 twapTrendRatioFee;
        uint256 meanReserveAmount18;
        uint256 trendUpFactor;
        uint256 trendDownFactor;
        uint256 bounty;
    }

    function getTestTrendOrder(
        Vm vm,
        TrendTradeTest memory tradeTestConifg,
        address orderBookSubparser,
        address uniswapSubparser
    ) internal returns (bytes memory testTrend) {
        string[] memory ffi = new string[](35);
        ffi[0] = "rain";
        ffi[1] = "dotrain";
        ffi[2] = "compose";
        ffi[3] = "-i";
        ffi[4] = "src/trend-trader.rain";
        ffi[5] = "--entrypoint";
        ffi[6] = "calculate-io";
        ffi[7] = "--entrypoint";
        ffi[8] = "handle-io";
        ffi[9] = "--bind";
        ffi[10] = string.concat("reserve-token=", tradeTestConifg.reserveToken.toHexString());
        ffi[11] = "--bind";
        ffi[12] = string.concat("reserve-decimals=", tradeTestConifg.reserveDecimals.toString());
        ffi[13] = "--bind";
        ffi[14] = string.concat("times='constant-times");
        ffi[15] = "--bind";
        ffi[16] = string.concat("jittery-binomial-bits=", tradeTestConifg.jitteryBinomialBits.toString());
        ffi[17] = "--bind";
        ffi[18] = string.concat("mean-cooldown=", tradeTestConifg.meanCooldown.toString());
        ffi[19] = "--bind";
        ffi[20] = string.concat("trend-ratio-exp='constant-trend-ratio");
        ffi[21] = "--bind";
        ffi[22] = string.concat("constant-trend-ratio-value=", tradeTestConifg.testTrendRatioValue.toString());
        ffi[23] = "--bind";
        ffi[24] = string.concat("mean-reserve-amount18=", tradeTestConifg.meanReserveAmount18.toString());
        ffi[25] = "--bind";
        ffi[26] = string.concat("trend-up-factor=", tradeTestConifg.trendUpFactor.toString());
        ffi[27] = "--bind";
        ffi[28] = string.concat("trend-down-factor=", tradeTestConifg.trendDownFactor.toString());
        ffi[29] = "--bind";
        ffi[30] = string.concat("bounty=", tradeTestConifg.bounty.toString());
        ffi[31] = "--bind";
        ffi[32] = string.concat("constant-last-time=", tradeTestConifg.testLastTime.toString());
        ffi[33] = "--bind";
        ffi[34] = string.concat("constant-now=", tradeTestConifg.testNow.toString());

        testTrend = bytes.concat(getSubparserPrelude(orderBookSubparser, uniswapSubparser), vm.ffi(ffi));
    }

    function getTrendOrder(
        Vm vm,
        TrendTrade memory trendOrderConfig,
        address orderBookSubparser,
        address uniswapSubparser
    ) internal returns (bytes memory trendOrder) {
        string[] memory ffi = new string[](35);
        ffi[0] = "rain";
        ffi[1] = "dotrain";
        ffi[2] = "compose";
        ffi[3] = "-i";
        ffi[4] = "src/trend-trader.rain";
        ffi[5] = "--entrypoint";
        ffi[6] = "calculate-io";
        ffi[7] = "--entrypoint";
        ffi[8] = "handle-io";
        ffi[9] = "--bind";
        ffi[10] = string.concat("reserve-token=", trendOrderConfig.reserveToken.toHexString());
        ffi[11] = "--bind";
        ffi[12] = string.concat("reserve-decimals=", trendOrderConfig.reserveDecimals.toString());
        ffi[13] = "--bind";
        ffi[14] = string.concat("times='real-times");
        ffi[15] = "--bind";
        ffi[16] = string.concat("jittery-binomial-bits=", trendOrderConfig.jitteryBinomialBits.toString());
        ffi[17] = "--bind";
        ffi[18] = string.concat("mean-cooldown=", trendOrderConfig.meanCooldown.toString());
        ffi[19] = "--bind";
        ffi[20] = string.concat("trend-ratio-exp='uni-v3-twap-trend-ratio");
        ffi[21] = "--bind";
        ffi[22] = string.concat("twap-trend-ratio-long-time=", trendOrderConfig.twapTrendRatioLongTime.toString());
        ffi[23] = "--bind";
        ffi[24] = string.concat("twap-trend-ratio-short-time=", trendOrderConfig.twapTrendRatioShortTime.toString());
        ffi[25] = "--bind";
        ffi[26] = string.concat("twap-trend-ratio-fee=", trendOrderConfig.twapTrendRatioFee.toString());
        ffi[27] = "--bind";
        ffi[28] = string.concat("mean-reserve-amount18=", trendOrderConfig.meanReserveAmount18.toString());
        ffi[29] = "--bind";
        ffi[30] = string.concat("trend-up-factor=", trendOrderConfig.trendUpFactor.toString());
        ffi[31] = "--bind";
        ffi[32] = string.concat("trend-down-factor=", trendOrderConfig.trendDownFactor.toString());
        ffi[33] = "--bind";
        ffi[34] = string.concat("bounty=", trendOrderConfig.bounty.toString());

        trendOrder = bytes.concat(getSubparserPrelude(orderBookSubparser, uniswapSubparser), vm.ffi(ffi));
    }

    function getTwapTrendSource(
        Vm vm,
        address orderBookSubparser,
        address uniswapSubparser,
        uint256 twapTrendRatioLongTime,
        uint256 twapTrendRatioShortTime,
        uint256 twapTrendRatioFee
    ) internal returns (bytes memory twapSources) {
        string[] memory ffi = new string[](15);
        ffi[0] = "rain";
        ffi[1] = "dotrain";
        ffi[2] = "compose";
        ffi[3] = "-i";
        ffi[4] = "src/trend-trader.rain";
        ffi[5] = "--entrypoint";
        ffi[6] = "uni-v3-twap-trend-ratio";
        ffi[7] = "--bind";
        ffi[8] = string.concat("twap-trend-ratio-long-time=", twapTrendRatioLongTime.toString());
        ffi[9] = "--bind";
        ffi[10] = string.concat("twap-trend-ratio-short-time=", twapTrendRatioShortTime.toString());
        ffi[11] = "--bind";
        ffi[12] = string.concat("twap-trend-ratio-fee=", twapTrendRatioFee.toString());
        ffi[13] = "--bind";
        ffi[14] = string.concat("times='real-times");

        twapSources = bytes.concat(getSubparserPrelude(orderBookSubparser, uniswapSubparser), vm.ffi(ffi));
    }

    function getEnsureCooldownSource(
        Vm vm,
        address orderBookSubparser,
        address uniswapSubparser,
        uint256 meanCooldown,
        uint256 jitteryBinomialBits
    ) internal returns (bytes memory twapSources) {
        string[] memory ffi = new string[](11);
        ffi[0] = "rain";
        ffi[1] = "dotrain";
        ffi[2] = "compose";
        ffi[3] = "-i";
        ffi[4] = "src/trend-trader.rain";
        ffi[5] = "--entrypoint";
        ffi[6] = "ensure-cooldown";
        ffi[7] = "--bind";
        ffi[8] = string.concat("mean-cooldown=", meanCooldown.toString());
        ffi[9] = "--bind";
        ffi[10] = string.concat("jittery-binomial-bits=", jitteryBinomialBits.toString());

        twapSources = bytes.concat(getSubparserPrelude(orderBookSubparser, uniswapSubparser), vm.ffi(ffi));
    }

    function getHandleIo(Vm vm, address orderBookSubparser, address uniswapSubparser)
        internal
        returns (bytes memory twapSources)
    {
        string[] memory ffi = new string[](7);
        ffi[0] = "rain";
        ffi[1] = "dotrain";
        ffi[2] = "compose";
        ffi[3] = "-i";
        ffi[4] = "src/trend-trader.rain";
        ffi[5] = "--entrypoint";
        ffi[6] = "handle-io";

        twapSources = bytes.concat(getSubparserPrelude(orderBookSubparser, uniswapSubparser), vm.ffi(ffi));
    }

    function getSubparserPrelude(address obSubparser, address uniswapWords) internal pure returns (bytes memory) {
        bytes memory RAINSTRING_OB_SUBPARSER =
            bytes(string.concat("using-words-from ", obSubparser.toHexString(), " ", uniswapWords.toHexString(), " "));
        return RAINSTRING_OB_SUBPARSER;
    }
}
