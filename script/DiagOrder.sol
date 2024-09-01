// SPDX-License-Identifier: CAL
pragma solidity >=0.6.0;

import {Script} from "forge-std/Script.sol"; // put the path to forge-std/Script.sol

contract DiagOrder is Script {
    function run() external {
        address to = 0x3cC2ebbfc66cE846AFE6949248d0a54d1F903A25; // put arb contract address
        bytes memory data = hex"7ea0b76a000000000000000000000000d2938e7c9fe3597f78832ce780feb61945c377d700000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000d00000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000038d7ea4c68000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff00000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000ba0000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000aa00000000000000000000000007c172bd11a77532ca4e29006d755ad72c5781a0500000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000086000000000000000000000000000000000000000000000000000000000000009408c5e59e0b24eec6b1061208815f1f9ca427a29498aff1a3af3d2f59b2a9baf92000000000000000000000000fa4989f5d49197fd9673ce4b7fe2a045a0f2f9c8000000000000000000000000783b82f0fbf6743882072ae2393b108f5938898b0000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000072300000000000000000000000000000000000000000000000000000000000000120000000000000000000000000000000000000000000000000de0b6b3a76400000000000000000000000000000000000000000000000000000001c6bf5263400000000000000000000000000000000000000000000000000000038d7ea4c68000000000000000000000000000000000000000000000000000002386f26fc100000000000000000000000000000000000000000000000000000c7d713b49da0000000000000000000000000000000000000000000000000000016345785d8a00009b4d696e696d756d2074726164652073697a65206e6f74206d65742e0000000000000000000000000000000000000000000000000000001043561a882930000000000000000000000000000000000000000000000000124bc0ddd92e560000000000000000000000000000000000000000000000000000008ac7230489e80000000000000000000000000000000000000000000000000000000000000000000084656c73650000000000000000000000000000000000000000000000000000008d6c6173742d696f2d726174696f00000000000000000000000000000000000000000000000000000000000000000000000000000000008670e9ec6598c00000976c6173742d74726164652d6f75747075742d746f6b656e0000000000000000000000000000000000000000833589fcd6edb6e08f4c7c32d4f71b54bda029138f6c6173742d74726164652d74696d65000000000000000000000000000000008d7472616e6368652d737061636500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004a30f00000074010001580208024c02600270029c02a002c003200440045c047c1c0b00090b3000020b1000040b1000031b12000001100001011000002b120000001000033d1200000010000001100002001000040b13000500100001001000023d12000000100005001000062e120000001000060b1000062213000000100005001000080b01000700100008001000070b020008220c00090b40000203100403031004040b1000062213000000100003001000042e12000000100005001000002b1200000010000601100003451200000010000701100004001000072b120000001000073311000023110000221300000110000601100005001000002b12000000100007211200001d0200000b00000900100005001000080b02000a0b00000b150b00090b10000c0b20000d01100007001000022b120000001000014812000101100008001000032e12000000100004001000004812000100100005321100000010000535110000001000060110000a011000090b13000e2b0b0005031000030310000403100003031000010c14000049110000031000040310000403100003031000010c14000049110000031000030310000303100004031000010c14000049110000031000040310000303100004031000010c140000491100000110000a0110000b01100000001000031b120000001000022e12000000100003001000021f12000001100000001000011b120000001000002e12000000100001001000001f1200001c160000100500020110000d0110000c031000010c120000491100001b1200000010000036110000001000000110000e031000010c12000049110000031000041e12000022130000040603040010000200100001001000002613000003020001031000040110000f1e1200000a040101031000040110000e031000010c1200004a020000001000000110000c031000010c1200004a02000000020202070500001a100000011000100310000403100003031000010c1400004a02000017090204011000110310000303100004031000010c1400004911000000100001001000024812000100100000011000110310000403100003031000010c1400004a02000000100003011000110310000303100004031000010c1400004a020000470f000d031000040310000303100004031000010c140000031000030310000303100004031000010c1400000010000049110000001000014911000003100404001000023b12000000100004001000024712000000100005001000004a02000018100000001000041b12000000100002001000033d1200002e120000001000041f120000001000060010000347120000001000051f120000001000014a020000031000030310000403100003031000010c140000031000040310000403100003031000010c140000001000074911000000100008491100000010000403100404471200000010000603100403471200000010000c001000092b120000001000074a0200000010000b0010000a2b1200000010000c1f120000001000084a02000006040001011000110310000403100003031000010c14000049110000070500021a100000011000100310000403100003031000010c14000049110000010403040010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002000000000000000000000000833589fcd6edb6e08f4c7c32d4f71b54bda029130000000000000000000000000000000000000000000000000000000000000006086f2e7609aa033b3754c948b014141af8ef9a636ef687fba5a65cee1d61b15400000000000000000000000042000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000012086f2e7609aa033b3754c948b014141af8ef9a636ef687fba5a65cee1d61b1540000000000000000000000000000000000000000000000000000000000000002000000000000000000000000833589fcd6edb6e08f4c7c32d4f71b54bda029130000000000000000000000000000000000000000000000000000000000000006086f2e7609aa033b3754c948b014141af8ef9a636ef687fba5a65cee1d61b15400000000000000000000000042000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000012086f2e7609aa033b3754c948b014141af8ef9a636ef687fba5a65cee1d61b154000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000e00000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000008702420000000000000000000000000000000000000601ffff000feb1490f80b6978002c3e501753562f2f2853b2010389879e0156033202c44bf784ac18fc02edee4f0009c40150c5725949a6f0c72e6c4a641f24049a917db0cb01ffff013bd740dc10864f35001aab7771c56a85c48c901b013cc2ebbfc66ce846afe6949248d0a54d1f903a2500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000c0000000000000000000000000fa4989f5d49197fd9673ce4b7fe2a045a0f2f9c8000000000000000000000000783b82f0fbf6743882072ae2393b108f5938898b000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"; // put calldata here without 0x
        (bool success, bytes memory result) = to.call(data);
        (success, result);
    }
}