// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.18;

contract Constants {
    // solhint-disable max-line-length
    string public constant DEPLOYMENTS_PATH =
        "lib/@aragon/osx-commons-configs/dist/deployments/json";

    string public constant DAO_FACTORY_ADDRESS_KEY = "DAOFactory.address";
    string public constant SPP_PLUGIN_REPO_KEY = "StagedProposalProcessorRepoProxy.address";
    string public constant PLUGIN_SETUP_PROCESSOR_KEY = "PluginSetupProcessor.address";
    string public constant GLOBAL_EXECUTOR_KEY = "Executor.address";
}