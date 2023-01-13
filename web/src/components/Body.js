// SPDX-License-Identifier: BUSL-1.1
import React from 'react';
import { Container, Row, Col, Card, Form, InputGroup, Button, ToggleButton, Spinner } from 'react-bootstrap';
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

    const [maker, setMaker] = React.useState(true);
    const [taker, setTaker] = React.useState(true);
    const [amountA, setAmountA] = React.useState(BigNumber.from(0));
    const [estAmountB, setEstAmountB] = React.useState(BigNumber.from(0));
    const [estProtocolFee, setEstProtocolFee] = React.useState("");
    const [estT2MFee, setEstT2MFee] = React.useState("");
    const [poolSizeA, setPoolSizeA] = React.useState(BigNumber.from(0));
    const [poolSizeB, setPoolSizeB] = React.useState(BigNumber.from(0));
    const [sufficientOrderIndex, setSufficientOrderIndex] = React.useState(BigNumber.from(0));
    const [orderStatus, setOrderStatus] = React.useState(null);
    const [orderStatusReverse, setOrderStatusReverse] = React.useState(null);

    React.useEffect(() => {
        (async () => {
            if (!provider || !pair) return;
            const signer = provider.getSigner();
            const p = new ethers.Contract(pair.pair, aIOrderPool.abi, signer);
            setOrderPool(p);
            const r = new ethers.Contract(await p.reversePool(), aIOrderPool.abi, signer);
            setReverseOrderPool(r);
            const cTokenA = new ethers.Contract(await p.tokenA(), aERC20.abi, signer);
            setTokenA(cTokenA);
            const cTokenB = new ethers.Contract(await p.tokenB(), aERC20.abi, signer);
            setTokenB(cTokenB);
            const tokenADec = await cTokenA.decimals();
            setTokenADecimals(tokenADec);
            const tokenBDec = await cTokenB.decimals();
            setTokenBDecimals(tokenBDec);
            await doUpdate(amountA, taker, maker, p, r, tokenADec, tokenBDec);
        }) ();
    }, [provider, address, pair]); // On load

    const doUpdate = async (amtA, tkr, mkr, p, r, tokenADec, tokenBDec) => {
        if (!tokenADec || !tokenBDec) return;
        const ps = await p.poolSize();
        setPoolSizeA(ps);
        const rs = await r.poolSize();
        setPoolSizeB(rs);
        const estAmtB = await p.convert(amtA);
        setEstAmountB(estAmtB);
        const t = !tkr ? BigNumber.from(0) : (rs.gte(estAmtB) ? estAmtB : rs);
        const m = !mkr ? BigNumber.from(0) : estAmtB.sub(t);
        setEstProtocolFee(uint256ToDecimal(t.mul(BigNumber.from(5)).div(BigNumber.from(10000)), tokenBDec));
console.log("m: ", m, " t: ", t);
        const tmf = (t.gt(m)) ?
            uint256ToDecimal(t.sub(m).mul(BigNumber.from(25)).div(BigNumber.from(10000)), tokenBDec) :
            "-" + uint256ToDecimal(m.sub(t).mul(BigNumber.from(25)).div(BigNumber.from(10000)), tokenBDec);
        setEstT2MFee(tmf);
        setSufficientOrderIndex(await p.sufficientOrderIndexSearch(amtA));
        setOrderStatus(await p.orderStatus());
        setOrderStatusReverse(await r.orderStatus());
    }

    const onUpdate = async (blockNumber) => {
console.log(blockNumber, tokenADecimals, tokenBDecimals);
        await doUpdate(amountA, taker, maker, orderPool, reverseOrderPool, tokenADecimals, tokenBDecimals);
    }

    React.useEffect(() => {
        if (provider) {
            provider.on("block", onUpdate);
            return () => provider.off("block");
        }
    }); // Run on each render because onUpdate is a closure

    const registerToken = async (address, symbol, decimals) => {
        try {
            await window.ethereum.request({
                method: 'wallet_watchAsset',
                params: {
                "type":"ERC20",
                "options":{
                    "address": address,
                    "symbol": symbol,
                    "decimals": decimals,
                    "image": (window.location.origin + "/favicon.ico"),
                },
                },
                id: Math.round(Math.random() * 100000),
            });
        } catch(_) {};
    }

    const addTokenAToWallet = async () => {
        await registerToken(tokenA.address, pair.SymbolA, tokenADecimals);
    }

    const addTokenBToWallet = async () => {
        await registerToken(tokenB.address, pair.SymbolB, tokenBDecimals);
    }

    const onChangeAmount = async (e) => {
        let a = e.currentTarget.value;
        if (!a) a = "0"
        else
            a = BigNumber.from(decimalToUint256(parseFloat(e.currentTarget.value), tokenADecimals));
        setAmountA(a);
        await doUpdate(a, taker, maker, orderPool, reverseOrderPool, tokenADecimals, tokenBDecimals);
    }

    const assureAuthorized = async () => {
        const allowance = await tokenA.allowance(address, orderPool.address);
        if (amountA.gt(allowance)) {
            try {
                const authzAmount = ethers.constants.MaxUint256;
                const tx = await tokenA.approve(orderPool.address, authzAmount);
    
                const r = await tx.wait();
                window.alert('Completed. Block hash: ' + r.blockHash);
                return authzAmount;        
            } catch(e) {
                console.log("Error: ", e);
                window.alert(e.message + "\n" + (e.data?e.data.message:""));
                return 0;
            }
        }
    }

    const onSwap = async () => {
    console.log("sufficientOrderIndex", sufficientOrderIndex);
        if (!orderStatus) return;
        if (!orderStatus.remainingA.isZero() || !orderStatus.remainingB.isZero()  || 
            !orderStatusReverse.remainingA.isZero() || !orderStatusReverse.remainingB.isZero()) return;
        if (await assureAuthorized() === 0) return;
        try {
            const tx = await orderPool.swap(amountA, taker, maker, sufficientOrderIndex, {gasLimit: 10000000});

            const r = await tx.wait();
            await doUpdate(amountA, taker, maker, orderPool, reverseOrderPool, tokenADecimals, tokenBDecimals);
            window.alert('Completed. Block hash: ' + r.blockHash);        
        } catch(e) {
            console.log("Error: ", e);
            window.alert(e.message + "\n" + (e.data?e.data.message:""));
            return;
        }
    }
    
    const onWithdraw = async (reverse) => {
        if (!reverse && !orderStatus || reverse && !orderStatusReverse) return;
        try {
            const tx = (!reverse)? 
                await orderPool.withdraw(orderStatus.rangeIndex):
                await reverseOrderPool.withdraw(orderStatusReverse.rangeIndex);

            const r = await tx.wait();
            await doUpdate(amountA, taker, maker, orderPool, reverseOrderPool, tokenADecimals, tokenBDecimals);
            window.alert('Completed. Block hash: ' + r.blockHash);        
        } catch(e) {
            console.log("Error: ", e);
            window.alert(e.message + "\n" + (e.data?e.data.message:""));
            return;
        }
    }

    const onChangeTaker = async (e) => {
        const t = e.currentTarget.checked;
        setTaker(t);
        let m = maker;
        if (!t) {
            m = true;
            setMaker(m);
        }
        await doUpdate(amountA, t, m, orderPool, reverseOrderPool, tokenADecimals, tokenBDecimals)
    }

    const onChangeMaker = async (e) => {
        const m = e.currentTarget.checked;
        setMaker(m);
        let t = taker;
        if (!m) {
            t = true;
            setTaker(t);
        }
        await doUpdate(amountA, t, m, orderPool, reverseOrderPool, tokenADecimals, tokenBDecimals)
    }

    if (!provider || !pair ) return(<></>);
    return (<>
        <br/><br/>
        <Container fluid>
            <Row></Row>
            <Row>
                <Col></Col>
                <Col><Card border="primary" bg="light" style={{ width: '35rem' }}>
                    <Card.Header>
                        {pair.SymbolA} &nbsp;
                        <Button size="sm" onClick={addTokenAToWallet}>+</Button>
                        &nbsp; -> {pair.SymbolB} &nbsp;
                        <Button size="sm" onClick={addTokenBToWallet}>+</Button>
                    </Card.Header>
                    <Card.Body>
                        <Form>
                        {orderStatus && orderStatusReverse &&
                         orderStatus.remainingA.eq(BigNumber.from(0)) && orderStatus.remainingB.eq(BigNumber.from(0)) &&
                         orderStatusReverse.remainingA.eq(BigNumber.from(0)) && orderStatusReverse.remainingB.eq(BigNumber.from(0)) && <>
                            <InputGroup className="mb-3">
                                <InputGroup.Text>Amount: {pair.SymbolA}</InputGroup.Text>
                                <Form.Control type="number" onChange={onChangeAmount}/>
                                <ToggleButton id="tkr" type="checkbox" variant="primary-outline" value="1" checked={taker} 
                                    onChange={onChangeTaker}>Take</ToggleButton>
                                <ToggleButton id="mkr" type="checkbox" variant="primary-outline" value="1" checked={maker} 
                                    onChange={onChangeMaker}>Make</ToggleButton>
                                <Button variant="primary" onClick={onSwap}>Swap -></Button>
                            </InputGroup>
                            <br/>
                            Estimate:
                            <br/>
                            Estimated gross {pair.SymbolB} amount to receive: {uint256ToDecimal(estAmountB && estAmountB, tokenBDecimals)}
                            <br/>
                            Estimated protocol fee: {estProtocolFee} {pair.SymbolB} (0.05%)
                            <br/>
                            Estimated taker to maker fee: {estT2MFee} {pair.SymbolB} (0.25%)
                        </>}
                        {orderStatus && orderStatusReverse && 
                         (orderStatus.remainingA.gt(BigNumber.from(0)) || orderStatusReverse.remainingA.gt(BigNumber.from(0)) ) && <>
                            <Spinner animation="border" variant="primary" />
                            {orderStatus && <>
                                <br/>
                                Pool:
                                <br/>
                                Remaining unexecuted amount of {pair.SymbolA} amount: {orderStatus && uint256ToDecimal(orderStatus.remainingA, tokenADecimals)}
                                <br/>
                                Uncollected executed amount of {pair.SymbolB} amount: {orderStatus && uint256ToDecimal(orderStatus.remainingB, tokenBDecimals)}
                            </>}
                            {orderStatusReverse && <>
                                <br/>
                                Reverse Pool:
                                <br/>
                                Remaining unexecuted amount of {pair.SymbolB} amount: {orderStatusReverse && uint256ToDecimal(orderStatusReverse.remainingA, tokenBDecimals)}
                                <br/>
                                Uncollected executed amount of {pair.SymbolA} amount: {orderStatusReverse && uint256ToDecimal(orderStatusReverse.remainingB, tokenADecimals)}
                            </>}
                        </>}
                        {orderStatus && (orderStatus.remainingB.gt(BigNumber.from(0)) || orderStatus.remainingA.gt(BigNumber.from(0))) &&
                            <><br/>This order in this pool:</>
                        }
                        {orderStatus && orderStatus.remainingB.gt(BigNumber.from(0)) &&
                            <InputGroup className="mb-3">
                                <InputGroup.Text>Unclaimed executed: {pair.SymbolB}
                                </InputGroup.Text>
                                <Form.Control readOnly={true} value={uint256ToDecimal(orderStatus.remainingB, tokenBDecimals)}/>
                                <Button variant="success" onClick={()=>onWithdraw(false)}>Withdraw</Button>
                            </InputGroup>
                        }
                        {orderStatus && orderStatus.remainingA.gt(BigNumber.from(0)) &&
                            <InputGroup className="mb-3">
                                <InputGroup.Text>Waiting to execute: {pair.SymbolA}
                                </InputGroup.Text>
                                <Form.Control readOnly={true} value={uint256ToDecimal(orderStatus.remainingA, tokenADecimals)}/>
                                <Button variant="success" onClick={()=>onWithdraw(false)}>Withdraw</Button>
                            </InputGroup>
                        }
                        {orderStatusReverse && (orderStatusReverse.remainingB.gt(BigNumber.from(0)) || orderStatusReverse.remainingA.gt(BigNumber.from(0))) &&
                            <><br/>This order in the reverse pool:</>
                        }
                        {orderStatusReverse && orderStatusReverse.remainingB.gt(BigNumber.from(0)) &&
                            <InputGroup className="mb-3">
                                <InputGroup.Text>Unclaimed executed: {pair.SymbolA}
                                </InputGroup.Text>
                                <Form.Control readOnly={true} value={uint256ToDecimal(orderStatusReverse.remainingB, tokenADecimals)}/>
                                <Button variant="success" onClick={()=>onWithdraw(true)}>Withdraw</Button>
                            </InputGroup>
                        }
                        {orderStatusReverse && orderStatusReverse.remainingA.gt(BigNumber.from(0)) &&
                            <InputGroup className="mb-3">
                                <InputGroup.Text>Waiting to execute: {pair.SymbolB}
                                </InputGroup.Text>
                                <Form.Control readOnly={true} value={uint256ToDecimal(orderStatusReverse.remainingA, tokenBDecimals)}/>
                                <Button variant="success" onClick={()=>onWithdraw(true)}>Withdraw</Button>
                            </InputGroup>
                        }
                        <br/>
                        <br/>
                        Pool:
                        <br/>
                        {pair.SymbolA} waiting to swap: {uint256ToDecimal(poolSizeA, tokenADecimals)}
                        <br/>
                        {pair.SymbolB} available immediately: {uint256ToDecimal(poolSizeB, tokenBDecimals)}
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