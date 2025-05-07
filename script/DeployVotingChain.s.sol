// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Counter} from "../src/Counter.sol";

import {ProxyLib} from "@aragon/osx-commons-contracts/src/utils/deployment/ProxyLib.sol";

import {ToucanVoting} from "@aragon/toucan-voting-plugin/execution-chain/voting/ToucanVoting.sol";
import {IToucanVoting} from "@aragon/toucan-voting-plugin/execution-chain/voting/IToucanVoting.sol";

contract DeployVotingChain {
    using ProxyLib for address;
    
    function setUp() public {}

    function run() public {
         // create a dao..
        address dao = _createDAO(bytes32(0), bytes32(0));
        
        // TODO: we might need to deploy ToucanReceiver as a plugin using plugin setups, 
        // but what if current setup is not enough due to requirements ?
        address toucanVoting = deployToucanVoting(dao);
    }

    function deployToucanVoting(address _dao) public returns (address) {
        address base = address(new ToucanVoting());

        address[] memory members = readMultisigMembers();

        bytes memory data = abi.encodeCall(
            ToucanVoting.initialize,
            (
                IDAO(_dao),
                IToucanVoting.VotingSettings({
                    VotingMode: IToucanVoting.VotingMode.Standard,
                    supportThreshold: 0,
                    minParticipation: 0,
                    minDuration: 0, 
                    minProposerVotingPower: 0
                }),
                address(token)
            )
        );

        // deploy and return the proxy
        return base.deployUUPSProxy(data);
    }

}    
