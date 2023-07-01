import CollectionConfig from "./CollectionConfig";

// Update the following array if you change the constructor arguments...
const ContractArguments = [
  CollectionConfig.bnbToken,
  CollectionConfig.voolaToken,
  CollectionConfig.usdtBnbLpToken,
  CollectionConfig.usdtVoolaLpToken,
  CollectionConfig.creatorAddress,
  CollectionConfig.planAAddress,
  CollectionConfig.planBAddress,
  CollectionConfig.tokenName,
  CollectionConfig.tokenSymbol,
] as const;

export default ContractArguments;
