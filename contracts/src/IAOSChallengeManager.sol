// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@eigenlayer-middleware/src/libraries/BN254.sol";

interface IAOSChallengeManager {
    // EVENTS
    event NewChallengeCreated(uint32 indexed challengeIndex, Challenge challenge);

    event ChallengeResponded(
        ChallengeResponse challengeResponse,
        ChallengeResponseMetadata challengeResponseMetadata
    );

    // STRUCTS
    struct Challenge {
        uint256 clockNumber;
        bytes32 attestationHash;
        bytes signature;
        uint32 challengeCreatedBlock;
        uint32 quorumThresholdPercentage;
        bytes quorumNumbers;
    }

    // Challenge response is hashed and signed by operators.
    // these signatures are aggregated and sent to the contract as response.
    struct ChallengeResponse {
        // Can be obtained by the operator from the event NewChallengeCreated.
        uint32 referenceChallengeIndex;
        // This is just the response that the operator has to compute by itself.
        uint256 clockNumber;
        bytes32 attestationHash;
    }

    // Extra information related to challengeResponse, which is filled inside the contract.
    // It thus cannot be signed by operators, so we keep it in a separate struct than ChallengeResponse
    // This metadata is needed by the challenger, so we emit it in the ChallengeResponded event
    struct ChallengeResponseMetadata {
        uint32 challengeResponsedBlock;
    }

    // FUNCTIONS
    // NOTE: this function creates new challenge.
    function createNewChallenge(
        uint256 clockNumber,
        bytes32 attestationRoot,
        bytes calldata signature,
        uint32 quorumThresholdPercentage,
        bytes calldata quorumNumbers
    ) external;

    /// @notice Returns the current 'challengeNumber' for the middleware
    function challengeNumber() external view returns (uint32);


    /// @notice Returns the challenge_RESPONSE_WINDOW_BLOCK
    function getChallengeResponseWindowBlock() external view returns (uint32);
}
