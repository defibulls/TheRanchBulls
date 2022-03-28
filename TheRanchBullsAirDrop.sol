// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

/*    
🅣🅗🅔🅡🅐🅝🅒🅗_🅑🅤🅛🅛🅢_➋⓿➋➋
*/

import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./TheRanchBullsMint.sol";

contract TheRanchBullsAirDrop is VRFConsumerBase, Ownable {

    using SafeERC20 for IERC20;
    
    address public TheRanchBullsMintAddress;
    address public dev1;
    address public dev2;
    uint256 public dev1_percent = 14;
    uint256 public dev2_percent = 6;
    address public rewardTokenContract;
    uint public rewardDecimals = 6;
    uint256 public eligibleRewardAmount = 0;
    uint public giveawayId = 1;

    mapping (address => uint256) internal ownerOfNFTRewardBalance;

    event centennial_Air_Drop(
        address[] nftOwnerAddresses,
        uint[] indexOfNfts,
        uint256 winning_amount   
    );

    event withdrawRewardsEvent(
        address indexed nftOwner,
        uint256 indexed amount
    );

    uint256 public fee = 10 ** 14;   // 0.0001 LINK
    bytes32 public keyhash;
    uint256 public randomResult;

    enum AWARD_STATE {
        OPEN,
        CLOSED,
        PAY_AUTHORIZED
    }
    AWARD_STATE public award_state;

    constructor(
        address _vrfCoordinator,
        address _link,
        bytes32 _keyhash
    ) public
        VRFConsumerBase(_vrfCoordinator, _link) {
        award_state = AWARD_STATE.CLOSED;
        keyhash = _keyhash;    
    }

    /** 
     * Requests randomness from Chainlink
     */
    function getRandomNumber() private returns (bytes32 requestId) {
        require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK - fill contract with more");
        bytes32 requestId = requestRandomness(keyhash, fee);
        return requestId;
    }

    /**
     * Callback function used by VRF Coordinator
     */
    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        randomResult = randomness;
    }

    /**
     * Expand the single random number from the VRF into more (n) 
    */
    function expand(uint256 randomValue, uint256 n, uint256 _tokenSupply) private returns (uint256[] memory expandedValues) {
        require(n <= _tokenSupply, "Looking for too many results, this will infinitely loop");
        expandedValues = new uint256[](n);
        uint found_num;
        uint i = 0;
        while (found_num < n) {
            uint256 num = (uint256(keccak256(abi.encode(randomValue, i))) % _tokenSupply);
            if (num != 0 && num <= _tokenSupply && exists(expandedValues,num) == false) {
                expandedValues[found_num] = num;
                found_num++;
            }
            i++;
        }
        require(expandedValues.length == 100, "We didn't find 100 winners during the expansion");
        award_state = AWARD_STATE.PAY_AUTHORIZED;
        return expandedValues;
    }

    /**
     * Assist the expand function to limit the same number twice 
    */
    function exists (uint256[] memory arrayToCheck, uint numberToCheck) private returns (bool) {
        for (uint i = 0; i < arrayToCheck.length; i++) {
            if (arrayToCheck[i] == numberToCheck) {
                return true;
            }
        }
        return false;
    }


    function centennialAirDrop() public onlyOwner {
        require(award_state == AWARD_STATE.OPEN, "The award state is currently closed");
        require(address(rewardTokenContract) != address(0), "ERROR: Must set the Reward Token Contract address before rewarding");
        require(eligibleRewardAmount > 0, "Not Enough Funds to Warrant calling the function to award the Bulls");

        IERC20 tokenContract = IERC20(rewardTokenContract);

        uint256 _balance = eligibleRewardAmount;
        tokenContract.safeTransfer(dev1, _balance * dev1_percent / 100);
        tokenContract.safeTransfer(dev2, _balance * dev2_percent / 100);

        _balance = _balance - ((_balance * dev1_percent / 100) + (_balance * dev2_percent / 100));
        uint256 centennial_cut = _balance / 100;

        getRandomNumber();
        uint256 _tokenSupply = getMintTotalSupply();
        uint256[] memory weeklyWinners = expand(randomResult,100, _tokenSupply);

        address[] memory winningNftOwners = new address[](100);
        uint256[] memory winningIndexes = new uint[](100);
        
        require(award_state == AWARD_STATE.PAY_AUTHORIZED);
        
        for (uint256 i = 0; i < weeklyWinners.length; i++) {
            uint winning_index = weeklyWinners[i];
            address luckyBullOwner = getNFTOwnerOf(winning_index);
            winningNftOwners[i] = luckyBullOwner;
            winningIndexes[i] = winning_index;
            updateNftOwnerRewardBalance(luckyBullOwner, centennial_cut);
        }
        
        emit centennial_Air_Drop(winningNftOwners, winningIndexes, centennial_cut);

        giveawayId++;
        award_state = AWARD_STATE.CLOSED;
        eligibleRewardAmount = 0;
    }

    // Minting contract info
    function setTheRanchBullsMintAddress(address _mintAddress) external {
        TheRanchBullsMintAddress = _mintAddress;
    }

    function getMintTotalSupply() private view returns (uint256) {
        TheRanchBullsMint TRBM = TheRanchBullsMint(TheRanchBullsMintAddress);
        return TRBM.totalSupply();
    }

    function getNFTOwnerOf(uint _index) public view returns (address) {
        TheRanchBullsMint TRBM = TheRanchBullsMint(TheRanchBullsMintAddress);
        return TRBM.ownerOf(_index);
    }

    function getLinkBalance() public view returns (uint256){
        uint256 _balance = LINK.balanceOf(address(this));
        return _balance;
    }

    function getBalance() public view returns (uint256){
        uint256 _balance = address(this).balance;
        return _balance;
    }

    function getRandomResult() public view returns (uint256){
        return randomResult;
    }

    function checkTokenBalance(address token) public view returns(uint) {
        IERC20 token = IERC20(token);
        return token.balanceOf(address(this));
    }


    // Contract Funding / Withdrawing / Transferring
    function updateNftOwnerRewardBalance(address _ownerOfNFT, uint256 _amount) internal {
       ownerOfNFTRewardBalance[_ownerOfNFT] = ownerOfNFTRewardBalance[_ownerOfNFT] + _amount;
    }

    function getUserRewardBalance(address _ownerOfNFT) public view returns (uint256) {
        if (ownerOfNFTRewardBalance[_ownerOfNFT] <= 0){
            return 0;
        }
        return ownerOfNFTRewardBalance[_ownerOfNFT];
    }

    function withdrawRewards(address _ownerOfNFT) public {
        uint256 balance = ownerOfNFTRewardBalance[_ownerOfNFT];
        require(balance > 0, "You must have a balance more than 0");

        IERC20(rewardTokenContract).safeTransfer(_ownerOfNFT, balance);
        ownerOfNFTRewardBalance[_ownerOfNFT] = 0;
        withdrawRewardsEvent(_ownerOfNFT, balance);
    }

    function fund(uint256 _amount) public payable {}
  
    function withdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    function withdrawToken(address _tokenContract, uint256 _amount) external onlyOwner {
        IERC20 tokenContract = IERC20(_tokenContract);
        tokenContract.safeTransfer(msg.sender, _amount);
    }

    // Contract Control _ OnlyOwner
    function openAwardState() external onlyOwner {
        require(award_state == AWARD_STATE.CLOSED);
        award_state = AWARD_STATE.OPEN;
    }

    function closeAwardState() external onlyOwner {
        require(award_state == AWARD_STATE.OPEN);
        award_state = AWARD_STATE.CLOSED;
    }

    function updateEligibleRewardAmount(uint256 _amount) external  onlyOwner {
        uint256 amount = _amount * 10 ** rewardDecimals;
        eligibleRewardAmount = amount;
    }

    function setdev1(address payable _address) external  onlyOwner {
        dev1 = _address;
    }

    function setdev2(address payable _address) external onlyOwner {
        dev2 = _address;
    }

    function set_Dev1_percent(uint256 _percent) external onlyOwner {
        require(_percent + dev2_percent <= 20, "dev1_% + dev2_% must be <=20");
        dev1_percent  = _percent;
    }

    function set_Dev2_percent(uint256 _percent) external onlyOwner {
        require(_percent + dev1_percent <= 20, "dev1_% + dev2_% must be <=20");
        dev2_percent  = _percent;
    }

    function setRewardTokenAddress(address _address) public onlyOwner {
        rewardTokenContract = _address;
    }

    function setRewardTokenDecimals(uint _decimals) public onlyOwner {
        rewardDecimals = _decimals;
    }
}



