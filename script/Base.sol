// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {Constants} from "./utils/Constants.sol";
import {DAOFactory} from "@aragon/osx/framework/dao/DAOFactory.sol";
import {DAO} from "@aragon/osx/core/dao/DAO.sol";
import {IDAO} from "@aragon/osx-commons-contracts/dao/IDAO.sol";

contract BaseScript is Constants, Script {
    address public psp;
    address public daoFactory;
    address public globalExecutor;

    uint256 internal deployerPrivateKey = vm.envUint("DEPLOYER_KEY");
    string internal network = vm.envString("NETWORK_NAME");
    string internal protocolVersion = vm.envString("PROTOCOL_VERSION");

    // solhint-disable immutable-vars-naming
    address internal immutable deployer = vm.addr(deployerPrivateKey);

    error UnsupportedNetwork(string network);

    function setUp() public {
        psp = _getAddressFromConfig(PLUGIN_SETUP_PROCESSOR_KEY);
        daoFactory = _getAddressFromConfig(DAO_FACTORY_ADDRESS_KEY);
        globalExecutor = _getAddressFromConfig(GLOBAL_EXECUTOR_KEY);
    }

    function _createDAO(bytes32 _subdomain, bytes32 _metadata) internal returns(address) {
        // create a dao..
        // Note that we pass 0 plugins, so deployer
        // will have the execute permission on the dao.
        DAOFactory.DAOSettings memory daoSettings = DAOFactory.DAOSettings({
            trustedForwarder: address(0),
            daoURI: "",
            subdomain: _subdomain,
            metadata: _metadata
        });

        (DAO dao, ) = DAOFactory(daoFactory).createDAO(
            daoSettings,
            new DAOFactory.PluginSettings[](0)
        );

        return address(dao);
    }
    

    function _getAddressFromConfig(string memory _key) internal view returns(address) {
        string memory _json = _getOsxConfigs(network);
        string memory buildKey = _buildKey(protocolVersion, _key);

        if (!vm.keyExists(_json, buildKey)) {
            revert UnsupportedNetwork(network);
        }

        return vm.parseJsonAddress(_json, _key);
    }
    
    function _getOsxConfigs(string memory _network) internal view returns (string memory) {
        string memory osxConfigsPath = string.concat(
            vm.projectRoot(),
            "/",
            DEPLOYMENTS_PATH,
            "/",
            _network,
            ".json"
        );
        return vm.readFile(osxConfigsPath);
    }

    function _buildKey(
        string memory _protocolVersion,
        string memory _contractKey
    ) internal pure returns (string memory) {
        return string.concat(".['", _protocolVersion, "'].", _contractKey);
    }

    function _versionString(uint8 _release, uint8 _build) internal pure returns (string memory) {
        return string(abi.encodePacked("v", vm.toString(_release), ".", vm.toString(_build)));
    }

    function _protocolVersionString(uint8[3] memory version) internal pure returns (string memory) {
        return
            string(
                abi.encodePacked(
                    "v",
                    vm.toString(version[0]),
                    ".",
                    vm.toString(version[1]),
                    ".",
                    vm.toString(version[2])
                )
            );
    }
}