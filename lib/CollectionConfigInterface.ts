import NetworkConfigInterface from '../lib/NetworkConfigInterface';

export default interface CollectionConfigInterface {
  testnet: NetworkConfigInterface;
  mainnet: NetworkConfigInterface;
  contractName: string;
  tokenName: string;
  tokenSymbol: string;
  bnbToken: string;
  usdtBnbLpToken: string;
  creatorAddress: string;
  planAAddress: string;
  contractAddress: string|null;
};
