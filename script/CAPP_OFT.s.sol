// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";

import {BaseDeployer} from "./BaseDeployer.s.sol";
import {OFT} from "../src/OFT.sol";
import {UUPSProxy} from "../src/UUPSProxy.sol";

contract DeployCapp is Script, BaseDeployer {
    UUPSProxy internal proxyCapp;

    bytes32 internal cappProxySalt;
    bytes32 internal cappSalt;

    address private create2addrCapp;
    address private create2addrProxy;

    OFT private wrappedProxy;

    struct LayerZeroChainDeployment {
        Chains chain;
        address endpoint;
    }

    LayerZeroChainDeployment[] private targetChains;

    function setUp() public {
        // Endpoint configuration from: https://docs.layerzero.network/contracts/endpoint-addresses
        targetChains.push(LayerZeroChainDeployment(Chains.Sepolia, 0x6EDCE65403992e310A62460808c4b910D972f10f));
        targetChains.push(LayerZeroChainDeployment(Chains.Mumbai, 0x6EDCE65403992e310A62460808c4b910D972f10f));
    }

    function run() public {}

    function deployCappTestnet(uint256 _cappSalt, uint256 _cappProxySalt) public setEnvDeploy(Cycle.Test) {
        cappSalt = bytes32(_cappSalt);
        cappProxySalt = bytes32(_cappProxySalt);

        createDeployMultichain();
    }

    /// @dev Helper to iterate over chains and select fork.
    function createDeployMultichain() private {
        address[] memory deployedContracts = new address[](targetChains.length);
        uint256[] memory forkIds = new uint256[](targetChains.length);

        for (uint256 i; i < targetChains.length;) {
            console2.log("Deploying to chain:", forks[targetChains[i].chain], "\n");

            uint256 forkId = createSelectFork(targetChains[i].chain);
            forkIds[i] = forkId;

            deployedContracts[i] = chainDeployCapp(targetChains[i].endpoint);

            ++i;
        }

        wireOApps(deployedContracts, forkIds);
    }

    /// @dev Function to perform actual deployment.
    function chainDeployCapp(address lzEndpoint)
        private
        computeCreate2(cappSalt, cappProxySalt, lzEndpoint)
        broadcast(deployerPrivateKey)
        returns (address deployedContract)
    {
        OFT capp = new OFT{salt: cappSalt}();

        require(create2addrCapp == address(capp), "Implementation address mismatch");

        console2.log("Capp address:", address(capp), "\n");

        proxyCapp = new UUPSProxy{salt: cappProxySalt}(
            address(capp), abi.encodeWithSelector(OFT.initialize.selector, "CAPP Token", "CAPP", lzEndpoint, ownerAddress)
        );

        proxyAddress = address(proxyCapp);

        require(create2addrProxy == proxyAddress, "Proxy address mismatch");

        wrappedProxy = OFT(proxyAddress);

        require(wrappedProxy.owner() == ownerAddress, "Owner role mismatch");

        console2.log("Capp Proxy address:", address(proxyCapp), "\n");

        return address(proxyCapp);
    }

    /// @dev Compute the CREATE2 addresses for contracts (proxy, capp).
    /// @param saltCapp The salt for the capp contract.
    /// @param saltProxy The salt for the proxy contract.
    modifier computeCreate2(bytes32 saltCapp, bytes32 saltProxy, address lzEndpoint) {
        create2addrCapp = vm.computeCreate2Address(saltCapp, hashInitCode(type(OFT).creationCode));

        create2addrProxy = vm.computeCreate2Address(
            saltProxy,
            hashInitCode(
                type(UUPSProxy).creationCode,
                abi.encode(
                    create2addrCapp, abi.encodeWithSelector(OFT.initialize.selector, lzEndpoint, ownerAddress)
                )
            )
        );

        _;
    }
}
