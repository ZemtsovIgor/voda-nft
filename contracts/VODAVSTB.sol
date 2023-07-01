// SPDX-License-Identifier: MIT
// VODAVSTB by ShimmeringPort

pragma solidity ^0.8.4;
pragma abicoder v2;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../lib/EnumerableMap.sol";
import "../lib/ERC165.sol";
import "../lib/IERC721.sol";
import "../lib/ISBT721.sol";
import "../lib/IERC721Metadata.sol";
import '../lib/IVODAVSTB.sol';
import "../lib/IUniswapV2Pair.sol";

contract VODAVSTB is IVODAVSTB, ISBT721, IERC721Metadata, Ownable {
    using Strings for uint256;
    using Counters for Counters.Counter;
    using EnumerableMap for EnumerableMap.AddressToUintMap;
    using EnumerableMap for EnumerableMap.UintToAddressMap;

    // Mapping from token ID to owner address
    EnumerableMap.UintToAddressMap private _ownerMap;
    EnumerableMap.AddressToUintMap private _tokenMap;

    // Token Id
    Counters.Counter private _tokenId;

    // Token name
    string public name;

    // Token symbol
    string public symbol;

    // Token URI
    string private _baseTokenURI = 'https://voda.infura-ipfs.io/ipfs/Qmd5xyZinr7gV5mQMyofSYahVaCpMqBW8AvGXrJRaPqEJL/1.json';

    /**
     * @dev Initializes the contract by setting a `name` and a `symbol` to the token collection.
     */

    IERC20 public bnbToken;
    IUniswapV2Pair public usdtBnbLpToken;
    bool public bnbIsToken0;
    uint256 public referralFee = 0;
    uint256 public usdCost = 1;

    uint224 constant Q112 = 2**112;

    uint256 public bnbCost;
    address public creatorAddress;
    address public planAAddress;

    /**
     * @notice
     *   This is a array where we store all Referrals that are performed on the Contract
     *   The referrals for each address are stored at a certain index, the index can be found using the inviters mapping
     */
    Referrals[] internal referrals;

    /**
     * @notice
     * inviters is used to keep track of the INDEX for the referrals in the referrals array
     */
    mapping(address => uint256) private inviters;

    bool public paused = false;

    /**
     * @notice Claim event is triggered whenever a user clim rewards, address is indexed to make it filterable
     */
    event Claimed(address indexed user, uint256 reward, uint256 timestamp);


    /**
     * @notice Constructor
     * @param _tokenName: name of the token
     * @param _tokenSymbol: symbol of the token
     */
    constructor(
        IERC20 _bnbToken,
        address _usdtBnbLpToken,
        address _creatorAddress,
        address _planAAddress,
        string memory _tokenName,
        string memory _tokenSymbol
    ) {
        require(
            IUniswapV2Pair(_usdtBnbLpToken).token0() == address(_bnbToken) ||
            IUniswapV2Pair(_usdtBnbLpToken).token1() == address(_bnbToken),
            "BNB not Found"
        );
        bnbToken = _bnbToken;
        usdtBnbLpToken = IUniswapV2Pair(_usdtBnbLpToken);
        bnbIsToken0 = usdtBnbLpToken.token0() == address(_bnbToken);
        bnbCost = 1 * 10**uint(16);
        creatorAddress = _creatorAddress;
        planAAddress = _planAAddress;
        name = _tokenName;
        symbol = _tokenSymbol;
        referrals.push();
    }

    /**
     * @notice Mint NFT
     * @param _inviter: Inviter address
     */
    function mintNFT(address _inviter) external payable {
        require(!paused, 'The contract is paused!');
        require(msg.sender != address(0), "Address is empty");
        require(!_tokenMap.contains(msg.sender), "VSBT already exists");

        uint256 _price = _getPrice(usdtBnbLpToken, bnbIsToken0);
        uint256 totalCost = _price * usdCost;

        require(msg.value >= totalCost, 'Insufficient funds!');

        _tokenId.increment();
        uint256 tokenId = _tokenId.current();

        bnbCost = totalCost;

        require(_inviter != address(0), 'Only With Inviter');
        require(_tokenMap.contains(_inviter), 'Only NFT holder');

        uint256 senderIndex = inviters[msg.sender];
        if (senderIndex == 0) {
            senderIndex = _addInviter(msg.sender);
            referrals[senderIndex].inviter = _inviter;
        } else {
            require(referrals[senderIndex].inviter == _inviter, 'You have other inviter');
        }

        uint256 inviterIndex = inviters[_inviter];

        if (inviterIndex == 0) {
            inviterIndex = _addInviter(_inviter);
        }

        bool referralExist = false;
        uint256 listIndex = 0;
        while (listIndex < referrals[inviterIndex].referrals.length) {
            if (referrals[inviterIndex].referrals[listIndex] == msg.sender) {
                referralExist = true;
            }

            listIndex++;
        }

        if (!referralExist) {
            referrals[inviterIndex].referrals.push(msg.sender);
        }

        referrals[inviterIndex].count += 1;
        uint256 feePerOneNft = totalCost * 10 / 100;

        referrals[inviterIndex].sum += feePerOneNft;
        referralFee += feePerOneNft;

        address preInviter = referrals[inviterIndex].inviter;
        uint256 preInviterIndex = inviters[preInviter];

        if (preInviterIndex > 0) {
            referrals[preInviterIndex].count += 1;
            referrals[preInviterIndex].sum += feePerOneNft;
            referralFee += feePerOneNft;
        }

        _tokenMap.set(msg.sender, tokenId);
        _ownerMap.set(tokenId, msg.sender);

        emit Attest(msg.sender, tokenId);
        emit Transfer(address(0), msg.sender, tokenId);
    }

    /**
     * @notice Mint NFT for Address
     * @param _receiver: receiver address
     * @dev Callable by owner
     */
    function mintForAddress(address _receiver) external onlyOwner {
        require(_receiver != address(0), "Address is empty");
        require(!_tokenMap.contains(_receiver), "SBT already exists");

        _tokenId.increment();
        uint256 tokenId = _tokenId.current();

        _tokenMap.set(_receiver, tokenId);
        _ownerMap.set(tokenId, _receiver);

        emit Attest(_receiver, tokenId);
        emit Transfer(address(0), _receiver, tokenId);
    }

    /**
     * @notice Burn NFT
     */
    function burn() external override(ISBT721, IVODAVSTB) {
        address sender = _msgSender();

        require(
            _tokenMap.contains(sender),
            "The account does not have any VSTB"
        );

        uint256 tokenId = _tokenMap.get(sender);

        _tokenMap.remove(sender);
        _ownerMap.remove(tokenId);

        emit Burn(sender, tokenId);
        emit Transfer(sender, address(0), tokenId);
    }

    /**
     * @notice attest NFT
     * @param _to: user address
     * @dev Callable by owner
     */
    function attest(address _to) external onlyOwner returns (uint256) {
        require(_to != address(0), "Address is empty");
        require(!_tokenMap.contains(_to), "SBT already exists");

        _tokenId.increment();
        uint256 tokenId = _tokenId.current();

        _tokenMap.set(_to, tokenId);
        _ownerMap.set(tokenId, _to);

        emit Attest(_to, tokenId);
        emit Transfer(address(0), _to, tokenId);

        return tokenId;
    }

    /**
     * @notice Revoke NFT
     * @param _from: user address
     * @dev Callable by owner
     */
    function revoke(
        address _from
    ) external onlyOwner {
        require(_from != address(0), "Address is empty");
        require(_tokenMap.contains(_from), "The account does not have any SBT");

        uint256 tokenId = _tokenMap.get(_from);

        _tokenMap.remove(_from);
        _ownerMap.remove(tokenId);

        emit Revoke(_from, tokenId);
        emit Transfer(_from, address(0), tokenId);
    }

    /**
     * @notice Setting new NFT cost
     * @param _usdCost: new BNB cost
     * @dev Callable by owner
     */
    function setCost(
        uint256 _usdCost
    ) external onlyOwner {
        usdCost = _usdCost;
    }

    /**
     * @notice Setting contract pause
     * @param _state: pause state
     * @dev Callable by owner
     */
    function setPaused(
        bool _state
    ) external onlyOwner {
        paused = _state;
    }

    /**
     * @notice Setting addresses for withdraw
     * @param _creatorAddress: creator address
     * @param _planAAddress: planA address
     * @dev Callable by owner
     */
    function setAddresses(
        address _creatorAddress,
        address _planAAddress
    ) external onlyOwner {
        creatorAddress = _creatorAddress;
        planAAddress = _planAAddress;
    }

    /**
     * @notice Getting referrals by inviter address
     * @param _inviter: wallet Address
     */
    function getReferrals(
        address _inviter
    ) external view returns (address[] memory) {
        uint256 inviterIndex = inviters[_inviter];
        uint256 referralsCount = referrals[inviterIndex].referrals.length;
        address[] memory referralsList = new address[](referralsCount);
        uint256 referralIndex = 0;

        while (referralIndex < referralsCount) {
            referralsList[referralIndex] = referrals[inviterIndex].referrals[referralIndex];

            referralIndex++;
        }

        return referralsList;
    }

    /**
     * @notice Getting inviter by user address
     * @param _user: user Address
     */
    function getInviter(
        address _user
    ) external view returns (address) {
        uint256 userIndex = inviters[_user];
        require(userIndex > 0, 'Inviter not found');

        return referrals[userIndex].inviter;
    }

    /**
     * @dev Claim rewards for inviters
     *
     */
    function claim() external {
        uint256 userIndex = inviters[msg.sender];
        require(userIndex > 0, 'Inviter not found');

        uint256 reward = referrals[userIndex].sum;
        require(reward > 0, 'Reward is missing');

        referralFee -= reward;

        referrals[userIndex].sum = 0;

        (bool hs, ) = payable(msg.sender).call{value: reward}('');
        require(hs);

        emit Claimed(msg.sender, reward, block.timestamp);
    }

    /**
     * @dev Get reward sum
     * @param _user: user Address
     *
     */
    function getRewardSum(
        address _user
    ) external view returns (uint256) {
        uint256 userIndex = inviters[_user];
        require(userIndex > 0, 'Inviter not found');

        return referrals[userIndex].sum;
    }

    /**
     * @dev Get referrals amount
     * @param _user: user Address
     *
     */
    function getReferralsAmountForTwoLevels(
        address _user
    ) external view returns (uint256) {
        uint256 userIndex = inviters[_user];
        require(userIndex > 0, 'Inviter not found');

        return referrals[userIndex].count;
    }

    /**
     * @notice Return token price
     * @param _pair: pair contract
     * @param _token0: is token 0
     */
    function getPrice(
        address _pair,
        bool _token0
    ) public view returns (uint256 price) {
        IUniswapV2Pair pair = IUniswapV2Pair(_pair);
        price = _getPrice(pair, _token0);
    }

    /**
     * @notice Return token price
     * @param _pair: pair contract
     * @param _token0: is token 0
     */
    function _getPrice(
        IUniswapV2Pair _pair,
        bool _token0
    ) internal view returns (uint256 price) {
        uint224 _priceCumulative;

        (
            uint112 _reserve0,
            uint112 _reserve1,
            uint32 blockTimestampLast
        ) = _pair.getReserves();

        if (_token0) {
            _priceCumulative = (Q112 * _reserve0) / _reserve1;
        } else {
            _priceCumulative = (Q112 * _reserve1) / _reserve0;
        }

        price = (_priceCumulative * 1e18)  / Q112;
    }

    /**
     * @dev Create new referrals
     *
     * @param _inviter: user address
     */
    function _addInviter(
        address _inviter
    )
    internal
    returns (uint256)
    {
        referrals.push();
        uint256 inviterIndex = referrals.length - 1;
        referrals[inviterIndex].user = _inviter;
        inviters[_inviter] = inviterIndex;
        return inviterIndex;
    }

    /**
     * @notice withdraw
     * @dev Callable by owner
     */
    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        uint256 withdrawBalance = balance - referralFee;

        (bool hs, ) = payable(creatorAddress).call{value: withdrawBalance * 30 / 100}('');
        require(hs);


        (bool os, ) = payable(planAAddress).call{value: withdrawBalance * 70 / 100}('');
        require(os);
    }

    /**
     * @notice Update _baseTokenURI
     * @param _uri: new token uri
     * @dev Callable by owner
     */
    function setBaseTokenURI(string calldata _uri) external onlyOwner {
        _baseTokenURI = _uri;
    }

    /**
     * @notice Get token balance
     * @param _owner: user address
     */
    function balanceOf(
        address _owner
    )
    external
    override(ISBT721, IVODAVSTB)
    view returns (uint256) {
        (bool success, ) = _tokenMap.tryGet(_owner);
        return success ? 1 : 0;
    }

    /**
     * @notice Get token by user address
     * @param _owner: user address
     */
    function tokenIdOf(
        address _owner
    )
    external
    override(ISBT721, IVODAVSTB)
    view returns (uint256) {
        return _tokenMap.get(_owner, "The wallet has not attested any VSTB");
    }

    /**
     * @notice Get user address by token id
     * @param tokenId: token id
     */
    function ownerOf(
        uint256 tokenId
    )
    external
    override(ISBT721, IVODAVSTB)
    view returns (address) {
        return _ownerMap.get(tokenId, "Invalid tokenId");
    }

    /**
     * @notice Get total supply
     */
    function totalSupply()
    external
    override(ISBT721, IVODAVSTB)
    view returns (uint256) {
        return _tokenMap.length();
    }

    /**
     * @notice Get token uri
     */
    function tokenURI()
    external
    override(IVODAVSTB, IERC721Metadata)
    view returns (string memory) {
        return
        bytes(_baseTokenURI).length > 0
        ? string(abi.encodePacked(_baseTokenURI))
        : "";
    }
}
