// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface ICrossChainBalance {
    function setAutomationCronContract(address _upkeepContract) external;
    function updateRequest(bytes memory _request) external;
    function sendRequestCBOR() external;
    function removeActiveRequest(uint256 serialNumber) external;
    function getLatestSerialNumber() external view returns (uint256);
    function getBalance(uint256 _serialNumber) external view returns (uint256);
}
