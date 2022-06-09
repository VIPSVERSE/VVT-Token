//SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.10;

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

abstract contract Ownable is Context {
    address internal _owner;
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    constructor() {
        _transferOwnership(_msgSender());
    }
    function owner() public view virtual returns (address) {
        return _owner;
    }
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC223 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);
    
    
    function transfer(address recipient, uint256 amount, bytes calldata data) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);
    event TransferData(bytes);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
}


contract VVTFund is Ownable {
    address public baseToken;//VVT token
    uint256 public initialLockTime;
    uint256 public initialBalance;
    uint256 public roundDuration;
    uint256 public releasePerRound;// in "1/1000" of initial amount, so we can work with 0.5%, 1.5%, etc.  1% = 10.

    uint256 public startTime;
    uint256 public claimedBalance;

    constructor (address _token,uint256 _initialLockTime, uint256 _roundDuration, uint256 _releasePerRound) {
        baseToken = _token;
        initialLockTime = _initialLockTime;
        roundDuration = _roundDuration;
        releasePerRound = _releasePerRound;
    }

    function init() external onlyOwner{
        startTime = block.timestamp;
        initialBalance = IERC223(baseToken).balanceOf(address(this));
    }
    /*
    Claim all currently unlocked and unclaimed funds.
    Calculate current round(starts after end of initial lock period)
    Calculate all unlocked now funds(wantToClaim)
    Check difference between initial balance and current contract balance and calculate unclaimed amount(final amount = wantToClaim - "claimed")
    */
    function claimToken() external onlyOwner {
        require(startTime>0,"not yet initialized");
        require(block.timestamp >= (startTime+initialLockTime),"Initial lock period not finished");
        require(claimedBalance < initialBalance ,"locked funds ended");
        uint256 activeTime = block.timestamp - (startTime+initialLockTime);
        uint256 currentRound = activeTime/ roundDuration;
        uint256 wantToClaim = initialBalance * (currentRound * releasePerRound ) / 1000; 
        uint256 finalAmount = wantToClaim - (initialBalance  - claimedBalance);
        claimedBalance += finalAmount;
        if( (claimedBalance + finalAmount) > initialBalance){//just to be sure there is no any cummulative calculation error and we can't claim last round
            finalAmount = initialBalance - claimedBalance;
        }
        IERC223(baseToken).transfer(owner(), finalAmount);
    }
    function rescueERC223(address _token, address to) external onlyOwner {
        require(_token != baseToken,"VVT token can't be rescued using this method");
        uint256 value = IERC223(_token).balanceOf(address(this));
        IERC223(_token).transfer(to, value);
    }
    //We can take all balance after end of lock period in case of any mistake or somebody filled more VVT tokens.
    function claimUnusedTokens() external onlyOwner {
        require(startTime > 0,"Not yet initialized");
        require(block.timestamp >= (startTime+initialLockTime),"Initial lock period not finished yet");
        require(claimedBalance >= initialBalance ,"Not all locked funds claimed");
        uint256 value = IERC223(baseToken).balanceOf(address(this));
        IERC223(baseToken).transfer(owner(), value);
    }
    

}