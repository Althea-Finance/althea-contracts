// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {AltheaOwnable} from "src/dependencies/AltheaOwnable.sol";
import {RewardsFramework} from "src/dependencies/RewardsFramework.sol";

// Information of a single lock (an account can have multiple locks)
struct Lock {
    uint256 balance;
    uint64 lockPeriodStartTime;
    uint32 nWeeks;
}

library LockOperations {
    function power(Lock storage self) internal view returns (uint256) {
        return power(self.balance, self.nWeeks);
    }

    // pure function to avoid storage reads when possible
    function power(uint256 amount, uint32 nWeeks) internal pure returns (uint256) {
        return amount * nWeeks;
    }

    function deadline(Lock storage self) internal view returns (uint256) {
        return self.lockPeriodStartTime + (self.nWeeks * 1 weeks);
    }
}

// CONTRACT INVARIANTS:
//  the balance of a single lock has to be higher than MINIMUM_LOCK_BALANCE at any time
//  the deadline of a lock can never be decreased (pushed backwards)
//  the sum of all powers must be equal to the state variable totalPower
//  the weight of an account can never exceed 100% (PRECISSION)
//  the contract's balance of lockTokens must be >= the sum of all lock.balance.

/// @title Althea Token Locker contract
/// @notice Users can lock their tokens commiting for a number of weeks, and receive a "power" in the locker.
///         The weight of the account is their power divided by the total power (sum of all other users).
///         The lock power of a given user is calculated as (lockedBalance * commitedWeeks)
///         This locker contract therefore incentivices COMMITMENT, in terms of both TIME and TOKENS.
///         The longer the commitment and the higher the balance, the higher the power
///         A user's power will not decay over time, and will stay the same until the user unlocks the tokens
///         A user's power does not decay when the commitment period is over. The lock needs to be terminated / withdrawn
///         These powers will be used for THEA emissions distribution as well as for the voting system
/// @dev    An address can have multiple locks
///         Once created, a lock can be extended in time (postpone the deadline), but not in balance.
///         Any address can terminate a lock which deadline has passed, removing his power from totalPower, giving more weight to the remaining.

