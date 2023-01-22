// SPDX-License-Identifier: BUSL-1.1
import React from 'react';
import { Accordion } from 'react-bootstrap';
import 'bootstrap/dist/css/bootstrap.css'; 
import { BigNumber, ethers } from 'ethers';
import aIOrderPool from '../artifacts/IOrderPool.json';
import aERC20 from '../artifacts/ERC20.json';
import uint256ToDecimal from '../utils/uint256ToDecimal';
import decimalToUint256 from '../utils/decimalToUint256';
import OrderDetails from './OrderDetails';

function OrderList({provider, address, pair, orderPool, reverseOrderPool, tokenA, tokenB, tokenADecimals, tokenBDecimals}) {
    const [orders, setOrders] = React.useState([]);
    const [ordersRev, setOrdersRev] = React.useState([]);

    React.useEffect(() => {
        (async () => {
            await doUpdate();
        }) ();
    }, [provider, address, pair,  orderPool, reverseOrderPool, tokenA, tokenB, tokenADecimals, tokenBDecimals]); // On load

    const doUpdate = async () => {
        if (!orderPool || !reverseOrderPool) return;
        const numOrd = await orderPool.numOrdersOwned();
        const numOrdRev = await reverseOrderPool.numOrdersOwned();
        let o = [];
        let ro = [];
        for (let i=0; i<numOrd; i++) {
            o.push(await orderPool.getOrderId(i));
        }
        setOrders(o);
        for (let i=0; i<numOrdRev; i++) {
            ro.push(await reverseOrderPool.getOrderId(i));
        }
        setOrdersRev(ro);
    }

    const onUpdate = async (blockNumber) => {
console.log("Block ", blockNumber);
        await doUpdate();
    }

    React.useEffect(() => {
console.log("Provider: ", provider);
        if (provider) {
console.log("On activated");
            provider.on("block", onUpdate);
            return () => provider.off("block", onUpdate);
        }
    }); // Run on each render because onUpdate is a closure

    if (!provider || !pair ) return <></>;
    return <>
        <Accordion>
        {orders.map((o)=><OrderDetails key={o} provider={provider} address={address} pair={pair}
                            orderPool={orderPool} reverseOrderPool={reverseOrderPool}
                            tokenA={tokenA} tokenB={tokenB} tokenADecimals={tokenADecimals} tokenBDecimals={tokenBDecimals} 
                            orderId={o} isReverse={false} keyNum={o}/>)}
        {ordersRev.map((o)=><OrderDetails key={o} provider={provider} address={address} pair={pair}
                            orderPool={orderPool} reverseOrderPool={reverseOrderPool}
                            tokenA={tokenA} tokenB={tokenB} tokenADecimals={tokenADecimals} tokenBDecimals={tokenBDecimals} 
                            orderId={o} isReverse={true} keyNum={o+orders.length} />)}
        </Accordion>
     </>;
}

export default OrderList;