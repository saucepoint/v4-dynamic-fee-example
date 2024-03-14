// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {CurrencyLibrary, Currency} from "v4-core/src/types/Currency.sol";
import {Deployers} from "v4-core/test/utils/Deployers.sol";
import {DynamicFeeHook} from "../src/DynamicFeeHook.sol";
import {HookMiner} from "./utils/HookMiner.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {SwapFeeLibrary} from "v4-core/src/libraries/SwapFeeLibrary.sol";

contract DynamicFeeHookTest is Test, Deployers {
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;
    using FixedPointMathLib for uint256;

    DynamicFeeHook hook;

    function setUp() public {
        // creates the pool manager, utility routers, and test tokens
        Deployers.deployFreshManagerAndRouters();
        Deployers.deployMintAndApprove2Currencies();

        // Deploy the hook to an address with the correct flags
        uint160 flags = uint160(Hooks.BEFORE_SWAP_FLAG);
        (address hookAddress, bytes32 salt) =
            HookMiner.find(address(this), flags, type(DynamicFeeHook).creationCode, abi.encode(address(manager)));
        hook = new DynamicFeeHook{salt: salt}(IPoolManager(address(manager)));
        require(address(hook) == hookAddress, "DynamicFeeHookTest: hook address mismatch");

        // Create the pool with dynamic fees enabled
        key = PoolKey(currency0, currency1, SwapFeeLibrary.DYNAMIC_FEE_FLAG, 60, IHooks(address(hook)));
        manager.initialize(key, SQRT_RATIO_1_1, ZERO_BYTES);

        // Provide liquidity to the pool
        modifyLiquidityRouter.modifyLiquidity(key, IPoolManager.ModifyLiquidityParams(-60, 60, 10000 ether), ZERO_BYTES);
        modifyLiquidityRouter.modifyLiquidity(
            key, IPoolManager.ModifyLiquidityParams(-120, 120, 1000 ether), ZERO_BYTES
        );
        modifyLiquidityRouter.modifyLiquidity(
            key,
            IPoolManager.ModifyLiquidityParams(TickMath.minUsableTick(60), TickMath.maxUsableTick(60), 10000 ether),
            ZERO_BYTES
        );
    }

    function test_dynamic_fee_even_block_number() public {
        // set block number to 10 (even), making the dynamic fee 0.69%
        vm.roll(10);
        assertEq(block.number, 10);

        uint256 balance1Before = currency1.balanceOfSelf();

        // Perform a test swap //
        bool zeroForOne = true;
        int256 amountSpecified = 1e18;
        BalanceDelta swapDelta = Deployers.swap(key, zeroForOne, amountSpecified, ZERO_BYTES);
        // ------------------- //

        uint256 token1Output = currency1.balanceOfSelf() - balance1Before;

        assertEq(int256(swapDelta.amount0()), amountSpecified);
        assertEq(int256(swapDelta.amount1()), -int256(token1Output));

        // tokens are trading 1:1, so 1e18 input should produce roughly 0.9931e18 output (0.69% fee)
        // (fee is taken from the input, which leads to a smaller output)
        // need to use approx-assertion because tokens are not trading exactly 1:1
        assertApproxEqAbs(token1Output, uint256(amountSpecified).mulWadDown(0.9931e18), 0.00005e18);
    }

    function test_dynamic_fee_odd_block_number() public {
        // set block number to 11 (odd), making the dynamic fee 0.05%
        vm.roll(11);
        assertEq(block.number, 11);

        uint256 balance1Before = currency1.balanceOfSelf();

        // Perform a test swap //
        bool zeroForOne = true;
        int256 amountSpecified = 1e18;
        BalanceDelta swapDelta = Deployers.swap(key, zeroForOne, amountSpecified, ZERO_BYTES);
        // ------------------- //

        uint256 token1Output = currency1.balanceOfSelf() - balance1Before;

        assertEq(int256(swapDelta.amount0()), amountSpecified);
        assertEq(int256(swapDelta.amount1()), -int256(token1Output));

        // tokens are trading 1:1, so 1e18 input should produce roughly 0.9995e18 output (0.05% fee)
        // (fee is taken from the input, which leads to a smaller output)
        // need to use approx-assertion because tokens are not trading exactly 1:1
        assertApproxEqAbs(token1Output, uint256(amountSpecified).mulWadDown(0.9995e18), 0.00005e18);
    }
}
