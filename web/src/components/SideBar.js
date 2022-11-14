// SPDX-License-Identifier: BUSL-1.1
import React from 'react';
import { Form, Accordion } from 'react-bootstrap';
import 'bootstrap/dist/css/bootstrap.css'; 
import { ethers } from 'ethers';
import aOrderPoolFactory from '../artifacts/OrderPoolFactory.json';

function SideBar({provider,  address}) {

    React.useEffect(() => {
        (async () => {
            const signer = provider.getSigner();
            const { chainId } = await provider.getNetwork();
            const cOrderPoolFactory = new ethers.Contract(aOrderPoolFactory.contractAddress, aOrderPoolFactory.abi, signer);
            const getNumPairs = await cOrderPoolFactory.getNumPairs();
console.log("address", address);
console.log("getNumPairs", getNumPairs);
        }) ();
    }, [provider, address]); // On load

    return (<>
SideBar
<br/>
{address}
    </>);
}

export default SideBar;