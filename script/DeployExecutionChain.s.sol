// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";

import {ProxyLib} from "@aragon/osx-commons-contracts/src/utils/deployment/ProxyLib.sol";

import {PluginRepo} from "@aragon/osx/framework/plugin/repo/PluginRepo.sol";
import {IPlugin} from "@aragon/osx-commons-contracts/src/plugin/IPlugin.sol";
import {Multisig} from "@aragon/multisig-plugin/Multisig.sol";
import {TokenVoting} from "@aragon/token-voting-plugin/TokenVoting.sol";
import {StagedProposalProcessor as SPP} from "@aragon/staged-proposal-processor-plugin/StagedProposalProcessor.sol";
import {DAOFactory} from "@aragon/osx/framework/dao/DAOFactory.sol";
import {DAO} from "@aragon/osx/core/dao/DAO.sol";
import {IDAO} from "@aragon/osx-commons-contracts/dao/IDAO.sol";
import {PluginSetupProcessor as PSP, PluginSetupRef, hashHelpers} from "@aragon/osx/framework/plugin/setup/PluginSetupProcessor.sol";

import {BaseScript} from "./Base.sol";

contract DeployExecutionChain is BaseScript {
    
    address public sppRepo;

    using ProxyLib for Address;

    function setUp() public {}

    function run() public {
        psp = _getAddressFromConfig(PLUGIN_SETUP_PROCESSOR_KEY);
        sppRepo = _getAddressFromConfig(SPP_PLUGIN_REPO_KEY);
        daoFactory = _getAddressFromConfig(DAO_FACTORY_ADDRESS_KEY);
        globalExecutor = _getAddressFromConfig(GLOBAL_EXECUTOR_KEY);

        // create a dao..
        address dao = _createDAO(bytes32(0), bytes32(0));

        // Deploy bodies and create stages struct.
        address multisig = deployMultisigBody();
        SPP.Stage[] memory stages = new SPP.Stage[](1);

        // Stage 0
        {
            SPP.Body[] memory bodies = new SPP.Body[](1);
            bodies[0] = SPP.Body({
                addr: multisig,
                isManual: false,
                tryAdvance: true,
                resultType: SPP.ResultType.Veto
            });

            SPP.Stage memory stage0 = SPP.Stage({
                bodies: bodies,
                maxAdvance: 1,
                minAdvance: 1,
                voteDuration: 1,
                approvalThreshold: 20,
                vetoThreshold: 30,
                cancelable: false,
                editable: false
            });
        }

        stages[0] = stage0;

        IDAO.Actions[] memory actions = prepareSPP(dao, bytes(""), stages);
        DAO(dao).execute(bytes32(0), actions, 0);
    }

    function prepareSPP(
        address _dao,
        bytes memory _pluginMetadata,
        SPP.Stage[] memory _stages
    ) public {
        // Prepare the installation
        bytes memory setupData = abi.encode(
            _pluginMetadata,
            _stages,
            new RuledCondition.Rule[](0),
            IPlugin.TargetConfig({
                target: _dao,
                operation: IPlugin.Operation.Call
            })
        );

        PluginSetupRef memory pluginSetupRef = PluginSetupRef(
            PluginRepo.Tag(1, 1),
            PluginRepo(sppRepo)
        );

        (
            address plugin,
            IPluginSetup.PreparedSetupData memory preparedSetupData
        ) = PSP(psp).prepareInstallation(
                _dao,
                PSP.PrepareInstallationParams(pluginSetupRef, setupData)
            );

        IDAO.Actions[] memory actions = new IDAO.Actions[](3);
        actions[0] = IDAO.Action({
            to: _dao,
            value: 0,
            data: abi.encodeCall(
                DAO.grant,
                (_dao, psp, DAO.ROOT_PERMISSION_ID())
            )
        });

        actions[1] = IDAO.Action({
            to: psp,
            value: 0,
            data: abi.encodeCall(
                PSP.applyInstallation,
                (
                    _dao,
                    PSP.ApplyInstallationParams(
                        pluginSetupRef,
                        plugin,
                        preparedSetupData.permissions,
                        hashHelpers(preparedSetupData.helpers)
                    )
                )
            )
        });

        actions[2] = IDAO.Action({
            to: _dao,
            value: 0,
            data: abi.encodeCall(
                DAO.revoke,
                (_dao, psp, DAO.ROOT_PERMISSION_ID())
            )
        });
    }

    function deployMultisigBody(address _dao) public returns (address) {
        address base = new Multisig();

        address[] memory members = readMultisigMembers();

        bytes memory data = abi.encodeCall(
            Multisig.initialize,
            (
                IDAO(_dao),
                members,
                Multisig.MultisigSettings({onlyListed: true, minApprovals: 3}),
                IPlugin.TargetConfig({
                    target: globalExecutor,
                    operation: IPlugin.Operation.DelegateCall
                }),
                bytes("") // multisig metadata.
            )
        );

        // deploy and return the proxy
        return base.deployUUPSProxy(data);
    }

    function readMultisigMembers()
        public
        view
        returns (address[] memory result)
    {
        // JSON list of members
        string memory membersFileName = vm.envOr(
            "MULTISIG_MEMBERS_FILE_NAME",
            "multisig-members.json"
        );
        string memory path = string.concat(
            vm.projectRoot(),
            "/",
            membersFileName
        );
        string memory strJson = vm.readFile(path);

        bool exists = vm.keyExistsJson(strJson, "$.members");
        if (!exists) {
            revert(
                "The file pointed by MULTISIG_MEMBERS_FILE_NAME does not contain any members"
            );
        }

        result = vm.parseJsonAddressArray(strJson, "$.members");

        if (result.length == 0) {
            revert(
                "The file pointed by MULTISIG_MEMBERS_FILE_NAME needs to contain at least one member"
            );
        }
    }
}
