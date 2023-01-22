// SPDX-License-Identifier: BUSL-1.1
import React from 'react';
import { Accordion, Form, InputGroup, Button, Spinner } from 'react-bootstrap';
import 'bootstrap/dist/css/bootstrap.css'; 
import { BigNumber } from 'ethers';
import uint256ToDecimal from '../utils/uint256ToDecimal';

function OrderDetails({provider, address, pair, orderPool, reverseOrderPool, tokenA, tokenB, tokenADecimals, tokenBDecimals, orderId, isReverse, keyNum}) {
    const [orderStatus, setOrderStatus] = React.useState(null);

    React.useEffect(() => {
        (async () => {
            await doUpdate();
        }) ();
    }, [provider, address, pair, orderPool, reverseOrderPool, orderId, isReverse]); // On load

    const doUpdate = async () => {
        setOrderStatus(!isReverse ? await orderPool.orderStatus(orderId) : await reverseOrderPool.orderStatus(orderId));
    }

    const onUpdate = async (blockNumber) => {
console.log("Block ", blockNumber);
        await doUpdate();
    }

    React.useEffect(() => {
        if (provider) {
            provider.on("block", onUpdate);
            return () => provider.off("block", onUpdate);
        }
    }); // Run on each render because onUpdate is a closure

    const onWithdraw = async () => {
        if (!orderStatus) return;
        try {
            const tx = (!isReverse)? 
                await orderPool.withdraw(orderStatus.rangeIndex):
                await reverseOrderPool.withdraw(orderStatus.rangeIndex);

            const r = await tx.wait();
            await doUpdate();
            window.alert('Completed. Block hash: ' + r.blockHash);        
        } catch(e) {
            console.log("Error: ", e);
            window.alert(e.message + "\n" + (e.data?e.data.message:""));
            return;
        }
    }

    return (
        <Accordion.Item eventKey={keyNum.toString()} >
            <Accordion.Header>OrderID: {orderId.toString()} {isReverse ? "Reverse" : ""}</Accordion.Header>
            <Accordion.Body> <Form>
                {orderStatus && orderStatus.remainingA.gt(BigNumber.from(0)) && <>
                    <Spinner animation="border" variant="primary" />
                    <>
                        <br/>
                        Pool:
                        <br/>
                        Remaining unexecuted amount of {!isReverse ? pair.SymbolA : pair.SymbolB}: 
                        {uint256ToDecimal(orderStatus.remainingA, !isReverse ? tokenADecimals : tokenBDecimals)}
                        <br/>
                        Uncollected executed amount of {!isReverse ? pair.SymbolB : pair.SymbolA}:
                        {uint256ToDecimal(orderStatus.remainingB, !isReverse ? tokenBDecimals : tokenADecimals)}
                    </>
                </>}
                {orderStatus && orderStatus.remainingB.gt(BigNumber.from(0)) &&
                    <InputGroup className="mb-3">
                        <InputGroup.Text>Unclaimed executed: {!isReverse ? pair.SymbolB : pair.SymbolA}
                        </InputGroup.Text>
                        <Form.Control readOnly={true} value={uint256ToDecimal(orderStatus.remainingB, !isReverse ? tokenBDecimals : tokenADecimals)}/>
                        <Button variant="success" onClick={onWithdraw}>Withdraw</Button>
                    </InputGroup>
                }
                {orderStatus && orderStatus.remainingA.gt(BigNumber.from(0)) &&
                    <InputGroup className="mb-3">
                        <InputGroup.Text>Waiting to execute: {!isReverse ? pair.SymbolA : pair.SymbolB}
                        </InputGroup.Text>
                        <Form.Control readOnly={true} value={uint256ToDecimal(orderStatus.remainingA, !isReverse ? tokenADecimals : tokenBDecimals)}/>
                        <Button variant="success" onClick={onWithdraw}>Withdraw</Button>
                    </InputGroup>
                }
           </Form> </Accordion.Body>
        </Accordion.Item>);
}

export default OrderDetails;