# Juicebox 721 Distribution Mechanism

## Motivation

If added to an existing project via a funding cycle, NFTs can provide utility or incentive for contributors to participate in funding of a project.

## Mechanic

Within one collection, NFTs can be minted within any number of pre-programmed tiers.

Each tier has the following optional properties:

- a contribution floor amount.
- a max quantity.
- a number of voting units to associate with each unit within the tier.
- a reserved rate, allowing a proprtion of units within the tier to be minted to a pre-programmed beneficiary.
- URI, overridable by a URI resolver that can return dynamic values for each unit with the tier.
- a lock date, before which the tier must remain accessible.
- the ability for the contract's owner to mint tokens from the tier on demand.
- if the tokens within the tier can have transfers paused on a per-funding-cycle basis, or if they must always remain transferable.

New tiers can be added, so long as they respect the contract's `flags` that specify if new tiers can influence voting units, reserved quantities, or be manually minted.

Tiers can also be removed, so long as they are not locked.

An incoming payment can specify any number of tiers to mint as part of the payment, so long as the sum of the tier's prices are contained within the paid amount. If specific tiers aren't specified, the best available tier will be minted based on the specified floor amount, unless a flag is specifically sent along with the payment telling the contract to not mint.

If a tier's contribution floor is specified in a currency different to the incoming payment, a `JBPrices` contract will by used for trying to normalize the values.

If a payment received does not meet a minting threshold or is in excess of the minted tiers, the balance is stored as a credit which will be added to future payments and applied to mints at that time. A flag can also be passed to avoid accepting payments that aren't applied to mints in full.

The contract's owner can mint on demand from tier's that have been pre-programmed to allow manual token minting.

The NFTs from each tier can also be used for redemptions against the underlying Juicebox treasury. The rate of redemptions corresponds to the price floor of the tier being redeemed, compared to the total price floors of all minted NFTs. Fungible project tokens cannot be being redeemed at the same time. In order to activate NFT redemptions, turn on the `shouldUseDataSourceForRedeem` metadata flag of your next funding cycle.

The NFTs can serve as utilities for on-chain governance if specified during the collection's deployment. Voting delegation can be made on a per-tier basis, or on a global basis.

## Architecture

An understanding of how the Juicebox protocol's pay and redeem functionality works is an important prereq to understanding how this repo's contracts work and attach themselves to Juicebox's regular operating behavior. This contract specifically makes use of the DataSource+Delegate pattern. See https://info.juicebox.money/dev/.

In order to use a 721 delegate, a Juicebox project should be launched from `JBTiered721DelegateProjectDeployer` instead of a `JBController`. This Deployer will deploy a `JBTiered721Delegate` (through it's reference to a `JBTiered721DelegateDeployer`) and attach it to the first funding cycle of the newly launched project as a DataSource and Delegate. Funding cycle reconfigurations can also be done using the `JBTiered721DelegateProjectDeployer`, though it will need to have Operator permissions from the project's owner.

The abstract `JB721Delegate` implementation of the ERC721 Juicebox DataSource+Delegate extension can be used for any distribution mechanic. This repo includes one implementation – the `JBTiered721Delegate` – as well as two extensions that offer on-chain governance capabilities to the distributed tokens. 

All `JBTiered721Delegate`'s use a generic `JBTiered721DelegateStore` to store it's data.

## Deploy

The deployer copies the data of a pre-existing cononical version of the 721 contracts, which can be either GlobalGovernance, TierGovernance, or no governance. This was done to keep the deployer contract size small enough to be deployable, without the extra cost of the delegatecalls associated with a proxy pattern. 


# Install

Quick all-in-one command:

```bash
rm -Rf juice-721-delegate || true && git clone -n https://github.com/jbx-protocol/juice-721-delegate && cd juice-721-delegate && git pull origin f9893b1497098241dd3a664956d8016ff0d0efd0 && git checkout FETCH_HEAD && foundryup && git submodule update --init --recursive --force && yarn install && forge test --gas-report
```

To get set up:

1. Install [Foundry](https://github.com/gakonst/foundry).

```bash
curl -L https://foundry.paradigm.xyz | sh
```

2. Install external lib(s)

```bash
git submodule update --init --recursive --force && yarn install
```

then run

```bash
forge update
```

3. Run tests:

```bash
forge test
```

4. Update Foundry periodically:

```bash
foundryup
```

#### Setup

Configure the .env variables, and add a mnemonic.txt file with the mnemonic of the deployer wallet. The sender address in the .env must correspond to the mnemonic account.

## Goerli

```bash
yarn deploy-goerli
```

## Mainnet

```bash
yarn deploy-mainnet
```

The deployments are stored in ./broadcast

See the [Foundry Book for available options](https://book.getfoundry.sh/reference/forge/forge-create.html).
