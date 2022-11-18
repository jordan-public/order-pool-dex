// SPDX-License-Identifier: BUSL-1.1
import React from 'react';
import { Container, Row, Col, Card, Form, InputGroup, Button, Spinner } from 'react-bootstrap';
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
            await doUpdate(amountA, p, r, tokenADec, tokenBDec);
        }) ();
    }, [provider, address, pair]); // On load

    const doUpdate = async (amtA, p, r, tokenADec, tokenBDec) => {
        if (!tokenADec || !tokenBDec) return;
        const ps = await p.poolSize();
        setPoolSizeA(ps);
        const rs = await r.poolSize();
        setPoolSizeB(rs);
        const estAmtB = await p.convert(amtA);
        setEstAmountB(estAmtB);
        const t = rs.gte(estAmtB) ? estAmtB : rs;
        const m = estAmtB.gt(rs) ? estAmtB.sub(rs) : BigNumber.from(0);
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
        await doUpdate(amountA, orderPool, reverseOrderPool, tokenADecimals, tokenBDecimals);
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
        await doUpdate(a, orderPool, reverseOrderPool, tokenADecimals, tokenBDecimals);
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
        if (orderStatus.remainingA !== 0 || orderStatus.remainingB !== 0 || 
            orderStatusReverse.remainingA !== 0 || orderStatusReverse.remainingB !== 0) return;
        if (await assureAuthorized() === 0) return;
        try {
            const tx = await orderPool.swap(amountA, sufficientOrderIndex, {gasLimit: 10000000});

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
        if (!orderStatus || !orderStatusReverse) return;
    console.log("orderStatus.rangeIndex", orderStatus.rangeIndex);
    console.log("orderStatusReverse.rangeIndex", orderStatusReverse.rangeIndex);
        if (orderStatus.rangeIndex === ethers.constants.MaxUint256 && orderStatusReverse.rangeIndex === ethers.constants.MaxUint256) return;
        try {
            const tx = (orderStatus.rangeIndex !== ethers.constants.MaxUint256)? 
                await orderPool.withdraw(orderStatus.rangeIndex):
                await reverseOrderPool.withdraw(orderStatusReverse.rangeIndex);

            const r = await tx.wait();
            await doUpdate(amountA, orderPool, reverseOrderPool, tokenADecimals, tokenBDecimals);
            window.alert('Completed. Block hash: ' + r.blockHash);        
        } catch(e) {
            console.log("Error: ", e);
            window.alert(e.message + "\n" + (e.data?e.data.message:""));
            return;
        }
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
                        {orderStatus && orderStatusReverse &&
                         (orderStatus.remainingB.gt(BigNumber.from(0)) || orderStatusReverse.remainingB.gt(BigNumber.from(0))) &&
                            <InputGroup className="mb-3">
                                <InputGroup.Text>Unclaimed: {orderStatus.remainingB.gt(BigNumber.from(0))?pair.SymbolB:pair.SymbolA}
                                </InputGroup.Text>
                                <Form.Control readOnly={true} value={orderStatus.remainingB.gt(BigNumber.from(0))?uint256ToDecimal(orderStatus.remainingB, tokenBDecimals):uint256ToDecimal(orderStatusReverse.remainingB, tokenADecimals)}/>
                                <Button variant="success" onClick={onWithdraw}>Withdraw</Button>
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