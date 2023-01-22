// SPDX-License-Identifier: BUSL-1.1
import React from 'react';
import { Container, Row, Col, Card, Button } from 'react-bootstrap';
import 'bootstrap/dist/css/bootstrap.css'; 
import { ethers } from 'ethers';
import aIOrderPool from '../artifacts/IOrderPool.json';
import aERC20 from '../artifacts/ERC20.json';
import OrderEntry from './OrderEntry';
import OrderList from './OrderList';

function Body({provider, address, pair}) {
    const [orderPool, setOrderPool] = React.useState(null);
    const [reverseOrderPool, setReverseOrderPool] = React.useState(null);
    const [tokenA, setTokenA] = React.useState(null);
    const [tokenB, setTokenB] = React.useState(null);
    const [tokenADecimals, setTokenADecimals] = React.useState(null);
    const [tokenBDecimals, setTokenBDecimals] = React.useState(null);

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
        }) ();
    }, [provider, address, pair]); // On load

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

    if (!provider || !pair ) return <></>;
    return <>
        <br/><br/>
        <Container fluid>
            <Row></Row>
            <Row>
                <Col></Col>
                <Col><Card border="primary" bg="light" style={{ width: '35rem' }}>
                    <Card.Header>
                        {pair.SymbolA} &nbsp;
                        <Button size="sm" onClick={addTokenAToWallet}>+</Button>
                        &nbsp; -&gt; {pair.SymbolB} &nbsp;
                        <Button size="sm" onClick={addTokenBToWallet}>+</Button>
                    </Card.Header>
                    <Card.Body>
                        <OrderEntry provider={provider} address={address} pair={pair}
                            orderPool={orderPool} reverseOrderPool={reverseOrderPool}
                            tokenA={tokenA} tokenB={tokenB} tokenADecimals={tokenADecimals} tokenBDecimals={tokenBDecimals} />
                    </Card.Body>
                </Card></Col>
                <Col></Col>
            </Row>
            <Row>
                <OrderList provider={provider} address={address} pair={pair}
                    orderPool={orderPool} reverseOrderPool={reverseOrderPool}
                    tokenA={tokenA} tokenB={tokenB} tokenADecimals={tokenADecimals} tokenBDecimals={tokenBDecimals} />
            </Row>
        </Container>
    </>;
}

export default Body;