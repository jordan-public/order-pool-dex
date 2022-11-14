// SPDX-License-Identifier: BUSL-1.1

import './App.css';
import React from 'react';
import { Container, Row, Col } from 'react-bootstrap';
import NavigationBar from './components/NavigationBar';
import SideBar from './components/SideBar';
import Body from './components/Body';

function App() {
  const [provider, setProvider] = React.useState(null);
  const [address, setAddress] = React.useState(null);

  return (<Container fluid>
    <Row><Col>
    <NavigationBar provider={provider} setProvider={setProvider} address={address} setAddress={setAddress}/>
    </Col></Row>
    <Row>
    <Col xs>{window.web3 && <SideBar provider={provider} address={address} />}</Col>
    <Col lg>{window.web3 && <Body provider={provider} address={address} />}</Col>
    </Row>
    
  </Container >);
}

export default App;