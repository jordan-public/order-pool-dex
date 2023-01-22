// SPDX-License-Identifier: BUSL-1.1
import React from 'react';
import { Form, InputGroup, Button, ToggleButton } from 'react-bootstrap';
import 'bootstrap/dist/css/bootstrap.css'; 
import { BigNumber, ethers } from 'ethers';
import uint256ToDecimal from '../utils/uint256ToDecimal';
import decimalToUint256 from '../utils/decimalToUint256';

function OrderEntry({provider, address, pair, orderPool, reverseOrderPool, tokenA, tokenB, tokenADecimals, tokenBDecimals}) {
    const [maker, setMaker] = React.useState(true);
    const [taker, setTaker] = React.useState(true);
    const [amountA, setAmountA] = React.useState(BigNumber.from(0));
    const [estAmountB, setEstAmountB] = React.useState(BigNumber.from(0));
    const [estProtocolFee, setEstProtocolFee] = React.useState("");
    const [estT2MFee, setEstT2MFee] = React.useState("");
    const [poolSizeA, setPoolSizeA] = React.useState(BigNumber.from(0));
    const [poolSizeB, setPoolSizeB] = React.useState(BigNumber.from(0));
    const [sufficientOrderIndex, setSufficientOrderIndex] = React.useState(BigNumber.from(0));
 
    React.useEffect(() => {
        (async () => {
            await doUpdate(amountA, taker, maker);
        }) ();
    }, [provider, address, pair, orderPool, reverseOrderPool, tokenA, tokenB, tokenADecimals, tokenBDecimals]); // On load

    const doUpdate = async (amtA, tkr, mkr) => {
        if (!tokenADecimals || !tokenBDecimals) return;
        const ps = await orderPool.poolSize();
        setPoolSizeA(ps);
        const rs = await reverseOrderPool.poolSize();
        setPoolSizeB(rs);
        const estAmtB = await orderPool.convert(amtA);
        setEstAmountB(estAmtB);
        const t = !tkr ? BigNumber.from(0) : (rs.gte(estAmtB) ? estAmtB : rs);
        const m = !mkr ? BigNumber.from(0) : estAmtB.sub(t);
        setEstProtocolFee(uint256ToDecimal(t.mul(BigNumber.from(5)).div(BigNumber.from(10000)), tokenBDecimals));
//console.log("m: ", m, " t: ", t);
        const tmf = (t.gt(m)) ?
            uint256ToDecimal(t.sub(m).mul(BigNumber.from(25)).div(BigNumber.from(10000)), tokenBDecimals) :
            "-" + uint256ToDecimal(m.sub(t).mul(BigNumber.from(25)).div(BigNumber.from(10000)), tokenBDecimals);
        setEstT2MFee(tmf);
        setSufficientOrderIndex(await orderPool.sufficientOrderIndexSearch(amtA));
    }

    const onUpdate = async (blockNumber) => {
console.log("Block ", blockNumber);
        await doUpdate(amountA, taker, maker);
    }

    React.useEffect(() => {
        if (provider) {
            provider.on("block", onUpdate);
            return () => provider.off("block", onUpdate);
        }
    }); // Run on each render because onUpdate is a closure

    const onChangeAmount = async (e) => {
        let a = e.currentTarget.value;
        if (!a) a = "0"
        else
            a = BigNumber.from(decimalToUint256(parseFloat(e.currentTarget.value), tokenADecimals));
        setAmountA(a);
        await doUpdate(a, taker, maker);
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
        if (await assureAuthorized() === 0) return;
        try {
            const tx = await orderPool.swap(amountA, taker, maker, sufficientOrderIndex, {gasLimit: 20000000});

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
        await doUpdate(amountA, t, m);
    }

    const onChangeMaker = async (e) => {
        const m = e.currentTarget.checked;
        setMaker(m);
        let t = taker;
        if (!m) {
            t = true;
            setTaker(t);
        }
        await doUpdate(amountA, t, m);
    }

    if (!provider || !pair ) return(<></>);
    return (
        <Form>
        {<>
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
        <br/>
        <br/>
        Pool:
        <br/>
        {pair.SymbolA} waiting to swap: {uint256ToDecimal(poolSizeA, tokenADecimals)}
        <br/>
        {pair.SymbolB} available immediately: {uint256ToDecimal(poolSizeB, tokenBDecimals)}
        </Form>
    );
}

export default OrderEntry;