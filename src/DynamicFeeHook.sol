// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseHook} from "v4-periphery/BaseHook.sol";

import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";

contract DynamicFeeHook is BaseHook {
    constructor(IPoolManager _poolManager) BaseHook(_poolManager) {}

    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: false, // you can use afterInitialize to set the initial swap fee too
            beforeAddLiquidity: false,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: true,
            afterSwap: false,
            beforeDonate: false,
            afterDonate: false
        });
    }

    /// @notice Sets the swap fee for a pool
    /// @dev Define your own custom logic here!
    function setDynamicFee(PoolKey calldata key) public {
        if (block.number % 2 == 0) {
            poolManager.updateDynamicSwapFee(key, 6900); // 0.69%
        } else {
            poolManager.updateDynamicSwapFee(key, 500); // 0.05%
        }
    }

    function beforeSwap(address, PoolKey calldata key, IPoolManager.SwapParams calldata, bytes calldata)
        external
        override
        returns (bytes4)
    {
        setDynamicFee(key); // set the swap fee on every swap
        // TODO: optimization -- only needs to be set top-of-block
        return BaseHook.beforeSwap.selector;
    }
}
