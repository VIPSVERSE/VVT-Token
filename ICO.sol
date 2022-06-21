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


interface IPriceFeed {
    function getPrice(address token) external view returns(uint256);
}


contract VVTICO is Ownable {

    address public baseToken;//VVT token
    uint256 private basePrice;//in USD
    
    struct ReserveInfo{
        address user;
        uint256 amount;
        uint256 buyTime;
    }
    ReserveInfo[] public reservedFund;
    uint256 numberOfUsers;
    uint256 totalReserved;

    address public bank;
    uint256 public unlockPeriod;
    uint256 public priceIncrease;//price updated every X days. PriceIcrease in %
    uint256 public roundDuration;
    uint256 public startTime;
    uint256 public icoDuration;
    bool active;
    address private priceFeed; 
    mapping(address => bool) public allowedToken; 

    constructor (address _token,uint256 _basePrice) {
        baseToken = _token;
        basePrice = _basePrice;
        //default values:
        priceFeed = address(0x9bFc3046ea26f8B09D3E85bd22AEc96C80D957e3); 
        setAllowedToken(0x9FaE2529863bD691B4A7171bDfCf33C7ebB10a65,true);//SOY
        setAllowedToken(0x1eAa43544dAa399b87EEcFcC6Fa579D5ea4A6187,true);//CLOE
        setAllowedToken(0xCCc766f97629a4E14b3af8C91EC54f0b5664A69F,true);//ETC
        setAllowedToken(0xcC208c32Cc6919af5d8026dAB7A3eC7A57CD1796,true);//ETH
        setAllowedToken(0xcCDe29903E621Ca12DF33BB0aD9D1ADD7261Ace9,true);//BNB
        setAllowedToken(0xbf6c50889d3a620eb42C0F188b65aDe90De958c4,true);//BUSDT   
        priceIncrease = 1;//1%
        roundDuration  = 7 days;//1 week
        icoDuration = 180 days;//6 months
        unlockPeriod = 90 days;//3 months
        bank = owner();
    }
    /*
    Enable sales, save ICO start time.
    */
    function start() external onlyOwner{
        active = true;
        startTime = block.timestamp;
    }
    /*
    stop ICO
    */
    function stop() external onlyOwner{
        active = false;
    }
    /*
    
    */
    function setBank(address _bank) external onlyOwner{
        bank = _bank; 
    }
    /*
    We will use SOY IDO price feed by default
    */
    function setPriceFeed(address _feed) external onlyOwner{
        priceFeed = _feed; 
    }
    function setAllowedToken(address _token, bool state) public onlyOwner{
        require(_token != address(0));
        allowedToken[_token] = state;
    }
    function setUnlockPeriod(uint256 _time) external onlyOwner{
        require(_time != 0);
        unlockPeriod = _time;
    }
    function setRoundTime(uint256 _time) external onlyOwner{
        require(_time != 0);
        roundDuration = _time;
    }
    function setICODurationTime(uint256 _time) external onlyOwner{
        require(_time != 0);
        icoDuration = _time;
    }
    /*
    How much price increasing every "roundDuration" time. 
    in PERCENTS! 
    */
    function setPriceIncrease(uint256 _coefficient) external onlyOwner{
        require(_coefficient != 0);
        priceIncrease = _coefficient;
    }
    /*
    Calculates current VVT token price in USD(BUSDT).
    price updated "priceIncrease" percents every "roundDuration" time.
    */
    function getCurrentPrice() view internal returns(uint256){
        return basePrice + basePrice  *  ( (block.timestamp - startTime) / roundDuration) * priceIncrease / 100;//
    }
    /*
    Returns current price in selected token or CLO
    */
    function getPriceInToken(address _token) view public returns(uint256){
        if(_token != address(0xbf6c50889d3a620eb42C0F188b65aDe90De958c4)){//BUSDT
            uint256 priceToken = IPriceFeed(priceFeed).getPrice(_token);
            return getCurrentPrice() * 10**18 / priceToken ;
        }
        else{
            return getCurrentPrice();
        }   
    }
    /*
    Amount of tokens still available for sale on ICO
    */
    function availableForSale() public view returns(uint256){
        uint256 balance = IERC223(baseToken).balanceOf(address(this));
        if(balance <= totalReserved || balance == 0){
            return 0;
        }
        return balance - totalReserved;
    }
    /*
    Reserves VVT tokens by some user. User can claim tokens after "unlockPeriod" time. 
    And we will also have a bot that will auto claim tokens for lazy users.
    */
    function _reserve(address user, uint256 amount) internal{
        require(amount > 0 && amount <= availableForSale(),"Not enought tokens in ICO fund");
        reservedFund[numberOfUsers++] = ReserveInfo(user,amount,block.timestamp);
        totalReserved  += amount;
    }
    /* 
    Buy(reserve) tokens with base chain coin(CLO)
    CLO will be in IDO smart contract, 
    need to claim it with claimBank - wallets/explorer does not update balance when CLO moved as internal transaction
    */
    function buyWithClo(uint256 amount) payable external{
        require(active,"IDO inactive");
        require(block.timestamp < (startTime + icoDuration),"ICO finished");
        uint256 cost = getPriceInToken(address(1)) * amount / 10**18;//address(1)=CLO in price feed
        require(cost > 0, "Something wrong with price feed!");
        require(msg.value == cost,"Not enought funds");
        _reserve(_msgSender(), amount);
    }
    /* 
    Buy(reserve) VVT with some of allowed tokens
    tokens will be transfered directly to bank
    */
    function buyWithToken(address _token,uint256 amount) external{
        require(active,"IDO inactive");
        require(block.timestamp < (startTime + icoDuration),"ICO finished");
        require(allowedToken[_token],"Not allowed token");
        uint256 cost = getPriceInToken(_token) * amount / 10**18;
        require(cost > 0, "Something wrong with price feed!");
        IERC223(_token).transferFrom(msg.sender, address(bank),cost);
        _reserve(_msgSender(), amount);
    }
    /*
    Will be called from ICO page UI, checks all user reserves, releases all that unlocked.
    */
    function claimForAddress(address _user) external{
        for(uint i = 0; i < numberOfUsers; i++){
            if(reservedFund[i].user != _user){
                continue;
            }
            if(reservedFund[i].amount > 0 && (reservedFund[i].buyTime+unlockPeriod) >= block.timestamp){
                uint256 amount = reservedFund[i].amount;//re-entrancy protection
                reservedFund[i].amount = 0;  
                IERC223(baseToken).transfer(reservedFund[i].user,amount);
            }
        }     
    }
    /*
    Auto claim for users, will be called daily by bot.
    Scan all reserve entries and release all unlocked.
    */
    function claimAllAvailable() external{ 
        for(uint i = 0; i< numberOfUsers;i++){
            if(gasleft() < 200000){// try to auto claim until gas not ended
                break;
            }
            if(reservedFund[i].amount > 0 && (reservedFund[i].buyTime+unlockPeriod) >= block.timestamp){
                uint256 amount = reservedFund[i].amount;//re-entrancy protection
                reservedFund[i].amount = 0;  
                IERC223(baseToken).transfer(reservedFund[i].user,amount);  
            }
        }
    }
    function claimBank() external onlyOwner{
        uint256 balance = address(this).balance;
        payable(bank).transfer(balance); 
    }

    function rescueERC223(address _token, address to) external onlyOwner {
        require(_token != baseToken,"VVT token can't be rescued using this method");
        uint256 value = IERC223(_token).balanceOf(address(this));
        IERC223(_token).transfer(to, value);
    }
    function claimUnusedTokens() external onlyOwner {
        require(!active,"ICO in progress");
        uint256 value = IERC223(baseToken).balanceOf(address(this));
        IERC223(baseToken).transfer(owner(), value);
    }
}