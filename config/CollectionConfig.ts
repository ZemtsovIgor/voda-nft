import CollectionConfigInterface from "../lib/CollectionConfigInterface";
import * as Networks from "../lib/Networks";

const CollectionConfig: CollectionConfigInterface = {
  testnet: Networks.bscTestnet,
  mainnet: Networks.bscMainnet,
  contractName: "VODAVSTB",
  tokenName: "VODA SBT",
  tokenSymbol: "VSTB",
  bnbToken: "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c",
  usdtBnbLpToken: "0x16b9a82891338f9bA80E2D6970FddA79D1eb0daE",
  creatorAddress: "0x729816eD59Ac14C3Fced1051d80c89eeDA7eF54d",
  planAAddress: "0x0e5b5603ebc3c1841a0b2ce1e7afc081c50ca310",
  contractAddress: null,
};

export default CollectionConfig;
