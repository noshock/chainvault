// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {ChainVault} from "../src/ChainVault.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ChainVaultTest is Test {
    ChainVault vault;

    address owner = makeAddr("owner");
    address attacker = makeAddr("attacker");
    address depositor = makeAddr("depositor");

    function setUp() public {
        vault = new ChainVault(owner);
    }

    function test_InitialOwnerIsCorrect() public view {
        assertEq(vault.owner(), owner);
    }

    function test_NonOwnerCannotTransferOwnership() public {
        vm.prank(attacker);

        vm.expectRevert();
        vault.transferOwnership(attacker);
    }

    function test_AnyoneCanDepositETH() public {
        vm.deal(depositor, 5 ether);

        vm.prank(depositor);
        vault.depositETH{value: 2 ether}();

        assertEq(vault.ethBalance(), 2 ether);
    }

    function test_ZeroETHDepositReverts() public {
        vm.prank(depositor);

        vm.expectRevert(ChainVault.ZeroDeposit.selector);
        vault.depositETH{value: 0}();
    }

    function test_DirectETHTransfer() public {
        vm.deal(depositor, 3 ether);

        vm.prank(depositor);
        (bool success,) = address(vault).call{value: 1 ether}("");

        assertTrue(success);
        assertEq(vault.ethBalance(), 1 ether);
    }

    function test_OwnerCanWithdrawETH() public {
        vm.deal(address(vault), 5 ether);

        uint256 ownerBalanceBefore = owner.balance;

        vm.prank(owner);
        vault.withdrawETH(2 ether);

        assertEq(address(vault).balance, 3 ether);
        assertEq(owner.balance, ownerBalanceBefore + 2 ether);
    }

    function test_NonOwnerCannotWithdrawETH() public {
        vm.deal(address(vault), 5 ether);

        vm.prank(attacker);
        vm.expectRevert();

        vault.withdrawETH(1 ether);
    }

    function test_WithdrawMoreThanBalanceReverts() public {
        vm.deal(address(vault), 1 ether);

        vm.prank(owner);
        vm.expectRevert(ChainVault.InsufficientBalance.selector);

        vault.withdrawETH(2 ether);
    }

    function test_ZeroWithdrawalReverts() public {
        vm.prank(owner);
        vm.expectRevert(ChainVault.ZeroWithdrawal.selector);

        vault.withdrawETH(0);
    }

    function test_ReentrancyAttackIsBlocked() public {
        ReentrantOwner maliciousOwner = new ReentrantOwner();

        ChainVault targetVault = new ChainVault(address(maliciousOwner));

        maliciousOwner.setVault(targetVault);

        vm.deal(address(targetVault), 2 ether);

        maliciousOwner.attack();

        assertEq(address(targetVault).balance, 1 ether);
        assertEq(address(maliciousOwner).balance, 1 ether);
        assertEq(maliciousOwner.attempts(), 1);
        assertTrue(maliciousOwner.reentryBlocked());
    }

    function test_OwnerCanAllowToken() public {
        ERC20Mock token = new ERC20Mock();

        vm.prank(owner);
        vault.setTokenAllowed(address(token), true);

        assertTrue(vault.allowedTokens(address(token)));
    }

    function test_OwnerCanRevokeToken() public {
        ERC20Mock token = new ERC20Mock();

        vm.startPrank(owner);
        vault.setTokenAllowed(address(token), true);
        vault.setTokenAllowed(address(token), false);
        vm.stopPrank();

        assertFalse(vault.allowedTokens(address(token)));
    }

    function test_NonOwnerCannotAllowToken() public {
        ERC20Mock token = new ERC20Mock();

        vm.prank(attacker);
        vm.expectRevert();

        vault.setTokenAllowed(address(token), true);
    }

    function test_ZeroAddressCannotBeAllowed() public {
        vm.prank(owner);
        vm.expectRevert(ChainVault.InvalidTokenAddress.selector);

        vault.setTokenAllowed(address(0), true);
    }

    function test_NonContractAddressCannotBeAllowed() public {
        vm.prank(owner);
        vm.expectRevert(ChainVault.InvalidTokenAddress.selector);

        vault.setTokenAllowed(makeAddr("fakeToken"), true);
    }

    function test_AnyoneCanDepositApprovedToken() public {
        ERC20Mock token = new ERC20Mock();

        vm.prank(owner);
        vault.setTokenAllowed(address(token), true);

        token.mint(depositor, 100 ether);

        vm.startPrank(depositor);
        token.approve(address(vault), 50 ether);
        vault.depositToken(address(token), 50 ether);
        vm.stopPrank();

        assertEq(token.balanceOf(address(vault)), 50 ether);
        assertEq(token.balanceOf(depositor), 50 ether);
    }

    function test_UnapprovedTokenDepositReverts() public {
        ERC20Mock token = new ERC20Mock();

        token.mint(depositor, 100 ether);

        vm.startPrank(depositor);
        token.approve(address(vault), 50 ether);

        vm.expectRevert(ChainVault.TokenNotAllowed.selector);
        vault.depositToken(address(token), 50 ether);

        vm.stopPrank();
    }

    function test_ZeroTokenDepositReverts() public {
        ERC20Mock token = new ERC20Mock();

        vm.prank(owner);
        vault.setTokenAllowed(address(token), true);

        vm.prank(depositor);
        vm.expectRevert(ChainVault.ZeroTokenDeposit.selector);

        vault.depositToken(address(token), 0);
    }

    function test_InsufficientTokenAllowanceReverts() public {
        ERC20Mock token = new ERC20Mock();

        vm.prank(owner);
        vault.setTokenAllowed(address(token), true);

        token.mint(depositor, 100 ether);

        vm.startPrank(depositor);
        token.approve(address(vault), 10 ether);

        vm.expectRevert();
        vault.depositToken(address(token), 50 ether);

        vm.stopPrank();
    }

    function test_FeeOnTransferTokenDepositReverts() public {
        FeeOnTransferToken token = new FeeOnTransferToken();

        vm.prank(owner);
        vault.setTokenAllowed(address(token), true);

        token.mint(depositor, 100 ether);

        vm.startPrank(depositor);
        token.approve(address(vault), 50 ether);

        vm.expectRevert(ChainVault.TokenAmountMismatch.selector);
        vault.depositToken(address(token), 50 ether);

        vm.stopPrank();

        assertEq(token.balanceOf(address(vault)), 0);
        assertEq(token.balanceOf(depositor), 100 ether);
    }

    function test_OwnerCanWithdrawToken() public {
        ERC20Mock token = new ERC20Mock();

        vm.prank(owner);
        vault.setTokenAllowed(address(token), true);

        token.mint(depositor, 100 ether);

        vm.startPrank(depositor);
        token.approve(address(vault), 100 ether);
        vault.depositToken(address(token), 100 ether);
        vm.stopPrank();

        vm.prank(owner);
        vault.withdrawToken(address(token), 40 ether);

        assertEq(token.balanceOf(owner), 40 ether);
        assertEq(token.balanceOf(address(vault)), 60 ether);
    }

    function test_NonOwnerCannotWithdrawToken() public {
        ERC20Mock token = new ERC20Mock();

        vm.prank(owner);
        vault.setTokenAllowed(address(token), true);

        token.mint(depositor, 100 ether);

        vm.startPrank(depositor);
        token.approve(address(vault), 100 ether);
        vault.depositToken(address(token), 100 ether);
        vm.stopPrank();

        vm.prank(attacker);
        vm.expectRevert();
        vault.withdrawToken(address(token), 50 ether);
    }

    function test_WithdrawMoreTokensThanBalanceReverts() public {
        ERC20Mock token = new ERC20Mock();

        vm.prank(owner);
        vault.setTokenAllowed(address(token), true);

        vm.prank(owner);
        vm.expectRevert(ChainVault.InsufficientBalance.selector);

        vault.withdrawToken(address(token), 100 ether);
    }

    function test_ZeroTokenWithdrawalReverts() public {
        ERC20Mock token = new ERC20Mock();

        vm.prank(owner);
        vm.expectRevert(ChainVault.ZeroWithdrawal.selector);

        vault.withdrawToken(address(token), 0);
    }

    function test_OwnerCanWithdrawAfterTokenRevocation() public {
        ERC20Mock token = new ERC20Mock();

        vm.prank(owner);
        vault.setTokenAllowed(address(token), true);

        token.mint(depositor, 100 ether);

        vm.startPrank(depositor);
        token.approve(address(vault), 100 ether);
        vault.depositToken(address(token), 100 ether);
        vm.stopPrank();

        vm.prank(owner);
        vault.setTokenAllowed(address(token), false);

        vm.prank(owner);
        vault.withdrawToken(address(token), 100 ether);

        assertEq(token.balanceOf(owner), 100 ether);
        assertEq(token.balanceOf(address(vault)), 0);
    }

    function test_OwnershipTransferRequiresAcceptance() public {
        address newOwner = makeAddr("newOwner");

        vm.prank(owner);
        vault.transferOwnership(newOwner);

        assertEq(vault.owner(), owner);

        vm.prank(newOwner);
        vault.acceptOwnership();

        assertEq(vault.owner(), newOwner);
    }

    function test_OwnershipRenunciationIsDisabled() public {
        vm.prank(owner);
        vm.expectRevert(ChainVault.OwnershipRenunciationDisabled.selector);

        vault.renounceOwnership();

        assertEq(vault.owner(), owner);
    }

    function test_NonPendingOwnerCannotAcceptOwnership() public {
        address newOwner = makeAddr("newOwner");

        vm.prank(owner);
        vault.transferOwnership(newOwner);

        vm.prank(attacker);
        vm.expectRevert();
        vault.acceptOwnership();

        assertEq(vault.owner(), owner);
    }

    function test_OwnerCanCancelPendingOwnershipTransfer() public {
        address newOwner = makeAddr("newOwner");

        vm.prank(owner);
        vault.transferOwnership(newOwner);

        vm.prank(owner);
        vault.transferOwnership(address(0));

        assertEq(vault.owner(), owner);
        assertEq(vault.pendingOwner(), address(0));
    }

    function test_ZeroAddressInitialOwnerReverts() public {
        vm.expectRevert();
        new ChainVault(address(0));
    }

    function test_NewOwnerReceivesTokenWithdrawals() public {
        ERC20Mock token = new ERC20Mock();
        address newOwner = makeAddr("newOwner");

        vm.prank(owner);
        vault.setTokenAllowed(address(token), true);

        token.mint(depositor, 100 ether);

        vm.startPrank(depositor);
        token.approve(address(vault), 100 ether);
        vault.depositToken(address(token), 100 ether);
        vm.stopPrank();

        vm.prank(owner);
        vault.transferOwnership(newOwner);

        vm.prank(newOwner);
        vault.acceptOwnership();

        vm.prank(newOwner);
        vault.withdrawToken(address(token), 100 ether);

        assertEq(token.balanceOf(newOwner), 100 ether);
        assertEq(token.balanceOf(owner), 0);
        assertEq(token.balanceOf(address(vault)), 0);
    }

    function test_NonContractAddressDepositReverts() public {
        address fakeToken = makeAddr("fakeToken");

        vm.prank(depositor);
        vm.expectRevert(ChainVault.InvalidTokenAddress.selector);

        vault.depositToken(fakeToken, 1 ether);
    }

    function test_ZeroAddressTokenDepositReverts() public {
        vm.prank(depositor);
        vm.expectRevert(ChainVault.InvalidTokenAddress.selector);

        vault.depositToken(address(0), 1 ether);
    }

    function test_ReentrantTokenDepositIsBlocked() public {
        ReentrantToken token = new ReentrantToken();

        token.setVault(vault);

        vm.prank(owner);
        vault.setTokenAllowed(address(token), true);

        token.mint(depositor, 100 ether);

        vm.startPrank(depositor);
        token.approve(address(vault), 100 ether);
        vault.depositToken(address(token), 10 ether);
        vm.stopPrank();

        assertTrue(token.reentryBlocked());
        assertEq(token.balanceOf(address(vault)), 10 ether);
    }

    function test_ReentrantTokenWithdrawalIsBlocked() public {
        ReentrantToken token = new ReentrantToken();

        token.setVault(vault);

        vm.prank(owner);
        vault.setTokenAllowed(address(token), true);

        token.mint(depositor, 100 ether);

        vm.startPrank(depositor);
        token.approve(address(vault), 100 ether);
        vault.depositToken(address(token), 10 ether);
        vm.stopPrank();

        vm.prank(owner);
        vault.withdrawToken(address(token), 5 ether);

        assertTrue(token.withdrawReentryBlocked());
        assertEq(token.balanceOf(owner), 5 ether);
        assertEq(token.balanceOf(address(vault)), 5 ether);
    }

    function testFuzz_AnyoneCanDepositETH(uint96 amount) public {
        vm.assume(amount > 0);

        vm.deal(depositor, amount);

        vm.prank(depositor);
        vault.depositETH{value: amount}();

        assertEq(address(vault).balance, amount);
    }

    function testFuzz_AnyoneCanDepositToken(uint96 amount) public {
        vm.assume(amount > 0);

        ERC20Mock token = new ERC20Mock();

        vm.prank(owner);
        vault.setTokenAllowed(address(token), true);

        token.mint(depositor, amount);

        vm.startPrank(depositor);
        token.approve(address(vault), amount);
        vault.depositToken(address(token), amount);
        vm.stopPrank();

        assertEq(token.balanceOf(address(vault)), amount);
        assertEq(token.balanceOf(depositor), 0);
    }

    function testFuzz_OwnerCanWithdrawToken(uint96 amount) public {
        vm.assume(amount > 0);

        ERC20Mock token = new ERC20Mock();

        vm.prank(owner);
        vault.setTokenAllowed(address(token), true);

        token.mint(depositor, amount);

        vm.startPrank(depositor);
        token.approve(address(vault), amount);
        vault.depositToken(address(token), amount);
        vm.stopPrank();

        vm.prank(owner);
        vault.withdrawToken(address(token), amount);

        assertEq(token.balanceOf(owner), amount);
        assertEq(token.balanceOf(address(vault)), 0);
    }

    function testFuzz_OwnerCanWithdrawETH(uint96 amount) public {
        vm.assume(amount > 0);

        vm.deal(depositor, amount);

        vm.prank(depositor);
        vault.depositETH{value: amount}();

        vm.prank(owner);
        vault.withdrawETH(amount);

        assertEq(address(vault).balance, 0);
        assertEq(owner.balance, amount);
    }
}

