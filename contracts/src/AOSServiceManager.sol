// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@eigenlayer/contracts/libraries/BytesLib.sol";
import "@eigenlayer-middleware/src/ServiceManagerBase.sol";
import {IPauserRegistry} from "eigenlayer-contracts/src/contracts/interfaces/IPauserRegistry.sol";
import {Pausable} from "eigenlayer-contracts/src/contracts/permissions/Pausable.sol";
import {IServiceManager} from "@eigenlayer-middleware/src/interfaces/IServiceManager.sol";

/**
 * @title Primary entrypoint for procuring services from AOS.
 */
contract AOSServiceManager is ServiceManagerBase, Pausable {
    using BytesLib for bytes;

    uint8 public constant PAUSED_OPERTOR_REGISTRATION = 1;
    uint256 constant MAX_RANGE = 600000; // Maximum range value

    struct OperatorRange {
        uint256 start;
        uint256 end;
    }

    mapping(address => OperatorRange) public operatorRanges; // Using operator address as the index
    address[] public operators; // Storing all registered operator addresses

    constructor(
        IAVSDirectory _avsDirectory,
        IRegistryCoordinator _registryCoordinator,
        IStakeRegistry _stakeRegistry
    )
        ServiceManagerBase(
            _avsDirectory,
            IPaymentCoordinator(address(0)), // inc-sq doesn't need to deal with payments
            _registryCoordinator,
            _stakeRegistry
        )
    {
        _disableInitializers();
    }

    function initialize(
        IPauserRegistry _pauserRegistry,
        uint256 _initialPausedStatus,
        address _initialOwner
    ) public initializer {
        _initializePauser(_pauserRegistry, _initialPausedStatus);
        __ServiceManagerBase_init(_initialOwner);
    }

    function registerOperatorToAVS(
        address operator,
        ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature) 
        public 
        override(ServiceManagerBase)
        onlyWhenNotPaused(PAUSED_OPERTOR_REGISTRATION)
        onlyRegistryCoordinator 
    {
        require(!isOperatorRegistered(operator), "Operator already registered");
        operators.push(operator);
        _avsDirectory.registerOperatorToAVS(operator, operatorSignature);
    }

    function deregisterOperatorFromAVS(address operator) 
        public 
        override(ServiceManagerBase)
        onlyWhenNotPaused(PAUSED_OPERTOR_REGISTRATION)
        onlyRegistryCoordinator 
    {
        _avsDirectory.deregisterOperatorFromAVS(operator);
    }

    //TODO permit to update
    function updateOperatorRange(address operatorAddress, uint256 start, uint256 end) public onlyOwner {
        require(isOperatorRegistered(operatorAddress), "Operator not registered");
        require(start < end, "Start range must be less than end range");
        require(end <= MAX_RANGE, "End range cannot exceed maximum range");
        operatorRanges[operatorAddress] = OperatorRange(start, end);
    }

    function getOperatorsInRange(uint256 value) public view returns (address[] memory) {
        address[] memory operatorsInRange = new address[](operators.length);
        uint256 count = 0;
        
        for (uint256 i = 0; i < operators.length; i++) {
            address operatorAddress = operators[i];
            OperatorRange memory range = operatorRanges[operatorAddress];
            if (value >= range.start && value <= range.end) {
                operatorsInRange[count] = operatorAddress;
                count++;
            }
        }
        
        // Create a new array containing only the matched operator addresses
        address[] memory result = new address[](count);
        for (uint256 i = 0; i < count; i++) {
            result[i] = operatorsInRange[i];
        }
        return result;
    }

    function getNumOperators() public view returns (uint256) {
        return operators.length;
    }

    function getOperatorRange(address operatorAddress) private view returns (uint256 start, uint256 end) {
        OperatorRange memory range = operatorRanges[operatorAddress];
        start = range.start;
        end = range.end;
    }

    function isOperatorRegistered(address operatorAddress) private view returns (bool) {
        for (uint256 i = 0; i < operators.length; i++) {
            if (operators[i] == operatorAddress) {
                return true;
            }
        }
        return false;
    }

}
