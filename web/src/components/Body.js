// SPDX-License-Identifier: BUSL-1.1
import React from 'react';
import { Container, Row, Col, Card, Form, InputGroup, Button } from 'react-bootstrap';
import 'bootstrap/dist/css/bootstrap.css'; 
import { BigNumber, ethers } from 'ethers';
import aIOrderPool from '../artifacts/IOrderPool.json';
import aERC20 from '../artifacts/ERC20.json';
import uint256ToDecimal from '../utils/uint256ToDecimal';
import decimalToUint256 from '../utils/decimalToUint256';

function Body({provider, address, pair}) {
    const [orderPool, setOrderPool] = React.useState(null);
    const [reverseOrderPool, setReverseOrderPool] = React.useState(null);
    const [tokenA, setTokenA] = React.useState(null);
    const [tokenB, setTokenB] = React.useState(null);
    const [tokenADecimals, setTokenADecimals] = React.useState(null);
    const [tokenBDecimals, setTokenBDecimals] = React.useState(null);

    const [amountA, setAmountA] = React.useState(BigNumber.from(0));
    const [estAmountB, setEstAmountB] = React.useState(BigNumber.from(0));
    const [poolSizeA, setPoolSizeA] = React.useState(BigNumber.from(0));
    const [poolSizeB, setPoolSizeB] = React.useState(BigNumber.from(0));
    const [sufficientOrderIndex, setSufficientOrderIndex] = React.useState(BigNumber.from(0));
    const [orderStatus, setOrderStatus] = React.useState(null);

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
            const aInit = BigNumber.from(10).pow(tokenADec);
            setAmountA(aInit);
            await doUpdate(aInit, p, r, tokenADec, tokenBDec);
          }) ();
    }, [provider, address, pair]); // On load

    const doUpdate = async (amtA, p, r, tokenADec, tokenBDec) => {
        if (!tokenADec || !tokenBDec) return;
        setEstAmountB(await p.convert(amtA));
        setPoolSizeA(await p.poolSize());
        setPoolSizeB(await r.poolSize());
        setSufficientOrderIndex(await p.sufficientOrderIndexSearch(amtA));
        setOrderStatus(await p.orderStatus());
    }

    const onUpdate = async (blockNumber) => {
console.log(blockNumber, tokenADecimals, tokenBDecimals);
        await doUpdate(amountA, orderPool, reverseOrderPool, tokenADecimals, tokenBDecimals);
    }

    React.useEffect(() => {
        if (provider) {
            provider.on("block", onUpdate);
            return () => provider.off("block");
        }
    }); // Run on each render because onUpdate is a closure

    const onChangeAmount = async (e) => {
        const a = BigNumber.from(decimalToUint256(parseFloat(e.currentTarget.value), tokenADecimals));
        setAmountA(a);
        await doUpdate(a, orderPool, reverseOrderPool, tokenADecimals, tokenBDecimals);
    }

    const onSwap = async () => {
        if (!orderStatus) return;
        if (orderStatus[1] == 0 && orderStatus[2] == 0 && orderStatus[2] != ethers.constants.MaxUint256) return;
        try {
            const tx = await orderPool.swap(amountA, sufficientOrderIndex);

            const r = await tx.wait();
            await doUpdate(amountA, orderPool, reverseOrderPool, tokenADecimals, tokenBDecimals);
            window.alert('Completed. Block hash: ' + r.blockHash);        
        } catch(e) {
            console.log("Error: ", e);
            window.alert(e.message + "\n" + (e.data?e.data.message:""));
            return;
        }
    }
    
    const onWithdraw = async () => {
        if (!orderStatus) return;
        if (orderStatus[2] == ethers.constants.MaxUint256) return;
        try {
            const tx = await orderPool.withdraw(orderStatus[2]);

            const r = await tx.wait();
            await doUpdate(amountA, orderPool, reverseOrderPool, tokenADecimals, tokenBDecimals);
            window.alert('Completed. Block hash: ' + r.blockHash);        
        } catch(e) {
            console.log("Error: ", e);
            window.alert(e.message + "\n" + (e.data?e.data.message:""));
            return;
        }
    }

    if (!provider || !pair) return(<></>);
    return (<>
        {pair.SymbolA}/{pair.SymbolB}: {pair.pair}
        <br/>
        Amount A: {amountA.toString()}
        <br/>
        Est Amount B: {estAmountB.toString()}
        <br/>
        sufficientOrderIndex: {sufficientOrderIndex.toString()}
        <br/>
        rangeIndex: {orderStatus && orderStatus[2].toString()}
        <br/><br/>
        <Container fluid>
            <Row></Row>
            <Row>
                <Col></Col>
                <Col><Card border="primary" bg="light" style={{ width: '25rem' }}>
                    <Card.Header>{pair.SymbolA} -> {pair.SymbolB}</Card.Header>
                    <Card.Body>
                        <Form>
                        <InputGroup className="mb-3">
                            <InputGroup.Text>Amount: {pair.SymbolA}</InputGroup.Text>
                            <Form.Control type="number" onChange={onChangeAmount}/>
                            <Button variant="primary" onClick={onSwap}>Swap -></Button>
                        </InputGroup>
                        <InputGroup className="mb-3">
                            <InputGroup.Text>Unclaimed: {pair.SymbolB}</InputGroup.Text>
                            <Form.Control readOnly={true} />
                            <Button variant="success" onClick={onWithdraw}>Withdraw</Button>
                        </InputGroup>
                        {orderStatus && orderStatus[2] != ethers.constants.MaxUint256 && <>
                            <Form.Text>Remaining unexecuted amount of {pair.SymbolA} amount: {uint256ToDecimal(orderStatus[0], tokenADecimals)}</Form.Text>
                            <br/>
                            <Form.Text>Remaining uncollected executed amount of {pair.SymbolB} amount: {uint256ToDecimal(orderStatus[1], tokenBDecimals)}</Form.Text>
                            <br/>
                        </>}
                        <Form.Text>Estimated gross {pair.SymbolB} amount: {uint256ToDecimal(estAmountB, tokenBDecimals)}</Form.Text>
                        <br/>
                        <Form.Text>Estimated protocol fee: (0.05%)</Form.Text>
                        <br/>
                        <Form.Text>Estimated taker fee: (0.25%)</Form.Text>
                        <br/>
                        <Form.Text>{pair.SymbolA} waiting to swap: {uint256ToDecimal(poolSizeA, tokenADecimals)}</Form.Text>
                        <br/>
                        <Form.Text>{pair.SymbolB} available immediately: {uint256ToDecimal(poolSizeB, tokenBDecimals)}</Form.Text>
                        </Form>
                    </Card.Body>
                </Card></Col>
                <Col></Col>
            </Row>
            <Row></Row>
        </Container>
    </>);
}

export default Body;