contract ReentrantToken is ERC20 {
    ChainVault public vault;
    bool public reentryBlocked;
    bool public withdrawReentryBlocked;

    constructor() ERC20("Reentrant Token", "RTK") {}

    function setVault(ChainVault _vault) external {
        vault = _vault;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function _update(address from, address to, uint256 value) internal override {
        super._update(from, to, value);

        if (to == address(vault) && address(vault) != address(0)) {
            (bool success,) = address(vault).call(abi.encodeCall(ChainVault.depositToken, (address(this), 1)));

            reentryBlocked = !success;
        }

        if (from == address(vault) && address(vault) != address(0)) {
            (bool success,) = address(vault).call(abi.encodeCall(ChainVault.withdrawToken, (address(this), 1)));

            withdrawReentryBlocked = !success;
        }
    }
}

contract FeeOnTransferToken is ERC20 {
    constructor() ERC20("Fee Token", "FEE") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function _update(address from, address to, uint256 value) internal override {
        if (from != address(0) && to != address(0)) {
            uint256 fee = value / 100;

            super._update(from, to, value - fee);
            super._update(from, address(0), fee);
        } else {
            super._update(from, to, value);
        }
    }
}

contract ReentrantOwner {
    ChainVault public vault;
    bool public reentryBlocked;
    uint256 public attempts;

    function setVault(ChainVault _vault) external {
        vault = _vault;
    }

    function attack() external {
        vault.withdrawETH(1 ether);
    }

    receive() external payable {
        attempts++;

        (bool success,) = address(vault).call(abi.encodeCall(ChainVault.withdrawETH, (1 ether)));

        reentryBlocked = !success;
    }
}
