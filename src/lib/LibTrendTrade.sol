// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.19;

import {Vm} from "forge-std/Vm.sol";
import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";

library LibTrendTrade {

    using Strings for address;
    using Strings for uint256; 

    struct TrendTradeTest {
        address orderBookSubparser;
        address uniswapSubparser;
        uint256 testMeanReserveAmount18;
        uint256 testLastTime;
        uint256 testNow;
        uint256 testTrendNumerator;
        uint256 testTrendDenominator;
        uint256 testTrendUpFactor;
        uint256 testTrendDownFactor;
        uint256 cooldown;
        uint256 jitteryBinomialBits;
    } 

    struct TrendTrade {
        address orderBookSubparser;
        address uniswapSubparser;
        address tokenAddress;
        uint256 tokenDecimals;
        address reserveToken;
        uint256 reserveDecimals;
        uint256 meanAmount;
        uint256 cooldown;
        uint256 bounty;
        uint256 jitteryBinomialBits;
        uint256 twapLongTime;
        uint256 twapShortTime;
        uint256 trendUpFactor;
        uint256 trendDownFactor;
    }

    function getTestTrendOrder(
        Vm vm,
        TrendTradeTest memory tradeTest
    ) internal returns (bytes memory testTrend){

        string[] memory ffi = new string[](35);
        ffi[0] = "rain";
        ffi[1] = "dotrain";
        ffi[2] = "compose";
        ffi[3] = "-i";
        ffi[4] = "src/trend-trader.rain";
        ffi[5] = "--entrypoint";
        ffi[6] = "test-calculate-io";
        ffi[7] = "--entrypoint";
        ffi[8] = "test-handle-io"; 
        ffi[9] = "--bind";
        ffi[10] = string.concat("tkn-address=0x692AC1e363ae34b6B489148152b12e2785a3d8d6");
        ffi[11] = "--bind";
        ffi[12] = string.concat("tkn-decimals=18");
        ffi[13] = "--bind";
        ffi[14] = string.concat("reserve-address=0xc2132D05D31c914a87C6611C10748AEb04B58e8F");
        ffi[15] = "--bind";
        ffi[16] = string.concat("reserve-decimals=6");
        ffi[17] = "--bind";
        ffi[18] = string.concat("test-mean-reserve-amount18=", tradeTest.testMeanReserveAmount18.toString());
        ffi[19] = "--bind";
        ffi[20] = string.concat("test-last-time=", tradeTest.testLastTime.toString());
        ffi[21] = "--bind";
        ffi[22] = string.concat("test-now=", tradeTest.testNow.toHexString());
        ffi[23] = "--bind";
        ffi[24] = string.concat("test-trend-numerator=", tradeTest.testTrendNumerator.toString());
        ffi[25] = "--bind";
        ffi[26] = string.concat("test-trend-denominator=", tradeTest.testTrendDenominator.toString());
        ffi[27] = "--bind";
        ffi[28] = string.concat("test-trend-up-factor=", tradeTest.testTrendUpFactor.toString());
        ffi[29] = "--bind";
        ffi[30] = string.concat("test-trend-down-factor=", tradeTest.testTrendDownFactor.toString());
        ffi[31] = "--bind";
        ffi[32] = string.concat("mean-cooldown=", tradeTest.cooldown.toString());
        ffi[33] = "--bind";
        ffi[34] = string.concat("jittery-binomial-bits=", tradeTest.jitteryBinomialBits.toString());

        testTrend = bytes.concat(getSubparserPrelude(tradeTest.orderBookSubparser,tradeTest.uniswapSubparser), vm.ffi(ffi));

    }

    function getTrendBuyOrder(
        Vm vm,
        TrendTrade memory buyTrend
    )
        internal
        returns (bytes memory buyOrder)
    {
        string[] memory ffi = new string[](33);
        ffi[0] = "rain";
        ffi[1] = "dotrain";
        ffi[2] = "compose";
        ffi[3] = "-i";
        ffi[4] = "src/trend-trader.rain";
        ffi[5] = "--entrypoint";
        ffi[6] = "buy-calculate-io";
        ffi[7] = "--entrypoint";
        ffi[8] = "buy-handle-io";
        ffi[9] = "--bind";
        ffi[10] = string.concat("tkn-address=",buyTrend.tokenAddress.toHexString());
        ffi[11] = "--bind";
        ffi[12] = string.concat("tkn-decimals=",buyTrend.tokenDecimals.toString());
        ffi[13] = "--bind";
        ffi[14] = string.concat("reserve-address=",buyTrend.reserveToken.toHexString());
        ffi[15] = "--bind";
        ffi[16] = string.concat("reserve-decimals=",buyTrend.reserveDecimals.toString());
        ffi[17] = "--bind";
        ffi[18] = string.concat("buy-mean-reserve-amount18=", buyTrend.meanAmount.toString());
        ffi[19] = "--bind";
        ffi[20] = string.concat("mean-cooldown=", buyTrend.cooldown.toString());
        ffi[21] = "--bind";
        ffi[22] = string.concat("bounty=", buyTrend.bounty.toString());
        ffi[23] = "--bind";
        ffi[24] = string.concat("jittery-binomial-bits=", buyTrend.jitteryBinomialBits.toString());
        ffi[25] = "--bind";
        ffi[26] = string.concat("twap-long-time=", buyTrend.twapLongTime.toString());
        ffi[27] = "--bind";
        ffi[28] = string.concat("twap-short-time=", buyTrend.twapShortTime.toString());
        ffi[29] = "--bind";
        ffi[30] = string.concat("buy-trend-up-factor=", buyTrend.trendUpFactor.toString());
        ffi[31] = "--bind";
        ffi[32] = string.concat("buy-trend-down-factor=", buyTrend.trendDownFactor.toString());
        
        buyOrder = bytes.concat(getSubparserPrelude(buyTrend.orderBookSubparser,buyTrend.uniswapSubparser), vm.ffi(ffi));
    }

    function getTrendSellOrder(
        Vm vm,
        TrendTrade memory sellTrend
    )
        internal
        returns (bytes memory sellOrder)
    {
        string[] memory ffi = new string[](33);
        ffi[0] = "rain";
        ffi[1] = "dotrain";
        ffi[2] = "compose";
        ffi[3] = "-i";
        ffi[4] = "src/trend-trader.rain";
        ffi[5] = "--entrypoint";
        ffi[6] = "sell-calculate-io";
        ffi[7] = "--entrypoint";
        ffi[8] = "sell-handle-io";
        ffi[9] = "--bind";
        ffi[10] = string.concat("tkn-address=",sellTrend.tokenAddress.toHexString());
        ffi[11] = "--bind";
        ffi[12] = string.concat("tkn-decimals=",sellTrend.tokenDecimals.toString());
        ffi[13] = "--bind";
        ffi[14] = string.concat("reserve-address=",sellTrend.reserveToken.toHexString());
        ffi[15] = "--bind";
        ffi[16] = string.concat("reserve-decimals=",sellTrend.reserveDecimals.toString());
        ffi[17] = "--bind";
        ffi[18] = string.concat("sell-mean-reserve-amount18=", sellTrend.meanAmount.toString());
        ffi[19] = "--bind";
        ffi[20] = string.concat("mean-cooldown=", sellTrend.cooldown.toString());
        ffi[21] = "--bind";
        ffi[22] = string.concat("bounty=", sellTrend.bounty.toString());
        ffi[23] = "--bind";
        ffi[24] = string.concat("jittery-binomial-bits=", sellTrend.jitteryBinomialBits.toString());
        ffi[25] = "--bind";
        ffi[26] = string.concat("twap-long-time=", sellTrend.twapLongTime.toString());
        ffi[27] = "--bind";
        ffi[28] = string.concat("twap-short-time=", sellTrend.twapShortTime.toString());
        ffi[29] = "--bind";
        ffi[30] = string.concat("sell-trend-up-factor=", sellTrend.trendUpFactor.toString());
        ffi[31] = "--bind";
        ffi[32] = string.concat("sell-trend-down-factor=", sellTrend.trendDownFactor.toString());
        
        sellOrder = bytes.concat(getSubparserPrelude(sellTrend.orderBookSubparser,sellTrend.uniswapSubparser), vm.ffi(ffi));
    }

    function getSubparserPrelude(address obSubparser, address uniswapWords) internal pure returns (bytes memory) {
        bytes memory RAINSTRING_OB_SUBPARSER = bytes(
            string.concat(
                "using-words-from ", obSubparser.toHexString(), " ", uniswapWords.toHexString(), " "
            )
        );
        return RAINSTRING_OB_SUBPARSER;
    }

}