# JBX Contribution NFT Reward Mechanism

## Motivation

If added to an existing project via a funding cycle, NFT rewards can provide additional incentive for contributors to participate in funding of a project.

## Implementation

`AbstractNFTRewardDelegate` implements several Juicebox interfaces (`IJBFundingCycleDataSource`, `IJBPayDelegate`, `IJBRedemptionDelegate`) that make it possible to use it as a funding cycle data source. It also acts as an ERC721 reward token itself. The contract is highly configurable through constructor parameters. Note that this isn't meant to replace the ERC20 project token distribution.

This is an abstract contract, in its most basic implementation, `SimpleNFTRewardDelegate` will mint NFTs to participants contributing over some defined minimum and up to some number of NFTs. The constructor parameters are:

- projectId: JBX project id of the project in question.
- directory: Platform JBDirectory.
- maxSupply: NFT supply cap, to remove supply constraint, set this to `type(uint256).max`.
- minContribution: JBTokenAmount-based definition of minimum contribution that includes the token if used and balance to qualify for the mint.
- _name: NFT name.
- _symbol: NFT symbol.
- _uri: NFT base URI.
- _tokenUriResolverAddress: Token URI resolver, in the basic case this should be `address(0)`.
- _contractMetadataUri: Location of OpenSea-style contract metadata.
- _admin: EOA or multisig capable of executing arbitrary contract calls.

## Example Uses

### Bounded Tiers

`TieredNFTRewardDelegate` is a more complex implementation allowing for reward distribution in limited tiers. For example, the higher the contribution the more rare the NFT the participant would get. This contract takes tier configuration that includes tier floor contribution amount, tier size and id definition. Consider this tier definition:

```js
[
  { contributionFloor: 1 ether, idCeiling: 1001, remainingAllowance: 1000 },
  { contributionFloor: 5 ether, idCeiling: 1501, remainingAllowance: 500 }
]
```

This configuration will mint 1000 NFTs for contributors depositing more than 1 ether but below 5 and 500 NFTs for people contributing 5 or more. The combination of `idCeiling` and `remainingAllowance` will generate consecutive, increasing token ids. For example, the first deposit of 1 ether will receive token id `1001 - 1000`: 1. The second will get `1001 - 999`: 2, and so on. Token id 0 is interpreted by `AbstractNFTRewardDelegate` as a do not mint instruction.

In addition to this `globalMintAllowance` and `userMintCap` parameters provide the option of additional caps. They can be modified by the admin with `setCaps(uint256,uint256)`. For example, setting `globalMintAllowance` to 1000 in the above case will limit total number of issued NFTs to 1000 regardless of the tier they were minted in while still limiting the 5 ether + tier to 500 tokens. `userMintCap` can be used to limit how many NFT rewards a single account can get. By default, these limits are disabled by assigning them to `type(uint256).max`.

It is necessary to pass the tier configuration into the constructor sorted by contribution amount and there should be no id range overlap.

### Unbounded Tiers

Another, simpler and gas-cheaper example of a price resolver is `OpenTieredNFTRewardDelegate`, this contract comes with its own token URI resolver as well: `OpenTieredTokenUriResolver`. It is necessary to use them together or to implement another `IToken721UriResolver`. `OpenTieredNFTRewardDelegate` is a leaner version that removes caps and range limits. This reduces storage and call gas costs. Tier configuration might look like this:

```js
[
  { contributionFloor: 1 ether },
  { contributionFloor: 5 ether },
  { contributionFloor: 10 ether }
]
```

In this configuration anyone who deposits more than 1 ether, but less than 5 will get a tier-1 NFT, 5-10 tier-2 NFT and 10+ tier-3 NFT. There are no explicit limits on how many NFTs can be issued per tier. Practically however they're limited to `type(uint248).max`. The reason is that the tier is encoded in the low 8 bits of the token id. This is the reason for the custom token URI resolver. The URI resolver will parse the bottom 8 bits into an int and return an URI with that id. This means that many token ids will show the same content. The main content of the token id is derived from the contributor address and current block number. There is no collision check because the price resolver isn't aware if it's working with an ERC721 or 1155 type token.

It is necessary for the tiers to be sorted by contribution amount in the constructor.

### Customization

`AbstractNFTRewardDelegate` already implements most of the functionality necessary to offer NFT rewards. It has Juicebox hooks, an ERC721 NFT implementation and some core functionality. To customize the functionality implementing contracts are expected to provide a single function: `validateContribution(address,JBTokenAmount`. This function will validate the `JBTokenAmount` contribution from the `address` and mint the token to that account if needed. This function must not `revert` as that will cause contribution failure. NFT rewards are meant to be optionals and must not prevent contribution deposit. Usage of `JBTokenAmount` allows implementing contracts to use non-ether "currencies". For example, `OpenTieredNFTRewardDelegate` has a parameter in the constructor to set the contribution token address. To use ether there is a Juicebox constant in `JBTokens.ETH`.

### Deployment

It is necessary to deploy the `TieredPriceResolver` then `NFTRewardDataSourceDelegate` and then assign the latter to a funding cycle of the project. In the unbounded example, `OpenTieredPriceResolver` and `OpenTieredTokenUriResolver` need to deployed first, passed to the deployment of `NFTRewardDataSourceDelegate` and then assigned to a funding cycle.

### Post-deployment Admin Actions

One of the deployment parameters is an address that can be used to administer the contract. It should be set to an EOA or a multisig address capable of performing arbitrary operations. This account will be able to perform the following actions.

#### Mint

The admin account can issue tokens to any address without payment. Use of this function is not recommended. Currently it will mint the next token id to the provided address which may not mesh well with whatever price resolver the token may be using.

#### Prevent Token Transfers

There are use-cases where it's necessary to block reward NFT token holders from transferring them. This can be done after the token contract is deployed by calling `setTransferrable(false)`. At this point the admin will also be able to `burn` tokens from holders.

#### URI Management

There are two URIs associated with the contract: token URI and contract URI. The former is used to determine the location of the specific asset and the latter should contain OpenSea-style metadata. These can be set with either `setTokenUriResolver` or `setTokenUri` and `setContractUri`. `setTokenUriResolver` is used for complex cases where appending the token id to a base URI is not enough. All of these parameters are also part of the constructor.
