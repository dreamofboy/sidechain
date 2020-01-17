pragma solidity >=0.4.0;
pragma experimental ABIEncoderV2;

interface ItemAPI {
    struct WorldInfo {
        uint64 ID;
        string  Name;
        address Owner;
        address Creator;
        string  Description;
        uint64 Total;
    }
    function GetWorldInfo(uint64 worldID) external returns(WorldInfo memory);

    struct ItemType {
        uint64 WorldID;
        uint64 ID;
        string  Name;
        bool Merge;
        uint64 UpperLimit;
        uint64 AddIssue;
        string  Description;
        uint64 Total;
        uint64 AttrTotal;
    }
    function GetItemType(uint64 worldID, uint64 itemTypeID) external returns(ItemType memory);

    struct Item {
        uint64 WorldID;
        uint64 TypeID;
        uint64 ID;
        address Owner;
        string Description;
        bool Destroy;
        uint64 AttrTotal;
    }
    function GetItem(uint64 worldID, uint64 itemTypeID, uint64 itemID) external returns(Item memory);

    struct Items {
        uint64 WorldID;
        uint64 TypeID;
        address Owner;
        uint64 Amount;
    }
    function GetItems(uint64 worldID, uint64 itemTypeID, string calldata owner) external returns(Items memory);

    function IssueWorld(string calldata owner, string calldata name, string calldata description) external returns(uint64);
    function UpdateWorldOwner(string calldata owner, uint64 worldID) external;
    function IssueItemType(uint64 worldID, string calldata name, bool merge, uint64 upperLimit, string calldata description, uint64[] calldata attrPermission, string[] calldata attrName, string[] calldata attrDes) external returns(uint64);
    function IncreaseItem(uint64 worldID, uint64 itemTypeID, string calldata owner, string calldata description, uint64[] calldata attrPermission, string[] calldata attrName, string[] calldata attrDes) external;
    function DestroyItem(uint64 worldID, uint64 itemTypeID, uint64 itemID) external;
    function IncreaseItems(uint64 worldID, uint64 itemTypeID, string calldata to, uint64 amount) external;
    function DestroyItems(uint64 worldID, uint64 itemTypeID, uint64 amount) external;
    function TransferItem(string calldata to, uint64[] calldata worldID, uint64[] calldata itemTypeID, uint64[] calldata itemID, uint64[] calldata amount) external;
    function AddItemTypeAttributes(uint64 worldID, uint64 itemTypeID, uint64[] calldata attrPermission, string[] calldata attrName, string[] calldata attrDes) external;
    function DelItemTypeAttributes(uint64 worldID, uint64 itemTypeID, string[] calldata attrName) external;
    function ModifyItemTypeAttributes(uint64 worldID, uint64 itemTypeID, uint64[] calldata attrPermission, string[] calldata attrName, string[] calldata attrDes) external;
    function AddItemAttributes(uint64 worldID, uint64 itemTypeID, uint64 itemID, uint64[] calldata attrPermission, string[] calldata attrName, string[] calldata attrDes) external;
    function DelItemAttributes(uint64 worldID, uint64 itemTypeID, uint64 itemID, string[] calldata attrName) external;
    function ModifyItemAttributes(uint64 worldID, uint64 itemTypeID, uint64 itemID, uint64[] calldata attrPermission, string[] calldata attrName, string[] calldata attrDes) external;
}
