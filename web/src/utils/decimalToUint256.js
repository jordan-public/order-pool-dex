// SPDX-License-Identifier: BUSL-1.1
import BigNumber from 'bignumber.js';

export default function decimalToUint256(d, decimals) {
    if (decimals === null) return "";
    let bd = new BigNumber(d);
    bd = bd.multipliedBy(new BigNumber(10).exponentiatedBy(new BigNumber(decimals)));
    bd = bd.integerValue();
    BigNumber.config({ EXPONENTIAL_AT: 256 })
//console.log("decimalToUint256", d, decimals, bd.toString());
    return bd.toString();
}