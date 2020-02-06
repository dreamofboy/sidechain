pragma solidity ^0.5.7;
pragma experimental ABIEncoderV2;

//import "./ITRC20Receiver.sol";
//import "./ITRC721Receiver.sol";
import "./ECVerify.sol";
import "./DataModel.sol";
import "./Ownable.sol";
import "./item.sol";
import "./account.sol";

// issue:
// 1. 侧链账户不存在如何办
// 2. ItemID => WithdrawMsg
// 3. 手续费

// address+decimals+tokenID+type
// 1. item => trx/trc10/trc20


contract SideChainGateway is Ownable {
    using ECVerify for bytes32;

    AccountAPI account = AccountAPI(address(bytes20("fractalaccount")));
    ItemAPI constant item = ItemAPI(address(bytes20("fractalitem")));

    // 1. deployDAppTRC20AndMapping
    // 2. deployDAppTRC721AndMapping
    // 3. depositTRC10
    // 4. depositTRC20
    // 5. depositTRC721
    // 6. depositTRX
    // 7. withdrawTRC10
    // 8. withdrawTRC20
    // 9. withdrawTRC721
    // 10. withdrawTRX

    // onRecvxxx withdraw side->main

    enum TronType {
        SUCCESS, // 0
        LOCKING, // 1
        FAIL, // 2
        REFUNDED        // 3
    }


    event DeployDAppTRC20AndMapping(address mainChainAddress, uint64 worldID, uint64 itemID, uint256 nonce);
    event DeployDAppTRC721AndMapping(address mainChainAddress, uint64 worldID, uint64 itemID, uint256 nonce);

    event DepositTRC10(string to, uint256 tokenID, uint256 value, uint64 worldID, uint64 itemID, uint64 sideValue, uint256 nonce);
    event DepositTRC20(string to, address mainChainAddress, uint256 value, uint64 worldID, uint64 itemID, uint64 sideValue, uint256 nonce);
    event DepositTRC721(string to, address mainChainAddress, uint256 UID, uint64 worldID, uint64 itemID, uint64 sideUID, uint256 nonce);
    event DepositTRX(string to, uint64 worldID, uint256 itemID, uint256 value, uint64 sideValue, uint256 nonce);

    event WithdrawTRC10(address to, uint256 tokenId, uint256 value, uint256 nonce);
    event WithdrawTRC20(address to, address mainChainAddress, uint256 value, uint256 nonce);
    event WithdrawTRC721(address to, address mainChainAddress, uint256 uId, uint256 nonce);
    event WithdrawTRX(address to, uint256 value, uint256 nonce);

    event MultiSignForWithdrawTRC10(address from, uint256 tokenId, uint256 value, uint256 nonce);
    event MultiSignForWithdrawTRC20(address from, address mainChainAddress, uint256 value, uint256 nonce);
    event MultiSignForWithdrawTRC721(address from, address mainChainAddress, uint256 uId, uint256 nonce);
    event MultiSignForWithdrawTRX(address from, uint256 value, uint256 nonce);

    uint64 public worldID;

    uint256 public numOracles;
    address public sunTokenAddress;
    uint256 public withdrawMinTrx = 1;
    uint256 public withdrawMinTrc10 = 1;
    uint256 public withdrawMinTrc20 = 1;
    uint256 public withdrawFee = 0;
    uint256 public retryFee = 0;
    uint256 public bonus;
    bool public pause;
    bool public stop;
    mapping(address => MappingType) public mainToSideContractMap;
    mapping(uint256 => address) public sideToMainContractMap;
    address[] public mainContractList;
    mapping(address => bool) public oracles;

    mapping(uint256 => SignMsg) public depositSigns;
    mapping(uint256 => SignMsg) public withdrawSigns;
    mapping(uint256 => SignMsg) public mappingSigns;
    mapping(address => SignMsg) public changeLogicSigns;

    WithdrawMsg[] userWithdrawList;

    struct MappingType {
        address mainAddress;
        uint256 tokenID;
        uint8 decimals;
        uint64 itemID;
        uint64 UID;
        mapping(uint64 => uint256) side721ToMain;
        mapping(uint256 => uint64) main721ToSide;
        DataModel.TokenKind _type;
    }

    struct SignMsg {
        mapping(address => bool) oracleSigned;
        bytes[] signs;
        address[] signOracles;
        uint256 signCnt;
        bool success;
    }

    struct WithdrawMsg {
        address user;
        address mainChainAddress;
        uint256 tokenId;
        uint256 valueOrUid;
        DataModel.TokenKind _type;
        DataModel.Status status;
    }

    modifier onlyOracle {
        require(oracles[msg.sender], "oracles[msg.sender] is false");
        _;
    }

    modifier isHuman() {
        require(msg.sender == tx.origin, "not allow contract");
        _;
    }

    modifier checkForTrc10(uint256 tokenId, uint256 tokenValue) {
        // todo
        /*
        require(tokenId == uint256(msg.tokenid), "tokenId != msg.tokenid");
        require(tokenValue == msg.tokenvalue, "tokenValue != msg.tokenvalue");
        */
        _;
    }

    modifier onlyNotPause {
        require(!pause, "pause is true");
        _;
    }

    modifier onlyNotStop {
        require(!stop, "stop is true");
        _;
    }

    constructor() Ownable() public {
        worldID = item.IssueWorld(account.AddressToString(address(this)), "tronsidechan", "tron sidechain");

        uint64[] memory attrPermission = new uint64[](0);
        string[] memory attrName = new string[](0);
        string[] memory attrDes = new string[](0);
        uint64 itemID = item.IssueItemType(worldID, "trx", true, 0, "trx in here", attrPermission, attrName, attrDes);

        MappingType storage sideType = mainToSideContractMap[address(1)];
        sideType.decimals = 6;
        sideType.itemID = itemID;
        sideType._type = DataModel.TokenKind.TRX;

        uint256 itemKey = itemEncode(itemID);
        sideToMainContractMap[itemKey] = address(1);
    }

    function v64(uint256 value, uint8 decimals)private pure returns(uint64) {
        value /= uint256(10)**decimals;
        require(value < (1<<64)-1, "only uint64");
        return uint64(value);
    }

    function v256(uint64 value, uint8 decimals) private pure returns(uint256) {
        return (uint256(10)**decimals) * value;
    }

    function getWithdrawSigns(uint256 nonce) view public returns (bytes[] memory, address[] memory) {
        return (withdrawSigns[nonce].signs, withdrawSigns[nonce].signOracles);
    }

    function addOracle(address _oracle) public goDelegateCall onlyOwner {
        require(_oracle != address(0), "this address cannot be zero");
        require(!oracles[_oracle], "_oracle is oracle");
        oracles[_oracle] = true;
        numOracles++;
    }

    function delOracle(address _oracle) public goDelegateCall onlyOwner {
        require(oracles[_oracle], "_oracle is not oracle");
        oracles[_oracle] = false;
        numOracles--;
    }

    function setSunTokenAddress(address _sunTokenAddress) public goDelegateCall onlyOwner {
        require(_sunTokenAddress != address(0), "_sunTokenAddress == address(0)");
        sunTokenAddress = _sunTokenAddress;
    }

    // 1. deployDAppTRC20AndMapping
    function multiSignForDeployDAppTRC20AndMapping(address mainChainAddress, string memory name,
        string memory symbol, uint8 decimals, string memory contractOwner, uint256 nonce)
    public goDelegateCall onlyNotStop onlyOracle
    {
        require(mainChainAddress != sunTokenAddress, "mainChainAddress == sunTokenAddress");
        bool needMapping = multiSignForMapping(nonce);
        if (needMapping) {
            deployDAppTRC20AndMapping(mainChainAddress, name, symbol, decimals, contractOwner, nonce);
        }
    }
    function itemEncode(uint64 itemID) private view returns(uint256) {
        return (uint256(worldID) << 64) | uint256(itemID);
    }

    function deployDAppTRC20AndMapping(address mainChainAddress, string memory name,
        string memory symbol, uint8 decimals, string memory contractOwner, uint256 nonce) internal
    {
        // doit
        MappingType storage sideType = mainToSideContractMap[mainChainAddress];
        require(sideType.mainAddress == address(0), "TRC20 contract is mapped");
        {
            uint64[] memory attrPermission = new uint64[](0);
            string[] memory attrName = new string[](0);
            string[] memory attrDes = new string[](0);
            uint64 itemID = item.IssueItemType(worldID, name, true, 0, "trc20", attrPermission, attrName, attrDes);

            uint256 itemKey = itemEncode(itemID);
            sideType.mainAddress = mainChainAddress;
            sideType.itemID = itemID;
            sideType.decimals = decimals;
            sideType._type = DataModel.TokenKind.TRC20;
            sideToMainContractMap[itemKey] = mainChainAddress;
        }
        emit DeployDAppTRC20AndMapping(mainChainAddress, worldID, sideType.itemID, nonce);
        mainContractList.push(mainChainAddress);
    }

    // 2. deployDAppTRC721AndMapping
    function multiSignForDeployDAppTRC721AndMapping(address mainChainAddress, string memory name,
        string memory symbol, string memory contractOwner, uint256 nonce)
    public goDelegateCall onlyNotStop onlyOracle
    {
        require(mainChainAddress != sunTokenAddress, "mainChainAddress == sunTokenAddress");
        bool needMapping = multiSignForMapping(nonce);
        if (needMapping) {
            deployDAppTRC721AndMapping(mainChainAddress, name, symbol, contractOwner, nonce);
        }
    }

    function deployDAppTRC721AndMapping(address mainChainAddress, string memory name,
        string memory symbol, string memory contractOwner, uint256 nonce) internal
    {
        // doit
        MappingType storage sideType = mainToSideContractMap[mainChainAddress];
        require(sideType.mainAddress == address(0), "TRC721 contract is mapped");

        {
            uint64[] memory attrPermission = new uint64[](0);
            string[] memory attrName = new string[](0);
            string[] memory attrDes = new string[](0);
            uint64 itemID = item.IssueItemType(worldID, name, false, 0, "trc721", attrPermission, attrName, attrDes);
            sideType.mainAddress = mainChainAddress;
            sideType._type = DataModel.TokenKind.TRC721;
            sideType.itemID = itemID;
            
            uint256 itemKey = itemEncode(itemID);
            sideToMainContractMap[itemKey] = mainChainAddress;
        }
        emit DeployDAppTRC721AndMapping(mainChainAddress, worldID, sideType.itemID, nonce);
        mainContractList.push(mainChainAddress);
        
    }

    function multiSignForMapping(uint256 nonce) internal returns (bool) {
        SignMsg storage _signMsg = mappingSigns[nonce];
        if (_signMsg.oracleSigned[msg.sender]) {
            return false;
        }
        _signMsg.oracleSigned[msg.sender] = true;
        _signMsg.signCnt += 1;

        if (!_signMsg.success && _signMsg.signCnt > numOracles * 2 / 3) {
            _signMsg.success = true;
            return true;
        }
        return false;
    }
    function accountCheck(string memory accountStr) private {
        /*
        if (!account.IsExist(account))
            account.CreateAccount(account, "", "");
        */
    }
    // 3. depositTRC10
    function multiSignForDepositTRC10(string memory to, uint256 tokenId,
        uint256 value, bytes32 name, bytes32 symbol, uint8 decimals, uint256 nonce)
    public goDelegateCall onlyNotStop onlyOracle
    {
        require(tokenId > 1000000 && tokenId < 2000000, "tokenId <= 1000000 or tokenId >= 2000000");
        bool needDeposit = multiSignForDeposit(nonce);
        if (needDeposit) {
            depositTRC10(to, tokenId, value, name, symbol, decimals, nonce);
        }
    }

    function depositTRC10(string memory to, uint256 tokenId,
        uint256 value, bytes32 name, bytes32 symbol, uint8 decimals, uint256 nonce) internal
    {
        MappingType storage sideType = mainToSideContractMap[address(tokenId)];
        if( sideType.tokenID == 0 ){
            uint64[] memory attrPermission = new uint64[](0);
            string[] memory attrName = new string[](0);
            string[] memory attrDes = new string[](0);
            uint64 itemID = item.IssueItemType(worldID, "trc10", true, 0, "trc10", attrPermission, attrName, attrDes);

            sideType.tokenID = tokenId;
            sideType.decimals = decimals;
            sideType.itemID = itemID;
            sideType._type = DataModel.TokenKind.TRC10;

            uint256 itemKey = itemEncode(itemID);
            sideToMainContractMap[itemKey] = address(tokenId);
        }
        uint64 value64 = v64(value, sideType.decimals);
        item.IncreaseItems(worldID, sideType.itemID, to, value64);
        emit DepositTRC10(to, tokenId, value, worldID, sideType.itemID, value64, nonce);
    }

    // 4. depositTRC20
    function multiSignForDepositTRC20(string memory to, address mainChainAddress,
        uint256 value, uint256 nonce)
    public goDelegateCall onlyNotStop onlyOracle
    {
        MappingType storage sideType = mainToSideContractMap[mainChainAddress];
        require(sideType._type == DataModel.TokenKind.TRC20 && sideType.mainAddress == mainChainAddress, "the main chain address hasn't mapped");
        bool needDeposit = multiSignForDeposit(nonce);
        if (needDeposit) {
            depositTRC20(to, sideType, value, nonce);
        }
    }

    function depositTRC20(string memory to, MappingType storage sideType, uint256 value, uint256 nonce) internal {
        // doit
        {
            uint64 value64 = v64(value, sideType.decimals);
            item.IncreaseItems(worldID, sideType.itemID, to, value64);
            emit DepositTRC20(to, sideType.mainAddress, value, worldID, sideType.itemID, value64, nonce);
        }
    }

    // 5. depositTRC721
    function multiSignForDepositTRC721(string memory to, address mainChainAddress, uint256 uId, uint256 nonce)
    public goDelegateCall onlyNotStop onlyOracle {
        MappingType storage sideType = mainToSideContractMap[mainChainAddress];
        require(sideType._type == DataModel.TokenKind.TRC721 && sideType.mainAddress == mainChainAddress, "the main chain address hasn't mapped");
        bool needDeposit = multiSignForDeposit(nonce);
        if (needDeposit) {
            depositTRC721(to, sideType, uId, nonce);
        }
    }

    function depositTRC721(string memory to, MappingType storage sideType, uint256 uId, uint256 nonce) internal {
        // doit
        {
            uint64[] memory attrPermission = new uint64[](0);
            string[] memory attrName = new string[](0);
            string[] memory attrDes = new string[](0);
            uint64 newUID = item.IncreaseItem(worldID, sideType.itemID, to, "depositTRC721", attrPermission, attrName, attrDes);
            sideType.main721ToSide[uId] = newUID;
            sideType.side721ToMain[newUID] = uId;
            emit DepositTRC721(to, sideType.mainAddress, uId, worldID, sideType.itemID, newUID, nonce);
        }
    }

    // 6. depositTRX
    function multiSignForDepositTRX(string memory to, uint256 value, uint256 nonce) public goDelegateCall onlyNotStop onlyOracle {
        bool needDeposit = multiSignForDeposit(nonce);
        if (needDeposit) {
            depositTRX(to, value, nonce);
        }
    }

    function depositTRX(string memory to, uint256 value, uint256 nonce) internal {
        MappingType storage sideType = mainToSideContractMap[address(1)];
        uint64 value64 = v64(value, sideType.decimals);
        item.IncreaseItems(worldID, sideType.itemID, to, value64);
        emit DepositTRX(to, worldID, sideType.itemID, value, value64, nonce);
    }

    function multiSignForDeposit(uint256 nonce) internal returns (bool) {
        SignMsg storage _signMsg = depositSigns[nonce];
        if (_signMsg.oracleSigned[msg.sender]) {
            return false;
        }
        _signMsg.oracleSigned[msg.sender] = true;
        _signMsg.signCnt += 1;

        if (!_signMsg.success && _signMsg.signCnt > numOracles * 2 / 3) {
            _signMsg.success = true;
            return true;
        }
        return false;
    }

    function multiSignForWithdrawTRC10(uint256 nonce, bytes memory oracleSign)
    public goDelegateCall onlyNotStop onlyOracle {
        if (!countMultiSignForWithdraw(nonce, oracleSign)) {
            return;
        }

        WithdrawMsg storage withdrawMsg = userWithdrawList[nonce];
        bytes32 dataHash = keccak256(abi.encodePacked(withdrawMsg.user, withdrawMsg.tokenId, withdrawMsg.valueOrUid, nonce));
        if (countSuccessSignForWithdraw(nonce, dataHash)) {
            emit MultiSignForWithdrawTRC10(withdrawMsg.user, withdrawMsg.tokenId, withdrawMsg.valueOrUid, nonce);
        }
    }

    function ItemsWithdraw(address to, uint64 itemID, uint64 valueOrID) public payable goDelegateCall onlyNotPause onlyNotStop returns(uint256 nonce) {
        address mainAddress = sideToMainContractMap[itemEncode(itemID)];
        require(mainAddress != address(0), "invalid sideAddress");
        require(msg.value >= withdrawFee, "msg.value must >= withdrawFee");
        bonus += withdrawFee;
        MappingType storage sideType = mainToSideContractMap[mainAddress];
        string memory sender = account.AddressToString(msg.sender);
        uint256 mainValue = v256(valueOrID, sideType.decimals);
        userWithdrawList.push(WithdrawMsg(to, sideType.mainAddress, sideType.tokenID, mainValue, sideType._type, DataModel.Status.SUCCESS));
        nonce = userWithdrawList.length - 1;
        if (sideType._type == DataModel.TokenKind.TRX) {
            // withdraw trx
            require(mainValue >= withdrawMinTrx, "withdraw must >= withdrawMinTrx");
            item.DestroyItemFrom(sender, worldID, sideType.itemID, 0, valueOrID);
            emit WithdrawTRX(to, mainValue, nonce);
            return nonce;
        }
        if (sideType._type == DataModel.TokenKind.TRC10) {
            require(mainValue >= withdrawMinTrc10, "withdraw must >= withdrawMinTrc10");
            item.DestroyItemFrom(sender, worldID, sideType.itemID, 0, valueOrID);
            emit WithdrawTRC10(to, sideType.tokenID, mainValue, nonce);
            return nonce;
        }
        if (sideType._type == DataModel.TokenKind.TRC20) {
            require(mainValue >= withdrawMinTrc20, "withdraw must >= withdrawMinTrc20");
            item.DestroyItemFrom(sender, worldID, sideType.itemID, 0, valueOrID);
            emit WithdrawTRC20(to, sideType.mainAddress, mainValue, nonce);
            return nonce;
        }
        if (sideType._type == DataModel.TokenKind.TRC721) {
            item.DestroyItemFrom(sender, worldID, sideType.itemID, valueOrID, 0);
            emit WithdrawTRC721(to, sideType.mainAddress, sideType.side721ToMain[sideType.itemID], nonce);
            return nonce;
        }
        revert("wrong params");
    }

    function multiSignForWithdrawTRC20(uint256 nonce, bytes memory oracleSign)
    public goDelegateCall onlyNotStop onlyOracle {
        if (!countMultiSignForWithdraw(nonce, oracleSign)) {
            return;
        }

        WithdrawMsg storage withdrawMsg = userWithdrawList[nonce];
        bytes32 dataHash = keccak256(abi.encodePacked(withdrawMsg.user, withdrawMsg.mainChainAddress, withdrawMsg.valueOrUid, nonce));
        if (countSuccessSignForWithdraw(nonce, dataHash)) {
            emit MultiSignForWithdrawTRC20(withdrawMsg.user, withdrawMsg.mainChainAddress, withdrawMsg.valueOrUid, nonce);
        }
    }

    function multiSignForWithdrawTRC721(uint256 nonce, bytes memory oracleSign)
    public goDelegateCall onlyNotStop onlyOracle {
        if (!countMultiSignForWithdraw(nonce, oracleSign)) {
            return;
        }

        WithdrawMsg storage withdrawMsg = userWithdrawList[nonce];
        bytes32 dataHash = keccak256(abi.encodePacked(withdrawMsg.user, withdrawMsg.mainChainAddress, withdrawMsg.valueOrUid, nonce));
        if (countSuccessSignForWithdraw(nonce, dataHash)) {
            emit MultiSignForWithdrawTRC721(withdrawMsg.user, withdrawMsg.mainChainAddress, withdrawMsg.valueOrUid, nonce);
        }
    }

    function multiSignForWithdrawTRX(uint256 nonce, bytes memory oracleSign)
    public goDelegateCall onlyNotStop onlyOracle {
        if (!countMultiSignForWithdraw(nonce, oracleSign)) {
            return;
        }

        WithdrawMsg storage withdrawMsg = userWithdrawList[nonce];
        bytes32 dataHash = keccak256(abi.encodePacked(withdrawMsg.user, withdrawMsg.valueOrUid, nonce));
        if (countSuccessSignForWithdraw(nonce, dataHash)) {
            emit MultiSignForWithdrawTRX(withdrawMsg.user, withdrawMsg.valueOrUid, nonce);
        }
    }

    function countMultiSignForWithdraw(uint256 nonce, bytes memory oracleSign) internal returns (bool){
        SignMsg storage _signMsg = withdrawSigns[nonce];
        if (_signMsg.oracleSigned[msg.sender]) {
            return false;
        }
        _signMsg.oracleSigned[msg.sender] = true;
        _signMsg.signs.push(oracleSign);
        _signMsg.signOracles.push(msg.sender);
        _signMsg.signCnt += 1;
        if (!_signMsg.success && _signMsg.signCnt > numOracles * 2 / 3) {
            return true;
        }
        return false;
    }

    // 11. retryWithdraw
    function retryWithdraw(uint256 nonce) payable public goDelegateCall onlyNotPause onlyNotStop isHuman {
        require(msg.value >= retryFee, "msg.value need  >= retryFee");
        if (msg.value > retryFee) {
            msg.sender.transfer(msg.value - retryFee);
        }
        bonus += retryFee;
        require(nonce < userWithdrawList.length, "nonce >= userWithdrawList.length");
        WithdrawMsg storage withdrawMsg = userWithdrawList[nonce];
        if (withdrawMsg._type == DataModel.TokenKind.TRC10) {
            if (withdrawSigns[nonce].success) {
                emit MultiSignForWithdrawTRC10(withdrawMsg.user, withdrawMsg.tokenId, withdrawMsg.valueOrUid, nonce);
            } else {
                emit WithdrawTRC10(withdrawMsg.user, withdrawMsg.tokenId, withdrawMsg.valueOrUid, nonce);
            }
        } else if (withdrawMsg._type == DataModel.TokenKind.TRC20) {
            if (withdrawSigns[nonce].success) {
                emit MultiSignForWithdrawTRC20(withdrawMsg.user, withdrawMsg.mainChainAddress, withdrawMsg.valueOrUid, nonce);
            } else {
                emit WithdrawTRC20(withdrawMsg.user, withdrawMsg.mainChainAddress, withdrawMsg.valueOrUid, nonce);
            }
        } else if (withdrawMsg._type == DataModel.TokenKind.TRC721) {
            if (withdrawSigns[nonce].success) {
                emit MultiSignForWithdrawTRC721(withdrawMsg.user, withdrawMsg.mainChainAddress, withdrawMsg.valueOrUid, nonce);
            } else {
                emit WithdrawTRC721(withdrawMsg.user, withdrawMsg.mainChainAddress, withdrawMsg.valueOrUid, nonce);
            }
        } else {
            if (withdrawSigns[nonce].success) {
                emit MultiSignForWithdrawTRX(withdrawMsg.user, withdrawMsg.valueOrUid, nonce);
            } else {
                emit WithdrawTRX(withdrawMsg.user, withdrawMsg.valueOrUid, nonce);

            }
        }
    }

    function setLogicAddress(address _logicAddress) public onlyOracle {
        if (multiSignForDelegate(_logicAddress)) {
            changeLogicAddress(_logicAddress);
        }
    }

    function multiSignForDelegate(address _logicAddress) internal returns (bool) {

        SignMsg storage changeLogicSign = changeLogicSigns[_logicAddress];
        if (changeLogicSign.oracleSigned[msg.sender]) {
            return false;
        }
        changeLogicSign.oracleSigned[msg.sender] = true;
        changeLogicSign.signCnt += 1;

        if (!changeLogicSign.success && changeLogicSign.signCnt > numOracles * 2 / 3) {
            changeLogicSign.success = true;
            return true;
        }
        return false;
    }

    function batchvalidatesign(bytes32 dataHash, bytes[] storage signs, address[] storage oracle) internal returns(bytes32){
        uint256 bitmap = 0;
        for(uint256 i = 0; i < signs.length; i++){
            bytes memory sig = signs[i];
            address signer = oracle[i];
            if (account.ECVerify(signer, dataHash, sig)){
                bitmap |= 1<<i;
            }
        }
        return bytes32(bitmap);
    }

    function countSuccessSignForWithdraw(uint256 nonce, bytes32 dataHash) internal returns (bool) {
        SignMsg storage _signMsg = withdrawSigns[nonce];
        if (_signMsg.success) {
            return false;
        }
        bytes32 ret = batchvalidatesign(dataHash, _signMsg.signs, _signMsg.signOracles);
        uint256 count = countSuccess(ret);
        if (count > numOracles * 2 / 3) {
            _signMsg.success = true;
            return true;
        }
        return false;
    }

    function countSuccess(bytes32 ret) internal pure returns (uint256 count) {
        uint256 _num = uint256(ret);
        for (; _num > 0; ++count) {_num &= (_num - 1);}
        return count;
    }

    function() goDelegateCall onlyNotPause onlyNotStop payable external {
        revert("not allow function fallback");
    }

    function setPause(bool isPause) external goDelegateCall onlyOwner {
        pause = isPause;
    }

    function setStop(bool isStop) external goDelegateCall onlyOwner {
        stop = isStop;
    }

    function setWithdrawMinTrx(uint256 minValue) external goDelegateCall onlyOwner {
        withdrawMinTrx = minValue;
    }

    function setWithdrawMinTrc10(uint256 minValue) external goDelegateCall onlyOwner {
        withdrawMinTrc10 = minValue;
    }

    function setWithdrawMinTrc20(uint256 minValue) external goDelegateCall onlyOwner {
        withdrawMinTrc20 = minValue;
    }

    function setWithdrawFee(uint256 fee) external goDelegateCall onlyOwner {
        require(fee <= 100_000_000, "less than 100 TRX");
        withdrawFee = fee;
    }

    function getWithdrawFee() view public returns (uint256) {
        return withdrawFee;
    }

    function getMainContractList() view public returns (address[] memory) {
        return mainContractList;
    }

    function getWithdrawMsg(uint256 nonce) view public returns (address, address, uint256, uint256, uint256, uint256){
        WithdrawMsg memory _withdrawMsg = userWithdrawList[nonce];
        return (_withdrawMsg.user, _withdrawMsg.mainChainAddress, uint256(_withdrawMsg.tokenId), _withdrawMsg.valueOrUid,
        uint256(_withdrawMsg._type), uint256(_withdrawMsg.status));

    }

    function mappingDone(uint256 nonce) view public returns (bool) {
        return mappingSigns[nonce].success;
    }

    function setRetryFee(uint256 fee) external goDelegateCall onlyOwner {
        require(fee <= 100_000_000, "less than 100 TRX");
        retryFee = fee;
    }

    function setTokenOwner(address tokenAddress, address tokenOwner) external onlyOwner {
        // todo
        //address(0x10002).call(abi.encode(tokenAddress, tokenOwner));
    }

    function mainContractCount() view external returns (uint256) {
        return mainContractList.length;
    }

    function depositDone(uint256 nonce) view external returns (bool r) {
        r = depositSigns[nonce].success;
    }

    function isOracle(address _oracle) view public returns (bool) {
        return oracles[_oracle];
    }

}
