// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

/*
import "../src/AOSServiceManager.sol" as aossm;
import {AOSChallengeManager} from "../src/AOSChallengeManager.sol";
import {BLSMockAVSDeployer} from "@eigenlayer-middleware/test/utils/BLSMockAVSDeployer.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract AOSChallengeManagerTest is BLSMockAVSDeployer {
    aossm.AOSServiceManager sm;
    aossm.AOSServiceManager smImplementation;
    AOSChallengeManager tm;
    AOSChallengeManager tmImplementation;

    uint32 public constant CHALLENGE_RESPONSE_WINDOW_BLOCK = 30;
    address aggregator =
        address(uint160(uint256(keccak256(abi.encodePacked("aggregator")))));

    function setUp() public {
        _setUpBLSMockAVSDeployer();

        tmImplementation = new AOSChallengeManager(
            aossm.IRegistryCoordinator(address(registryCoordinator)),
            CHALLENGE_RESPONSE_WINDOW_BLOCK
        );

        // Third, upgrade the proxy contracts to use the correct implementation contracts and initialize them.
        tm = AOSChallengeManager(
            address(
                new TransparentUpgradeableProxy(
                    address(tmImplementation),
                    address(proxyAdmin),
                    abi.encodeWithSelector(
                        tm.initialize.selector,
                        pauserRegistry,
                        registryCoordinatorOwner,
                        aggregator
                    )
                )
            )
        );
    }

    function testCreateNewChallenge() public {
        bytes memory quorumNumbers = new bytes(0);
        cheats.prank(generator, generator);
        //tm.createNewChallenge(2,100, quorumNumbers);
        //assertEq(tm.latestChallengeNum(), 1);
    }
}
*/
