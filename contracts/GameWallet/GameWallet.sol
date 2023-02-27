//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract GameWallet is OwnableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    // Address of prize token
    IERC20Upgradeable public prizeToken;

    // Mapping for users balance
    mapping(address => uint256) public pBalance;

    // Mapping for withdraw lock
    mapping(address => bool) public locked;

    // treasury address
    address public treasury;

    // prize fee
    uint256 public prizeFee;

    uint256[48] private __gap;

    event Deposited(address indexed account, uint256 amount);
    event Withdrawn(address indexed account, uint256 amount);
    event Deducted(address indexed account, uint256 amount);
    event WonPrize(address indexed account, uint256 amount);
    event PrizeFeeSent(address indexed account, uint256 amount);

    /** Initializes the GameWallet
    @param tokenAddress_ the token address for prize 
     */
    function initialize(address tokenAddress_) external initializer {
        require(tokenAddress_ != address(0), "Invalid token address");
        __Ownable_init();

        prizeToken = IERC20Upgradeable(tokenAddress_);
    }

    function deposit(uint256 _amount) external {
        prizeToken.safeTransferFrom(msg.sender, address(this), _amount);
        pBalance[msg.sender] += _amount;

        emit Deposited(msg.sender, _amount);
    }

    function withdraw(uint256 _amount) external {
        require(pBalance[msg.sender] >= _amount, "Not enough token deposited");
        require(!locked[msg.sender], "Account locked for withdraw");

        pBalance[msg.sender] -= _amount;
        prizeToken.safeTransfer(msg.sender, _amount);

        emit Withdrawn(msg.sender, _amount);
    }

    ///////////////////////
    /// Owner Functions ///
    ///////////////////////

    function winPrize(
        address[] memory _accounts,
        uint256[] memory _entryFees,
        address[] memory _winners
    ) external onlyOwner {
        require(_winners.length != 0, "Invalid winners array");
        require(
            _accounts.length == _entryFees.length && _accounts.length != 0,
            "Invalid array length"
        );

        uint256 sum;
        uint256 i;

        for (i; i < _accounts.length; i++) {
            require(pBalance[_accounts[i]] >= _entryFees[i], "Not enough balance deposited");

            pBalance[_accounts[i]] -= _entryFees[i];
            sum += _entryFees[i];
            emit Deducted(_accounts[i], _entryFees[i]);
        }

        // deduct prize fee
        if ((sum * prizeFee) / 1e4 != 0 && treasury != address(0)) {
            prizeToken.safeTransfer(treasury, (sum * prizeFee) / 1e4);
            emit PrizeFeeSent(treasury, (sum * prizeFee) / 1e4);
            sum -= (sum * prizeFee) / 1e4;
        }

        for (i = 0; i < _winners.length; i++) {
            if (i == _winners.length - 1) {
                prizeToken.safeTransfer(
                    _winners[i],
                    sum - (sum * (_winners.length - 1)) / _winners.length
                );
                emit WonPrize(_winners[i], sum - (sum * (_winners.length - 1)) / _winners.length);
            } else {
                prizeToken.safeTransfer(_winners[i], sum / _winners.length);
                emit WonPrize(_winners[i], sum / _winners.length);
            }
        }
    }

    function lockAccounts(address[] memory _accounts, bool[] memory _locked) external onlyOwner {
        require(
            _accounts.length == _locked.length && _accounts.length != 0,
            "Invalid array length"
        );

        for (uint256 i; i < _locked.length; i++) locked[_accounts[i]] = _locked[i];
    }

    function setTreasury(address _treasury) external onlyOwner {
        require(_treasury != address(0), "Invalid treasury address");
        treasury = _treasury;
    }

    function setPrizeFee(uint256 _prizeFee) external onlyOwner {
        require(prizeFee <= 2e3, "Invalid prize fee value");
        prizeFee = _prizeFee;
    }
}
