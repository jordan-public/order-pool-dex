// SPDX-License-Identifier: BUSL-1.1

import './App.css';
import React from 'react';
import { Card } from 'react-bootstrap';
import NavigationBar from './components/NavigationBar';
import Body from './components/Body';

function App() {
  const [provider, setProvider] = React.useState(null);
  const [address, setAddress] = React.useState(null);

  return (<Card><Card.Body>
    <NavigationBar provider={provider} setProvider={setProvider} setAddress={setAddress}/>
    <br />
    { window.web3 && <Body provider={provider} address={address}/> }
    </Card.Body></Card>);
}

export default App;