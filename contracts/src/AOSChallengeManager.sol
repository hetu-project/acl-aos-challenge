// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";
import "@eigenlayer/contracts/permissions/Pausable.sol";
import "@eigenlayer-middleware/src/interfaces/IServiceManager.sol";
import {BLSApkRegistry} from "@eigenlayer-middleware/src/BLSApkRegistry.sol";
import {RegistryCoordinator} from "@eigenlayer-middleware/src/RegistryCoordinator.sol";
import {BLSSignatureChecker, IRegistryCoordinator} from "@eigenlayer-middleware/src/BLSSignatureChecker.sol";
//import {OperatorStateRetriever} from "@eigenlayer-middleware/src/OperatorStateRetriever.sol";
import "@eigenlayer-middleware/src/libraries/BN254.sol";
import "./IAOSChallengeManager.sol";

contract AOSChallengeManager is
    Initializable,
    OwnableUpgradeable,
    Pausable,
    BLSSignatureChecker,
    IAOSChallengeManager
{
    using BN254 for BN254.G1Point;

    /* CONSTANT */
    // The number of blocks from the challenge initialization within which the aggregator has to respond to
    uint32 public immutable CHALLENGE_RESPONSE_WINDOW_BLOCK;
    uint32 public constant CHALLENGE_CHALLENGE_WINDOW_BLOCK = 100;
    uint256 internal constant _THRESHOLD_DENOMINATOR = 100;

    /* STORAGE */
    // The latest challenge index
    uint32 public latestChallengeNum;

    // mapping of challenge indices to all challenges hashes
    // when a challenge is created, challenge hash is stored here,
    // and responses need to pass the actual challenge,
    // which is hashed onchain and checked against this mapping
    mapping(uint32 => bytes32) public allChallengeHashes;

    // mapping of challenge indices to hash of abi.encode(challengeResponse, challengeResponseMetadata)
    mapping(uint32 => bytes32) public allChallengeResponses;

    mapping(uint32 => bool) public challengeSuccesfullyChallenged;

    address public aggregator;

    /* MODIFIERS */
    modifier onlyAggregator() {
        require(msg.sender == aggregator, "Aggregator must be the caller");
        _;
    }

    constructor(
        IRegistryCoordinator _registryCoordinator,
        uint32 _challengeResponseWindowBlock
    ) BLSSignatureChecker(_registryCoordinator) {
        CHALLENGE_RESPONSE_WINDOW_BLOCK = _challengeResponseWindowBlock;
    }

    function initialize(
        IPauserRegistry _pauserRegistry,
        address initialOwner,
        address _aggregator
    ) public initializer {
        _initializePauser(_pauserRegistry, UNPAUSE_ALL);
        _transferOwnership(initialOwner);
        aggregator = _aggregator;
    }

    /* FUNCTIONS */
    // NOTE: this function creates new challenge, assigns it a challengeId
    function createNewChallenge(
        uint256 clockNumber,
        bytes32 attestationHash,
        bytes calldata signature,
        uint32 quorumThresholdPercentage,
        bytes calldata quorumNumbers
    ) external {
        //TODO pay challeng fee
        // create a new challenge struct
        Challenge memory newChallenge;
        newChallenge.clockNumber = clockNumber;
        newChallenge.challengeCreatedBlock = uint32(block.number);
        newChallenge.attestationHash = attestationHash;
        newChallenge.signature= signature;
        newChallenge.quorumThresholdPercentage = quorumThresholdPercentage;
        newChallenge.quorumNumbers = quorumNumbers;

        // store hash of challenge onchain, emit event, and increase challengeNum
        allChallengeHashes[latestChallengeNum] = keccak256(abi.encode(newChallenge));
        emit NewChallengeCreated(latestChallengeNum, newChallenge);
        latestChallengeNum = latestChallengeNum + 1;
    }

    // NOTE: this function responds to existing challenges.
    function respondToChallenge(
        Challenge calldata challenge,
        ChallengeResponse calldata challengeResponse,
        NonSignerStakesAndSignature memory nonSignerStakesAndSignature
    ) external onlyAggregator {
        uint32 challengeCreatedBlock = challenge.challengeCreatedBlock;
        bytes calldata quorumNumbers = challenge.quorumNumbers;
        uint32 quorumThresholdPercentage = challenge.quorumThresholdPercentage;

        // check that the challenge is valid, hasn't been responsed yet, and is being responsed in time
        require(
            keccak256(abi.encode(challenge)) ==
                allChallengeHashes[challengeResponse.referenceChallengeIndex],
            "supplied challenge does not match the one recorded in the contract"
        );
        // some logical checks
        require(
            allChallengeResponses[challengeResponse.referenceChallengeIndex] == bytes32(0),
            "Aggregator has already responded to the challenge"
        );
        require(
            uint32(block.number) <=
                challengeCreatedBlock + CHALLENGE_RESPONSE_WINDOW_BLOCK,
            "Aggregator has responded to the challenge too late"
        );

        /* CHECKING SIGNATURES & WHETHER THRESHOLD IS MET OR NOT */
        // calculate message which operators signed
        bytes32 message = keccak256(abi.encode(challengeResponse));

        // check the BLS signature
        (
            QuorumStakeTotals memory quorumStakeTotals,
            bytes32 hashOfNonSigners
        ) = checkSignatures(
                message,
                quorumNumbers,
                challengeCreatedBlock,
                nonSignerStakesAndSignature
            );

        // check that signatories own at least a threshold percentage of each quourm
        for (uint i = 0; i < quorumNumbers.length; i++) {
            // we don't check that the quorumThresholdPercentages are not >100 because a greater value would trivially fail the check, implying
            // signed stake > total stake
            require(
                quorumStakeTotals.signedStakeForQuorum[i] *
                    _THRESHOLD_DENOMINATOR >=
                    quorumStakeTotals.totalStakeForQuorum[i] *
                        uint8(quorumThresholdPercentage),
                "Signatories do not own at least threshold percentage of a quorum"
            );
        }

        ChallengeResponseMetadata memory challengeResponseMetadata = ChallengeResponseMetadata(
            uint32(block.number)
        );
        // updating the storage with challenge responsea
        allChallengeResponses[challengeResponse.referenceChallengeIndex] = keccak256(
            abi.encode(challengeResponse, challengeResponseMetadata)
        );

        // emitting event
        emit ChallengeResponded(challengeResponse, challengeResponseMetadata);
    }

    function challengeNumber() external view returns (uint32) {
        return latestChallengeNum;
    }


    function getChallengeResponseWindowBlock() external view returns (uint32) {
        return CHALLENGE_RESPONSE_WINDOW_BLOCK;
    }
}
