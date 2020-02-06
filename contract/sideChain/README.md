## 准备工作
1. 更新[gaia][gaia]代码
1. 部署侧链合约([BIN][bin],[ABI][abi])，记为`sideTrx`
2. 多次调用`sideTrx.addOracle(address)`增加7个账户，记为`oracle`账户

## 接口测试
### 侧链充值
以下接口需要使用`oracle`账户调用，当超过2/3的`oracle`账户调用成功后，将触发对应的事件，并充值到账.
#### TRX
充值TRX到侧链
- 方法: `sideTrx.multiSignForDepositTRX(string to, uint256 value, uint256 nonce)`
    - `to`: 充值账户
    - `value`: 充值数量
    - `nonce`: 唯一序号,可递增
- 事件: `event DepositTRX(string to, uint64 worldID, uint256 itemID, uint256 value, uint64 sideValue, uint256 nonce);`
    - `worldID`,`itemID`: 增发到账户`to`的资产类型
    - `sideValue`: 增发到账户`to`的数量(侧链)
    - 其余: 同方法描述一致
#### TRC10
充值TRC10
- 方法: `sideTrx.multiSignForDepositTRC10(string to, uint256 tokenId, uint256 value, bytes32 name, bytes32 symbol, uint8 decimals, uint256 nonce)`
    - `to`: 充值账户
    - `tokenId`: 资产id
    - `value`: 充值数量
    - `decimals`: 资产精度
    - `nonce`: 唯一序号,可递增
    - 其余: 资产描述
- 事件: `event DepositTRC10(string to, uint256 tokenID, uint256 value, uint64 worldID, uint64 itemID, uint64 sideValue, uint256 nonce);`
#### TRC20
充值TRC20(ERC20)到侧链，与前两者不同，需要先映射一次，再充值
##### 映射
- 方法: `sideTrx.multiSignForDeployDAppTRC20AndMapping(address mainChainAddress, string name, string symbol, uint8 decimals, string contractOwner, uint256 nonce)`
- 事件: `event DeployDAppTRC20AndMapping(address mainChainAddress, uint64 worldID, uint64 itemID, uint256 nonce);`
##### 充值
- 方法: `sideTrx.multiSignForDepositTRC20(string to, address mainChainAddress, uint256 value, uint256 nonce)`
- 事件: `event DepositTRC20(string to, address mainChainAddress, uint256 value, uint64 worldID, uint64 itemID, uint64 sideValue, uint256 nonce);`
#### TRC721
##### 映射
- 方法: `sideTrx.multiSignForDeployDAppTRC721AndMapping(address mainChainAddress, string name, string symbol, string contractOwner, uint256 nonce)`
    - `mainChainAddress`：主链合约地址
- 事件: `event DepositTRC721(string to, address mainChainAddress, uint256 UID, uint64 worldID, uint64 itemID, uint64 sideUID, uint256 nonce);`
##### 充值
- 方法: `sideTrx.multiSignForDepositTRC721(string to, address mainChainAddress, uint256 uId, uint256 nonce)`
    - `mainChainAddress`：使用与映射相同的值
- 事件: `event DeployDAppTRC721AndMapping(address mainChainAddress, uint64 worldID, uint64 itemID, uint256 nonce);`

### 侧链提现
提现分两步，由资产持有者调用: 
1. `itemAPI.ItemApprove(sideTrx, worldID, itemTypeID, UID, amount);`
2. `sideTrx.ItemsWithdraw(address to, uint64 itemID, uint64 valueOrID);`
- `sideTrx`: 跨链合约账户
- `to:`: 提现到主链的地址
- `worldID`,`itemTypeID`: 充值步骤中获得。
- `valueOrID`: 同质资产表示数量，非同质资产表示id.

[gaia]: https://github.com/fractalplatform/fractal/tree/gaia
[bin]: SideChain/SideChainGateway.bin
[abi]: SideChain/SideChainGateway.abi