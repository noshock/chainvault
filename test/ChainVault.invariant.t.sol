// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {ChainVault} from "../src/ChainVault.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract ChainVaultHandler {
    ChainVault public vault;
    ERC20Mock public token;

    uint256 public totalDeposited;
    uint256 public totalWithdrawn;
    uint256 public totalTokenDeposited;
    uint256 public totalTokenWithdrawn;

    constructor() {
        vault = new ChainVault(address(this));
        token = new ERC20Mock();

        vault.setTokenAllowed(address(token), true);

        token.mint(address(this), 1_000_000 ether);

        token.approve(address(vault), type(uint256).max);
    }

    receive() external payable {}

    function depositETH(uint96 rawAmount) external {
        uint256 amount = uint256(rawAmount) % (address(this).balance + 1);

        if (amount == 0) return;

        vault.depositETH{value: amount}();

        totalDeposited += amount;
    }

    function withdrawETH(uint96 rawAmount) external {
        uint256 balance = address(vault).balance;

        uint256 amount = uint256(rawAmount) % (balance + 1);

        if (amount == 0) return;

        vault.withdrawETH(amount);

        totalWithdrawn += amount;
    }

    function depositToken(uint96 rawAmount) external {
        uint256 balance = token.balanceOf(address(this));
        uint256 amount = uint256(rawAmount) % (balance + 1);

        if (amount == 0) return;

        token.approve(address(vault), amount);
        vault.depositToken(address(token), amount);

        totalTokenDeposited += amount;
    }

    function withdrawToken(uint96 rawAmount) external {
        uint256 balance = token.balanceOf(address(vault));
        uint256 amount = uint256(rawAmount) % (balance + 1);

        if (amount == 0) return;

        vault.withdrawToken(address(token), amount);

        totalTokenWithdrawn += amount;
    }
}

contract ChainVaultInvariantTest is StdInvariant, Test {
    ChainVaultHandler handler;
    ChainVault vault;

    function setUp() public {
        handler = new ChainVaultHandler();
        vault = handler.vault();

        vm.deal(address(handler), 100 ether);

        targetContract(address(handler));
    }

    function invariant_ETHAccountingIsConsistent() public view {
        assertEq(address(vault).balance, handler.totalDeposited() - handler.totalWithdrawn());
    }

    function invariant_TokenAccountingIsConsistent() public view {
        assertEq(
            vault.tokenBalance(address(handler.token())), handler.totalTokenDeposited() - handler.totalTokenWithdrawn()
        );
    }
}
