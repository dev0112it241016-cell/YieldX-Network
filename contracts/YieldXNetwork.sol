// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title YieldX Network
 * @dev A decentralized yield aggregation and optimization platform
 * @notice This contract allows users to deposit assets, earn yields, and participate in governance
 */
contract YieldXNetwork {
    
    // State variables
    address public owner;
    uint256 public totalDeposits;
    uint256 public totalYieldDistributed;
    uint256 public platformFeePercent = 5; // 5% platform fee
    
    struct UserDeposit {
        uint256 amount;
        uint256 depositTime;
        uint256 lastClaimTime;
        bool isActive;
    }
    
    struct YieldPool {
        string name;
        uint256 totalLiquidity;
        uint256 apy; // Annual Percentage Yield in basis points (e.g., 1000 = 10%)
        bool isActive;
    }
    
    mapping(address => UserDeposit) public userDeposits;
    mapping(uint256 => YieldPool) public yieldPools;
    mapping(address => uint256) public userRewards;
    
    uint256 public poolCount;
    address[] public depositors;
    
    // Events
    event Deposited(address indexed user, uint256 amount, uint256 timestamp);
    event Withdrawn(address indexed user, uint256 amount, uint256 timestamp);
    event YieldClaimed(address indexed user, uint256 amount, uint256 timestamp);
    event PoolCreated(uint256 indexed poolId, string name, uint256 apy);
    event FeeUpdated(uint256 newFeePercent);
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    modifier hasDeposit() {
        require(userDeposits[msg.sender].isActive, "No active deposit found");
        _;
    }
    
    constructor() {
        owner = msg.sender;
        
        // Initialize default yield pool
        yieldPools[0] = YieldPool({
            name: "Stable Yield Pool",
            totalLiquidity: 0,
            apy: 800, // 8% APY
            isActive: true
        });
        poolCount = 1;
    }
    
    /**
     * @dev Function 1: Deposit funds into the yield network
     * @notice Users can deposit ETH to start earning yields
     */
    function deposit() external payable {
        require(msg.value > 0, "Deposit amount must be greater than 0");
        
        if (!userDeposits[msg.sender].isActive) {
            depositors.push(msg.sender);
        }
        
        UserDeposit storage userDep = userDeposits[msg.sender];
        
        if (userDep.isActive) {
            // Claim pending rewards before adding new deposit
            _claimYield(msg.sender);
        }
        
        userDep.amount += msg.value;
        userDep.depositTime = block.timestamp;
        userDep.lastClaimTime = block.timestamp;
        userDep.isActive = true;
        
        totalDeposits += msg.value;
        yieldPools[0].totalLiquidity += msg.value;
        
        emit Deposited(msg.sender, msg.value, block.timestamp);
    }
    
    /**
     * @dev Function 2: Withdraw deposited funds
     * @param amount The amount to withdraw
     * @notice Users can withdraw their deposited funds along with earned yields
     */
    function withdraw(uint256 amount) external hasDeposit {
        UserDeposit storage userDep = userDeposits[msg.sender];
        require(amount > 0 && amount <= userDep.amount, "Invalid withdrawal amount");
        
        // Claim any pending yield before withdrawal
        _claimYield(msg.sender);
        
        userDep.amount -= amount;
        
        if (userDep.amount == 0) {
            userDep.isActive = false;
        }
        
        totalDeposits -= amount;
        yieldPools[0].totalLiquidity -= amount;
        
        payable(msg.sender).transfer(amount);
        
        emit Withdrawn(msg.sender, amount, block.timestamp);
    }
    
    /**
     * @dev Function 3: Claim accumulated yield rewards
     * @notice Users can claim their earned yield without withdrawing principal
     */
    function claimYield() external hasDeposit {
        uint256 reward = _claimYield(msg.sender);
        require(reward > 0, "No yield available to claim");
    }
    
    /**
     * @dev Internal function to calculate and transfer yield
     */
    function _claimYield(address user) internal returns (uint256) {
        UserDeposit storage userDep = userDeposits[user];
        
        uint256 yieldAmount = calculateYield(user);
        
        if (yieldAmount > 0) {
            uint256 platformFee = (yieldAmount * platformFeePercent) / 100;
            uint256 userReward = yieldAmount - platformFee;
            
            userRewards[user] += userReward;
            userDep.lastClaimTime = block.timestamp;
            totalYieldDistributed += yieldAmount;
            
            payable(user).transfer(userReward);
            payable(owner).transfer(platformFee);
            
            emit YieldClaimed(user, userReward, block.timestamp);
            
            return userReward;
        }
        
        return 0;
    }
    
    /**
     * @dev Function 4: Calculate pending yield for a user
     * @param user The address of the user
     * @return The calculated yield amount
     */
    function calculateYield(address user) public view returns (uint256) {
        UserDeposit memory userDep = userDeposits[user];
        
        if (!userDep.isActive) {
            return 0;
        }
        
        uint256 timeElapsed = block.timestamp - userDep.lastClaimTime;
        uint256 apy = yieldPools[0].apy;
        
        // Calculate yield: (amount * apy * timeElapsed) / (10000 * 365 days)
        uint256 yieldAmount = (userDep.amount * apy * timeElapsed) / (10000 * 365 days);
        
        return yieldAmount;
    }
    
    /**
     * @dev Function 5: Create a new yield pool
     * @param name The name of the pool
     * @param apy The annual percentage yield in basis points
     * @notice Only owner can create new yield pools
     */
    function createYieldPool(string memory name, uint256 apy) external onlyOwner {
        require(apy > 0 && apy <= 10000, "APY must be between 0 and 100%");
        
        yieldPools[poolCount] = YieldPool({
            name: name,
            totalLiquidity: 0,
            apy: apy,
            isActive: true
        });
        
        emit PoolCreated(poolCount, name, apy);
        poolCount++;
    }
    
    // Additional utility functions
    
    /**
     * @dev Get user deposit information
     * @param user The address of the user
     */
    function getUserInfo(address user) external view returns (
        uint256 depositAmount,
        uint256 depositTime,
        uint256 pendingYield,
        uint256 totalRewardsClaimed
    ) {
        UserDeposit memory userDep = userDeposits[user];
        return (
            userDep.amount,
            userDep.depositTime,
            calculateYield(user),
            userRewards[user]
        );
    }
    
    /**
     * @dev Update platform fee percentage
     * @param newFeePercent The new fee percentage
     */
    function updatePlatformFee(uint256 newFeePercent) external onlyOwner {
        require(newFeePercent <= 20, "Fee cannot exceed 20%");
        platformFeePercent = newFeePercent;
        emit FeeUpdated(newFeePercent);
    }
    
    /**
     * @dev Get total number of depositors
     */
    function getTotalDepositors() external view returns (uint256) {
        return depositors.length;
    }
    
    /**
     * @dev Get contract balance
     */
    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }
    
    // Fallback function to accept ETH
    receive() external payable {
        // Accept ETH for yield distribution
    }
}