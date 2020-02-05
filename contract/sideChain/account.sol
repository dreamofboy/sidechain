pragma solidity >=0.4.0;
pragma experimental ABIEncoderV2;

interface AccountAPI {
    function CreateAccount(string calldata name, string calldata pubKey, string calldata desc) external;
    function ChangePubKey(string calldata pubKey) external;
    function GetBalance(string calldata to, uint64 assetid) external returns(uint256);
    function Transfer(string calldata to, uint64 assetid, uint256 value) external;
    function AddressToString(address name) external returns(string memory);
    function StringToAddress(string calldata name) external returns(address);
    function ECVerify(address name, bytes32 dataHash, bytes calldata sig) external returns(bool);
    function IsExist(string calldata name) external returns(bool);
}