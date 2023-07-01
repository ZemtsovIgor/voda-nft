// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

interface IVODAVSTB {
    /**
     * @notice Referrals
     */
    struct Referrals {
        address user;
        address inviter;
        uint256 count;
        uint256 sum;
        address[] referrals;
    }

    /**
     * @notice Mint NFT
     * @param _inviter: Inviter address
     */
    function mintNFT(address _inviter) external payable;

    /**
     * @notice Burn NFT
     */
    function burn() external;

    /**
     * @notice Getting referrals by inviter address
     * @param _inviter: wallet Address
     */
    function getReferrals(
        address _inviter
    ) external view returns (address[] memory);

    /**
     * @notice Getting inviter by user address
     * @param _user: user Address
     */
    function getInviter(
        address _user
    ) external view returns (address);

    /**
     * @dev Claim rewards for inviters
     *
     */
    function claim() external;

    /**
     * @dev Get reward sum
     * @param _user: user Address
     *
     */
    function getRewardSum(
        address _user
    ) external view returns (uint256);

    /**
     * @dev Get referrals amount
     * @param _user: user Address
     *
     */
    function getReferralsAmountForTwoLevels(
        address _user
    ) external view returns (uint256);

    /**
     * @notice Return token price
     * @param _pair: pair contract
     * @param _token0: is token 0
     */
    function getPrice(
        address _pair,
        bool _token0
    ) external view returns (uint256 price);

    /**
     * @notice Get token balance
     * @param _owner: user address
     */
    function balanceOf(address _owner) external view returns (uint256);

    /**
     * @notice Get token by user address
     * @param _owner: user address
     */
    function tokenIdOf(address _owner) external view returns (uint256);

    /**
     * @notice Get user address by token id
     * @param tokenId: token id
     */
    function ownerOf(uint256 tokenId) external view returns (address);

    /**
     * @notice Get total supply
     */
    function totalSupply() external view returns (uint256);

    /**
     * @notice Get token uri
     */
    function tokenURI() external view returns (string memory);
}
