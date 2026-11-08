// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract ChainVault is Ownable2Step, ReentrancyGuard {
    using SafeERC20 for IERC20;

    mapping(address => bool) public allowedTokens;

    error ZeroDeposit();
    error ZeroWithdrawal();
    error InsufficientBalance();
    error ETHTransferFailed();
    error InvalidTokenAddress();
    error TokenNotAllowed();
    error ZeroTokenDeposit();
    error TokenAmountMismatch();
    error TokenTransferMismatch();
    error OwnershipRenunciationDisabled();

    event ETHDeposited(address indexed depositor, uint256 amount);

    event ETHWithdrawn(address indexed owner, uint256 amount);

    event TokenAllowlistUpdated(address indexed token, bool allowed);

    event TokenDeposited(address indexed token, address indexed depositor, uint256 amount);

    event TokenWithdrawn(address indexed token, address indexed owner, uint256 amount);

    constructor(address initialOwner) Ownable(initialOwner) {}

    function depositETH() external payable {
        if (msg.value == 0) {
            revert ZeroDeposit();
        }

        emit ETHDeposited(msg.sender, msg.value);
    }

    receive() external payable {
        if (msg.value == 0) {
            revert ZeroDeposit();
        }

        emit ETHDeposited(msg.sender, msg.value);
    }

    function ethBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function withdrawETH(uint256 amount) external nonReentrant onlyOwner {
        if (amount == 0) {
            revert ZeroWithdrawal();
        }

        if (amount > address(this).balance) {
            revert InsufficientBalance();
        }

        address payable recipient = payable(owner());

        emit ETHWithdrawn(recipient, amount);

        (bool success,) = recipient.call{value: amount}("");

        if (!success) {
            revert ETHTransferFailed();
        }
    }

    function setTokenAllowed(address token, bool allowed) external onlyOwner {
        if (token == address(0) || token.code.length == 0) {
            revert InvalidTokenAddress();
        }

        allowedTokens[token] = allowed;

        emit TokenAllowlistUpdated(token, allowed);
    }

    function depositToken(address token, uint256 amount) external nonReentrant {
        if (token == address(0) || token.code.length == 0) {
            revert InvalidTokenAddress();
        }

        if (!allowedTokens[token]) {
            revert TokenNotAllowed();
        }

        if (amount == 0) {
            revert ZeroTokenDeposit();
        }

        IERC20 tokenContract = IERC20(token);

        uint256 balanceBefore = tokenContract.balanceOf(address(this));

        tokenContract.safeTransferFrom(msg.sender, address(this), amount);

        uint256 balanceAfter = tokenContract.balanceOf(address(this));

        if (balanceAfter < balanceBefore || balanceAfter - balanceBefore != amount) {
            revert TokenAmountMismatch();
        }

        emit TokenDeposited(token, msg.sender, amount);
    }

    function tokenBalance(address token) external view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }

    function withdrawToken(address token, uint256 amount) external nonReentrant onlyOwner {
        if (token == address(0) || token.code.length == 0) {
            revert InvalidTokenAddress();
        }

        if (amount == 0) revert ZeroWithdrawal();

        IERC20 tokenContract = IERC20(token);

        uint256 vaultBalanceBefore = tokenContract.balanceOf(address(this));

        if (amount > vaultBalanceBefore) revert InsufficientBalance();

        address recipient = owner();
        uint256 ownerBalanceBefore = tokenContract.balanceOf(recipient);

        tokenContract.safeTransfer(recipient, amount);

        uint256 vaultBalanceAfter = tokenContract.balanceOf(address(this));
        uint256 ownerBalanceAfter = tokenContract.balanceOf(recipient);

        if (
            vaultBalanceAfter > vaultBalanceBefore || vaultBalanceBefore - vaultBalanceAfter != amount
                || ownerBalanceAfter < ownerBalanceBefore || ownerBalanceAfter - ownerBalanceBefore != amount
        ) {
            revert TokenTransferMismatch();
        }

        emit TokenWithdrawn(token, recipient, amount);
    }

    function renounceOwnership() public view override onlyOwner {
        revert OwnershipRenunciationDisabled();
    }
}