///         This contract implements the RewardsFramework. The "assets" here is the power, and the rewards are the THEA distributed on distributeEmissions()
contract Locker is AltheaOwnable, RewardsFramework {
    using SafeERC20 for IERC20;
    using LockOperations for Lock;

    // minimum 1 THEA needs to be locked. Must also hold when withdrawing tokens
    uint256 public constant MINIMUM_LOCK_BALANCE = 0.1e18;

    // @audit should we leave these configurable?
    uint8 public constant MINIMUM_WEEKS_TO_LOCK = 2;
    uint8 public constant MAXIMUM_WEEKS_TO_LOCK = 52;

    /// There is no iterations in state changing functions. Only in view functions that are meant for frontend purposes
    uint8 public constant MAX_LOCKS_PER_ADDRESS = 25;

    /// precission factor to minimize decimal loss
    uint256 public constant PRECISSION = 1e18;

    /// address of the token to lock. THEA token in this case
    IERC20 public lockToken;
    /// address of the token in wihch emissions (rewards) are gonna be deposited (oTHEA)
    IERC20 public emissionsToken;

    struct UserLockData {
        Lock[] locks;
        uint256 totalPower; // total power from all locks. UNITS: (balance * nWeeks)
    }

    // Lock information of each user
    mapping(address => UserLockData) public userLocks;

    /// Power is defined as (lockedBalance * nWeeks), the total Power it is the sum of all locks in the system
    uint256 public totalPower;

    ////////////// ERRORS & EVENTS ////////////////
    error NotEnoughAmount();
    error NotEnoughBalance();
    error LockPeriodTooShort();
    error LockPeriodToolLong();
    error ExceededLocksPerAddressLimit();
    error CommitmentPeriodNotFinished();
    error CommitmentPeriodAlreadyFinished();
    error CannotBringDeadlineForward();
    error InvalidBalanceAfterWithdraw();
    error InvalidLockParameters(address account, uint256 index);
    error NothingToClaim();

    event LockCreated(address indexed account, uint256 indexed index, uint256 amount, uint8 nWeeks);
    event CommitmentExtended(address indexed account, uint256 indexed index, uint8 nWeeks);
    event WithdrawBeforeDeadline(address indexed account, uint256 indexed index, uint256 received, uint256 fee);
    event LockTerminated(address indexed account, uint256 indexed index);

    ////////////////////////////////////////////////

    constructor(address _lockTokenAddress, address _emissionsTokenAddress, address _altheaCore)
        AltheaOwnable(_altheaCore)
    {
        lockToken = IERC20(_lockTokenAddress);
        emissionsToken = IERC20(_emissionsTokenAddress);
    }

    /// @dev Reverts if `index` is too large for `account`
    modifier validLock(address account, uint256 index) {
        if (index < userLocks[account].locks.length) revert InvalidLockParameters(account, index);
        _;
    }

    /// @dev all functions that trigger a change in `power` need to be preceeded by an update in the rewards buffer
    ///     This is because the rewards system uses `power` as the asset that determines the shares of rewards for each accoun    modifier bufferRewards(address account) {
        _bufferRewards(account, userLocks[account].totalPower);
        _;
    }

    ////////////// EXTERNAL FUNCTIONS ////////////////

    /// @dev nWeeks commited has to be within the accepted range
    /// @dev small amounts are not accepted
    function createLock(uint256 amount, uint8 nWeeks) external bufferRewards(msg.sender) {
        if (amount < MINIMUM_LOCK_BALANCE) revert NotEnoughAmount();
        if (nWeeks < MINIMUM_WEEKS_TO_LOCK) revert LockPeriodTooShort();
        if (nWeeks > MAXIMUM_WEEKS_TO_LOCK) revert LockPeriodToolLong();
        uint256 index = userLocks[msg.sender].locks.length;
        if (index >= MAX_LOCKS_PER_ADDRESS) revert ExceededLocksPerAddressLimit();

        // create new lock and push it to the list
        userLocks[msg.sender].locks.push(
            Lock({balance: amount, lockPeriodStartTime: uint64(block.timestamp), nWeeks: uint32(nWeeks)})
        );

        // this function is the same as lock.power(), but allows us to save some gas as it works in memory
        uint256 newLockPower = LockOperations.power(amount, nWeeks);

        // update state
        userLocks[msg.sender].totalPower += newLockPower;
        totalPower += newLockPower;

        lockToken.safeTransferFrom(msg.sender, address(this), amount);
        emit LockCreated(msg.sender, index, amount, nWeeks);
    }

    /// @notice resets the startTime of the lock and adds the new commitedWeeks
    /// @dev if the new deadline is lower than the old one it reverts
    /// @param index The index in the user's array of locks to modify
    function extendLock(uint256 index, uint8 nWeeks) external validLock(msg.sender, index) bufferRewards(msg.sender) {
        if (nWeeks < MINIMUM_WEEKS_TO_LOCK) revert LockPeriodTooShort();
        if (nWeeks > MAXIMUM_WEEKS_TO_LOCK) revert LockPeriodToolLong();

        Lock storage lock = userLocks[msg.sender].locks[index];

        uint256 newDeadline = block.timestamp + (nWeeks * 1 weeks);
        if (newDeadline < lock.deadline()) revert CannotBringDeadlineForward();

        uint256 lockBalance = lock.balance;
        uint32 lockWeeksBefore = lock.nWeeks;
        uint256 lockPowerBefore = LockOperations.power(lockBalance, lockWeeksBefore);

        // cache this ones to recalculate powers after lock is updated
        uint256 userPowerBefore = userLocks[msg.sender].totalPower;
        uint256 totalPowerBefore = totalPower;

        // update lock in storage (balance stays constant)
        lock.lockPeriodStartTime = uint64(block.timestamp);
        lock.nWeeks = nWeeks;

        uint256 newLockPower = LockOperations.power(lockBalance, nWeeks);

        // even though the deadline is postponed, nWeeks can be lower than before, so the power can decrease
        // underflows are not possible, as (totalPowerBefore >= lockPowerBefore) for both user and total
        totalPower = totalPowerBefore - lockPowerBefore + newLockPower;
        userLocks[msg.sender].totalPower = userPowerBefore - lockPowerBefore + newLockPower;

        emit CommitmentExtended(msg.sender, index, nWeeks);
    }

    /// @notice allows withdrawing a lock before the lock.deadline.
    ///         However, it incurrs a fee proportional to the time remaining until deadline, counted from start time
    /// @dev    WARNING: if a user calls extendLock, the lockPeriodStartTime is reset, so the percentage fee paid would be almost 100%
    function withdrawFromLockBeforeDeadline(uint256 amount, uint256 index)
        external
        validLock(msg.sender, index)
        bufferRewards(msg.sender)
    {
        Lock storage lock = userLocks[msg.sender].locks[index];
        uint256 deadline = lock.deadline();

        // amount = 0 is all right here.
        if (block.timestamp > deadline) revert CommitmentPeriodAlreadyFinished(); // use terminateLock() instead
        if (lock.balance < MINIMUM_LOCK_BALANCE + amount) revert InvalidBalanceAfterWithdraw(); // the requirement(balance > amount) is implicit here

        uint256 powerBefore = lock.power();
        lock.balance -= amount;
        uint256 powerAfter = lock.power();

        // The power has to decrease necessarily as balance decreases and nWeeks stays constant. No underflows
        uint256 powerDecrease = powerBefore - powerAfter;
        totalPower -= powerDecrease;
        userLocks[msg.sender].totalPower -= powerDecrease;

        // fee proportional to the remaining time from now until deadline, using the total duration of the lock as reference.
        uint256 fee = amount * (deadline - block.timestamp) / (lock.nWeeks * 1 weeks);
        uint256 withdrawable = amount - fee;

        // erc20 transfers
        if (fee > 0) lockToken.safeTransfer(ALTHEA_CORE.feeReceiver(), fee);
        if (withdrawable > 0) lockToken.safeTransfer(msg.sender, withdrawable);

        emit WithdrawBeforeDeadline(msg.sender, index, withdrawable, fee);
    }

    /// @notice terminates a lock, excluding it from future rewards, and sending the locked tokens to the original owner
    /// @dev anyone can terminate the lock of someone else, as long as the commirment date has passed
    function terminateLock(address account, uint256 index) external validLock(account, index) bufferRewards(account) {
        Lock storage lock = userLocks[account].locks[index];
        // msg.sender has no relevance here, anyone can terminate a lock, but assets go to the lock owner
        if (lock.deadline() > block.timestamp) revert CommitmentPeriodNotFinished();

        uint256 lockPower = lock.power();
        uint256 lockBalance = lock.balance;

        // totals have to be necessarily higher than individual lock powers, so this shoudn't underflow
        userLocks[account].totalPower -= lockPower;
        totalPower -= lockPower;

        // pop the last lock of the array.
        // If the index is not the last one, bring copy the last one to index and then pop the last one
        uint256 lastIndex = userLocks[account].locks.length - 1; // cant underflow, as validLock() ensures that at least there is 1 element
        if (index != lastIndex) {
            userLocks[account].locks[index] = userLocks[account].locks[lastIndex];
        }
        userLocks[account].locks.pop();

        emit LockTerminated(account, index);
        lockToken.safeTransfer(account, lockBalance);
    }

    ///////// EMISSIONS (Rewards related) /////////////

    function distributeEmissions(uint256 amountToDistribute) external {
        // no harm in small amountToDistribute (or even 0)
        // this function emits an event already with more info than what we have here
        _registerDepositedRewards(amountToDistribute, totalPower);

        emissionsToken.safeTransferFrom(msg.sender, address(this), amountToDistribute);
    }

    function claimRewardsFromEmissions() external bufferRewards(msg.sender) returns (uint256 claimed) {
        // this function already emits an event, but does NOT handle token transfers
        claimed = _registerClaim(msg.sender, userLocks[msg.sender].totalPower);
        if (claimed == 0) revert NothingToClaim();

        emissionsToken.safeTransfer(msg.sender, claimed);
    }

    //////////// VIEW //////////////

    /// @notice returns the weight of the user in the locker.
    /// @dev Calculated as the userPower / totalPower, scaled up by PRECISSION.
    ///      I.e, if userPower == totalPower, the output is PRECISSION (1e18) which represents 100% of the weight.
    function getAccountWeight(address account) public view returns (uint256 weight) {
        return PRECISSION * userLocks[account].totalPower / totalPower;
    }

    /// @notice Returns the total account power. No other info to minimize storage reads
    function getAccountPower(address account) public view returns (uint256 power) {
        return userLocks[account].totalPower;
    }

    /// @notice returns relevant info from an account
    /// @dev this function may seem redundant. The first one is for integrations (only power is required). This one is for frontend.
    function getAccountInfo(address account)
        public
        view
        returns (uint256 lockedBalance, uint256 unlockedBalance, uint256 power, uint256 weight)
    {
        uint256 nLocks = userLocks[account].locks.length;
        for (uint256 i; i < nLocks; i++) {
            Lock storage lock = userLocks[account].locks[i];
            if (lock.deadline() > block.timestamp) {
                lockedBalance += lock.balance;
            } else {
                unlockedBalance += lock.balance;
            }
        }
        // for power and weight, the fact that the locks are locked or unlocked is irrelevant. Unlocked locks still have same power.
        power = userLocks[account].totalPower;
        weight = getAccountWeight(account);
    }

    /// @notice returns relevant info from a lock. Frontend purposes
    function getLockInfo(address account, uint256 index)
        public
        view
        validLock(account, index)
        returns (uint256 balance, uint256 power, uint256 nWeeks, uint256 deadline)
    {
        return (
            userLocks[account].locks[index].balance,
            userLocks[account].locks[index].power(),
            userLocks[account].locks[index].nWeeks,
            userLocks[account].locks[index].deadline()
        );
    }
}
