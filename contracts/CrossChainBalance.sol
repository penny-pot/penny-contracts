// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/dev/v1_0_0/FunctionsClient.sol";
import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";

contract CrossChainBalance is FunctionsClient, ConfirmedOwner {
    address public upkeepContract;
    uint64 private subscriptionId;
    uint32 private gasLimit;
    bytes32 private donID;

    struct Request {
        bytes request;
        uint64 subscriptionId;
        uint32 gasLimit;
        bytes32 donID;
    }

    struct Response {
        bytes32 requestId;
        bytes response;
        bytes err;
    }

    uint256[] public activeRequests;
    uint256 public requestCounter;
    mapping(uint256 => Request) public requests;
    mapping(uint256 => bytes32) public requestsIDs;
    mapping(bytes32 => Response) public responses;

    error NotAllowedCaller(
        address caller,
        address owner,
        address automationRegistry
    );

    event RequestUpdated(uint256 indexed requestId);
    event ResponseReceived(
        bytes32 indexed requestId,
        bytes response,
        bytes err
    );

    constructor(address router)
        FunctionsClient(router)
        ConfirmedOwner(msg.sender)
    {
        subscriptionId = 4233;
        gasLimit = 300000;
        donID = "fun-avalanche-fuji-1";
    }

    function setAutomationCronContract(address _upkeepContract)
        external
        onlyOwner
    {
        require(upkeepContract != address(0), "Invalid contract address");
        upkeepContract = _upkeepContract;
    }

    function updateRequest(bytes memory _request) external {
        uint256 serialNumber = ++requestCounter;
        requests[serialNumber] = Request({
            request: _request,
            subscriptionId: subscriptionId,
            gasLimit: gasLimit,
            donID: donID
        });

        addActiveRequest(serialNumber);

        emit RequestUpdated(serialNumber);
    }

    function sendRequestCBOR() external {
        for (uint256 i = 0; i < activeRequests.length; i++) {
            uint256 requestSerialNumber = activeRequests[i];
            Request storage req = requests[requestSerialNumber];

            bytes32 s_lastRequestId = _sendRequest(
                req.request,
                req.subscriptionId,
                req.gasLimit,
                req.donID
            );

            requestsIDs[requestSerialNumber] = s_lastRequestId;
        }
    }

    function fulfillRequest(
        bytes32 requestId,
        bytes memory response,
        bytes memory err
    ) internal override {
        responses[requestId] = Response({
            requestId: requestId,
            response: response,
            err: err
        });
        emit ResponseReceived(requestId, response, err);
    }

    function addActiveRequest(uint256 serialNumber) internal {
        activeRequests.push(serialNumber);
    }

    function removeActiveRequest(uint256 serialNumber) external {
        for (uint256 i = 0; i < activeRequests.length; i++) {
            if (activeRequests[i] == serialNumber) {
                activeRequests[i] = activeRequests[activeRequests.length - 1];
                activeRequests.pop();
                break;
            }
        }
    }

    // Function to get the latest serial number
    function getLatestSerialNumber() external view returns (uint256) {
        return requestCounter;
    }

    // Function to get the balance associated with a serialNumber
    function getBalance(uint256 _serialNumber) external view returns (uint256) {
        bytes32 id = requestsIDs[_serialNumber];
        bytes memory response = responses[id].response;

        // Parse the response as a uint256
        uint256 balanceResult;
        assembly {
            balanceResult := mload(add(response, 32))
        }
        return balanceResult;
    }
}
