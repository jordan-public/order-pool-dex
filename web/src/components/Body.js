// SPDX-License-Identifier: BUSL-1.1
import React from 'react';
import { Form, Accordion } from 'react-bootstrap';
import 'bootstrap/dist/css/bootstrap.css'; 
import { BigNumber, ethers } from 'ethers';
import aIOrderPool from '../artifacts/IOrderPool.json';
import aERC20 from '../artifacts/ERC20.json';
import uint256ToDecimal from '../utils/uint256ToDecimal';

function Body({provider, address, pair}) {
    const [orderPool, setOrderPool] = React.useState(null);
    const [reverseOrderPool, setReverseOrderPool] = React.useState(null);
    const [tokenA, setTokenA] = React.useState(null);
    const [tokenB, setTokenB] = React.useState(null);
    const [tokenADecimals, setTokenADecimals] = React.useState(null);
    const [tokenBDecimals, setTokenBDecimals] = React.useState(null);
    const [priceAB, setPriceAB] = React.useState("");
    const [priceBA, setPriceBA] = React.useState("");

    React.useEffect(() => {
        (async () => {
            if (!provider || !pair) return;console.log("UE1 - ok")
            const signer = provider.getSigner();
            const p = new ethers.Contract(pair.pair, aIOrderPool.abi, signer);
            setOrderPool(p);
            const r = new ethers.Contract(await p.reversePool(), aIOrderPool.abi, signer);
            setReverseOrderPool(r);
            const cTokenA = new ethers.Contract(await p.tokenA(), aERC20.abi, signer);
            setTokenA(cTokenA);
            const cTokenB = new ethers.Contract(await p.tokenB(), aERC20.abi, signer);
            setTokenA(cTokenB);
            const tokenADec = await cTokenA.decimals();
            setTokenADecimals(tokenADec);
            const tokenBDec = await cTokenB.decimals();
            setTokenBDecimals(tokenBDec);
            await doUpdate(p, r, tokenADec, tokenBDec);
          }) ();
    }, [provider, address, pair]); // On load

    const doUpdate = async (p, r, tokenADec, tokenBDec) => {
        if (!tokenADec || !tokenBDec) return;
        const oneA = BigNumber.from(10).pow(BigNumber.from(tokenADec));
        const oneB = BigNumber.from(10).pow(BigNumber.from(tokenBDec));
        setPriceAB(uint256ToDecimal(await p.convert(oneA), tokenBDec));
        setPriceBA(uint256ToDecimal(await r.convert(oneB), tokenADec));
    }

    const onUpdate = async (blockNumber) => {console.log(blockNumber, tokenADecimals, tokenBDecimals);
        await doUpdate(orderPool, reverseOrderPool, tokenADecimals, tokenBDecimals);    console.log("NB Update ok");
    }

    React.useEffect(() => {
        if (provider) {
            provider.on("block", onUpdate);
            return () => provider.off("block");
        }
    }); // Run on each render because onUpdate is a closure

    if (!provider || !pair) return(<></>);
    return (<>
        {pair.SymbolA}/{pair.SymbolB}: {pair.pair}
        <br/>
        Price: {priceAB} = 1/{priceBA}
        <br/>
        TD: {tokenADecimals}, {tokenBDecimals}
    </>);
}

export default Body;