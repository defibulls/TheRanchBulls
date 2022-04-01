// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

/*    
🅣🅗🅔🅡🅐🅝🅒🅗_🅑🅤🅛🅛🅢_➋⓿➋➋
*/

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./TheRanchBullsMint.sol";

contract TheRanchBullsAirDrop is Ownable {
    using SafeERC20 for IERC20;
    address public TheRanchBullsMintAddress;
    address public rewardTokenContract;
    uint public rewardDecimals = 6;
    uint256 public eligibleRewardAmount = 0;
    uint public giveawayId = 1;

    mapping (address => uint256) internal ownerOfNFTRewardBalance;

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
    ) public {
        award_state = AWARD_STATE.CLOSED;
        keyhash = _keyhash;    
    }


    function AirDrop() public onlyOwner {
        require(award_state == AWARD_STATE.OPEN, "The award state is currently closed");
        require(address(rewardTokenContract) != address(0), "ERROR: Must set the Reward Token Contract address before rewarding");
        require(eligibleRewardAmount > 0, "Not Enough Funds to Warrant calling the function to award the Bulls");

        IERC20 tokenContract = IERC20(rewardTokenContract);
        uint256 payout_cut = eligibleRewardAmount / 100;
        uint256 _tokenSupply = getMintTotalSupply();
        for (uint256 i = 1; i <= _tokenSupply; i++) {
            address BullOwner = getNFTOwnerOf(i);
            if (BullOwner != address(0)){
                updateNftOwnerRewardBalance(BullOwner, payout_cut);
            } 
        }
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

    function setRewardTokenAddress(address _address) public onlyOwner {
        rewardTokenContract = _address;
    }

    function setRewardTokenDecimals(uint _decimals) public onlyOwner {
        rewardDecimals = _decimals;
    }
}



