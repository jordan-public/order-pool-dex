// SPDX-License-Identifier: BUSL-1.1
import React from 'react';
import { Button, ButtonGroup } from 'react-bootstrap';
import 'bootstrap/dist/css/bootstrap.css'; 
import { ethers } from 'ethers';
import aOrderPoolFactory from '../artifacts/OrderPoolFactory.json';
import aIOrderPool from '../artifacts/IOrderPool.json';
import aERC20 from '../artifacts/ERC20.json';

function SideBar({provider,  address, setPair}) {
    const [pairList, setPairList] = React.useState([]);

    const getPair = async (cIOrderPool) => {
        const signer = provider.getSigner();
        const tokenAAddress = await cIOrderPool.tokenA();
        const cTokenA = new ethers.Contract(tokenAAddress, aERC20.abi, signer);
        const tokenASymbol = await cTokenA.symbol();
        const tokenBAddress = await cIOrderPool.tokenB();
        const cTokenB = new ethers.Contract(tokenBAddress, aERC20.abi, signer);
        const tokenBSymbol = await cTokenB.symbol();
        return {SymbolA: tokenASymbol, SymbolB: tokenBSymbol, pair: cIOrderPool.address};
    }

    React.useEffect(() => {
        (async () => {
            if (!provider) return;
            const signer = provider.getSigner();
            const cOrderPoolFactory = new ethers.Contract(aOrderPoolFactory.contractAddress, aOrderPoolFactory.abi, signer);
            const numPairs = (await cOrderPoolFactory.getNumPairs()).toNumber();
            let p = [];
            for (let i=0; i<numPairs; i++) {
                const pairContractAddress = await cOrderPoolFactory.getPair(i);
                const cIOrderPool = new ethers.Contract(pairContractAddress, aIOrderPool.abi, signer);
                p.push(await getPair(cIOrderPool));
                const cIReverseOrderPool = new ethers.Contract(await cIOrderPool.reversePool(), aIOrderPool.abi, signer);
                p.push(await getPair(cIReverseOrderPool));
            } 
            setPairList(p);
        }) ();
    }, [provider, address]); // On load

    if (!provider) return;
    return (<div className="d-grid gap-2">
        <br/>
        {pairList.map((p) => <Button key={p.pair} size="sm" onClick={()=>setPair(p)}>{p.SymbolA}/{p.SymbolB}</Button>)}
    </div>);
}

export default SideBar;