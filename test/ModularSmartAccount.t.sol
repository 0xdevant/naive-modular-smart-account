// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {WebAuthn} from "@webauthn-sol/WebAuthn.sol";
import {Utils, WebAuthnInfo} from "@webauthn-sol-test/Utils.sol";

import {AASetup} from "./setups/AASetup.t.sol";
import {IModularSmartAccount} from "src/interfaces/IModularSmartAccount.sol";
import {IExtensionRegistry} from "src/interfaces/IExtensionRegistry.sol";
import {IExtensionManager} from "src/interfaces/IExtensionManager.sol";
import {IExtension} from "src/interfaces/extensions/IExtension.sol";
import {IExecuteHookExtension} from "src/interfaces/extensions/hooks/IExecuteHookExtension.sol";
import {IDCAExtension} from "src/interfaces/extensions/IDCAExtension.sol";
import {IOwnershipManagementHookExtension} from "src/interfaces/extensions/IOwnershipManagementHookExtension.sol";

import "test/helpers/Constants.sol";
import {IERC20Mock} from "test/interfaces/IERC20Mock.sol";
import {IWETH9} from "test/interfaces/IWETH9.sol";

contract ModularSmartAccountTest is AASetup {
    modifier registered_OMExtension() {
        bytes4[] memory omInterfaceIds = new bytes4[](2);
        omInterfaceIds[0] = type(IExtension).interfaceId;
        omInterfaceIds[1] = type(IExecuteHookExtension).interfaceId;
        IExtensionRegistry.HookExtensionConfig memory omHookExtensionConfig = IExtensionRegistry.HookExtensionConfig({
            extension: address(omExtension),
            isValidateHook: false,
            isExecuteHook: true,
            interfaceIds: omInterfaceIds
        });
        extensionRegistry.registerHookExtension(omExtension.extensionId(), omHookExtensionConfig);
        _;
    }

    // to have ownership checkings enabled
    modifier registeredAndInstalled_OMExtension_AliceAsOwner() {
        bytes4[] memory omInterfaceIds = new bytes4[](2);
        omInterfaceIds[0] = type(IExtension).interfaceId;
        omInterfaceIds[1] = type(IExecuteHookExtension).interfaceId;
        IExtensionRegistry.HookExtensionConfig memory omHookExtensionConfig = IExtensionRegistry.HookExtensionConfig({
            extension: address(omExtension),
            isValidateHook: false,
            isExecuteHook: true,
            interfaceIds: omInterfaceIds
        });
        extensionRegistry.registerHookExtension(omExtension.extensionId(), omHookExtensionConfig);
        bytes memory installData = abi.encode(address(msa), address(users[0]));
        msa.installHookExtension(omExtension.extensionId(), installData);
        _;
    }

    modifier registeredAndInstalled_DCAExtension() {
        bytes4[] memory dcaFuncSelectors = new bytes4[](3);
        dcaFuncSelectors[0] = IDCAExtension.subscribeDCA.selector;
        dcaFuncSelectors[1] = IDCAExtension.unsubscribeDCA.selector;
        dcaFuncSelectors[2] = IDCAExtension.executeDCA.selector;
        bytes4[] memory dcaInterfaceIds = new bytes4[](1);
        dcaInterfaceIds[0] = type(IExtension).interfaceId;
        IExtensionRegistry.ExtensionConfig memory dcaExtensionConfig = IExtensionRegistry.ExtensionConfig({
            extension: address(dcaExtension),
            funcSelectors: dcaFuncSelectors,
            interfaceIds: dcaInterfaceIds
        });
        extensionRegistry.registerExtension(dcaExtension.extensionId(), dcaExtensionConfig);
        bytes memory installData = abi.encode(DEFAULT_FEE_BP, MAINNET_SWAP_ROUTER_02);
        msa.installExtension(dcaExtension.extensionId(), installData);
        _;
    }

    function setUp() public override {
        AASetup.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                                PASSKEY
    //////////////////////////////////////////////////////////////*/
    function test_validateSignature_withPasskeySigner() public view {
        bytes32 hash = 0x15fa6f8c855db1dccbb8a42eef3a7b83f11d29758e84aed37312527165d5eec5;
        WebAuthnInfo memory webAuthn = Utils.getWebAuthnStruct(hash);

        (bytes32 r, bytes32 s) = vm.signP256(PASSKEY_PRIVATE_KEY, webAuthn.messageHash);
        s = bytes32(Utils.normalizeS(uint256(s)));
        (uint256 x, uint256 y) = abi.decode(PASSKEY_OWNER, (uint256, uint256));
        bytes memory sig = abi.encode(
            IModularSmartAccount.PasskeySignatureWrapper({
                x: x,
                y: y,
                signatureData: abi.encode(
                    WebAuthn.WebAuthnAuth({
                        authenticatorData: webAuthn.authenticatorData,
                        clientDataJSON: webAuthn.clientDataJSON,
                        typeIndex: 1,
                        challengeIndex: 23,
                        r: uint256(r),
                        s: uint256(s)
                    })
                )
            })
        );

        // check for a valid passkey signature
        bytes4 ret = msa.isValidSignature(hash, sig);
        assertEq(ret, EIP1271_MAGIC_VALUE);
    }

    /*//////////////////////////////////////////////////////////////
                               EXTENSION
    //////////////////////////////////////////////////////////////*/
    function test_RegisterExtension_RevertIfExtensionHasInvalidInterface() public {
        IExtensionRegistry.ExtensionConfig memory config = IExtensionRegistry.ExtensionConfig({
            extension: address(1),
            funcSelectors: new bytes4[](1),
            interfaceIds: new bytes4[](1)
        });
        vm.expectRevert(
            abi.encodeWithSelector(IExtensionRegistry.ExtensionRegistry__ExtensionNotSupported.selector, address(1))
        );
        extensionRegistry.registerExtension(bytes32(0), config);
    }

    function test_InstallExtension_RevertIfExtensionIsNotRegisteredOnRegistry() public {
        bytes memory installData = new bytes(0);
        bytes32 dcaExtensionId = dcaExtension.extensionId();
        vm.expectRevert(IExtensionManager.ExtensionManager__ExtensionNotRegistered.selector);
        msa.installExtension(dcaExtensionId, installData);
    }

    function test_InstallHookExtension_OwnershipManagementHookExtension() public registered_OMExtension {
        bytes memory installData = abi.encode(address(msa), address(this));
        msa.installHookExtension(omExtension.extensionId(), installData);
    }

    function test_UninstallExtension_msaOwnersStorageReset() public registeredAndInstalled_OMExtension_AliceAsOwner {
        bytes32 omExtensionId = omExtension.extensionId();
        msa.uninstallHookExtension(omExtensionId, abi.encode(address(msa)));

        assertEq(omExtension.owner(address(msa)), address(0));
    }

    function test_UninstallExtension_RevertIfExtensionNotInstalled() public registered_OMExtension {
        bytes32 omExtensionId = omExtension.extensionId();
        vm.expectRevert(
            abi.encodeWithSelector(
                IExtensionManager.ExtensionManager__ExtensionNotInstalled.selector, address(omExtension)
            )
        );
        msa.uninstallHookExtension(omExtensionId, new bytes(0));
    }

    /*//////////////////////////////////////////////////////////////
                                  MSA
    //////////////////////////////////////////////////////////////*/
    function test_execute_FromOwner() public registeredAndInstalled_OMExtension_AliceAsOwner {
        uint256 mintAmount = 1e18;
        assertEq(erc20Mock.balanceOf(address(msa)), 0);
        // execute as alice
        vm.prank(users[0]);
        msa.execute(address(erc20Mock), 0, abi.encodeCall(IERC20Mock.mint, (address(msa), mintAmount)));
        assertEq(erc20Mock.balanceOf(address(msa)), mintAmount);
    }

    function test_execute_RevertIfFromNonPermissionedCaller() public registeredAndInstalled_OMExtension_AliceAsOwner {
        uint256 mintAmount = 1e18;
        assertEq(erc20Mock.balanceOf(address(msa)), 0);
        vm.expectRevert(IModularSmartAccount.ModularSmartAccount__OnlyFromEntryPointOrPermissionedCaller.selector);
        msa.execute(address(erc20Mock), 0, abi.encodeCall(IERC20Mock.mint, (address(msa), mintAmount)));
        assertEq(erc20Mock.balanceOf(address(msa)), 0);
    }

    function test_fallback_owner_RevertIfCallingHookExtension()
        public
        registeredAndInstalled_OMExtension_AliceAsOwner
    {
        IOwnershipManagementHookExtension msaWithOMFuncs = IOwnershipManagementHookExtension(address(msa));
        vm.prank(users[0]);
        vm.expectRevert(
            abi.encodeWithSelector(
                IModularSmartAccount.ModularSmartAccount__NoExtensionFound.selector,
                IOwnershipManagementHookExtension.owner.selector
            )
        );
        msaWithOMFuncs.owner(address(msa));
    }

    /*//////////////////////////////////////////////////////////////
                          OWNERSHIP_MANAGEMENT
    //////////////////////////////////////////////////////////////*/
    function test_transferOwnership_FromOwner() public registeredAndInstalled_OMExtension_AliceAsOwner {
        address alice = users[0];
        address newOwner = users[1];

        vm.startPrank(alice);
        (bytes memory result) = msa.execute(
            address(omExtension), 0, abi.encodeCall(IOwnershipManagementHookExtension.owner, (address(msa)))
        );
        address currentOwner = abi.decode(result, (address));
        assertEq(currentOwner, alice);
        msa.execute(
            address(omExtension), 0, abi.encodeCall(IOwnershipManagementHookExtension.transferOwnership, (newOwner))
        );
        vm.stopPrank();

        vm.startPrank(users[1]);
        (bytes memory result2) = msa.execute(
            address(omExtension), 0, abi.encodeCall(IOwnershipManagementHookExtension.owner, (address(msa)))
        );
        address newCurrentOwner = abi.decode(result2, (address));
        vm.stopPrank();
        assertEq(newCurrentOwner, newOwner);
    }

    function testFuzz_transferOwnership_RevertIfFromNonOwner(address randomUser)
        public
        registeredAndInstalled_OMExtension_AliceAsOwner
    {
        vm.expectRevert(IModularSmartAccount.ModularSmartAccount__OnlyFromEntryPointOrPermissionedCaller.selector);
        msa.execute(
            address(omExtension), 0, abi.encodeCall(IOwnershipManagementHookExtension.transferOwnership, (randomUser))
        );
    }

    /*//////////////////////////////////////////////////////////////
                                  DCA
    //////////////////////////////////////////////////////////////*/
    function test_mainnetFork_subscribeAndExecuteDCA_ownerSubscribe_bundlerExecute()
        public
        registeredAndInstalled_OMExtension_AliceAsOwner
        registeredAndInstalled_DCAExtension
    {
        uint128 payAmount = 1 ether;
        uint128 totalPayAmount = 10 ether;
        uint64 slippageBP = 100;
        uint64 weekly = 1 weeks;
        uint256 totalFeeNeeded = totalPayAmount * DEFAULT_FEE_BP / BASIS_POINTS;
        uint256 totalTransferAmount = totalPayAmount + totalFeeNeeded;

        vm.createSelectFork(vm.rpcUrl("mainnet"));

        deal(address(msa), DEFAULT_AMOUNT);
        IERC20Mock mainnetUSDC = IERC20Mock(MAINNET_USDC);
        IWETH9 mainnetWETH = IWETH9(MAINNET_WETH);

        assertEq(mainnetUSDC.balanceOf(address(msa)), 0);
        assertEq(mainnetWETH.balanceOf(BUNDLER), 0);

        vm.prank(users[0]);
        msa.execute(MAINNET_WETH, totalTransferAmount, abi.encodeCall(IWETH9.deposit, ()));
        assertEq(mainnetWETH.balanceOf(address(msa)), totalTransferAmount);

        IDCAExtension msaWithDCAFuncs = IDCAExtension(address(msa));
        vm.startPrank(users[0]);
        // approve and transfer WETH to DCAExtension to subscribe for DCA
        msa.execute(MAINNET_WETH, 0, abi.encodeCall(IERC20Mock.approve, (address(dcaExtension), totalTransferAmount)));
        msaWithDCAFuncs.subscribeDCA(MAINNET_USDC, MAINNET_WETH, payAmount, totalPayAmount, slippageBP, weekly);
        vm.stopPrank();
        assertEq(mainnetWETH.balanceOf(address(dcaExtension)), totalTransferAmount);

        // simuluate the bundler executing the DCA task for the user
        vm.prank(MAINNET_ENTRY_POINT);
        IDCAExtension.SwapParams memory swapParams =
            IDCAExtension.SwapParams({feeReceiver: BUNDLER, amountOutMin: 0, sqrtPriceLimitX96: 0, fee: 0});
        msaWithDCAFuncs.executeDCA(0, swapParams);

        assertEq(mainnetWETH.balanceOf(BUNDLER), payAmount * DEFAULT_FEE_BP / BASIS_POINTS);
        assertEq(address(msa).balance, DEFAULT_AMOUNT - totalTransferAmount);
        assertGt(mainnetUSDC.balanceOf(address(msa)), 0);
    }

    function test_unsubscribeDCA_ownerUnsubscribe_getRefundedFullAmount()
        public
        registeredAndInstalled_OMExtension_AliceAsOwner
        registeredAndInstalled_DCAExtension
    {
        uint128 payAmount = 1 ether;
        uint128 totalPayAmount = 10 ether;
        uint64 slippageBP = 100;
        uint64 weekly = 1 weeks;
        uint256 totalFeeNeeded = totalPayAmount * DEFAULT_FEE_BP / BASIS_POINTS;
        uint256 totalTransferAmount = totalPayAmount + totalFeeNeeded;

        vm.createSelectFork(vm.rpcUrl("mainnet"));

        deal(address(msa), DEFAULT_AMOUNT);
        IWETH9 mainnetWETH = IWETH9(MAINNET_WETH);

        vm.prank(users[0]);
        msa.execute(MAINNET_WETH, totalTransferAmount, abi.encodeCall(IWETH9.deposit, ()));

        IDCAExtension msaWithDCAFuncs = IDCAExtension(address(msa));
        vm.startPrank(users[0]);
        msa.execute(MAINNET_WETH, 0, abi.encodeCall(IERC20Mock.approve, (address(dcaExtension), totalTransferAmount)));
        msaWithDCAFuncs.subscribeDCA(MAINNET_USDC, MAINNET_WETH, payAmount, totalPayAmount, slippageBP, weekly);
        msaWithDCAFuncs.unsubscribeDCA(0);
        // get refunded with totalPayAmount and fee
        assertEq(mainnetWETH.balanceOf(address(msa)), totalTransferAmount);
        vm.stopPrank();
    }
}
