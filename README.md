# Juicebox Contribution NFT Reward Mechanism

## Motivation

If added to an existing project via a funding cycle, NFT rewards can provide additional incentive for contributors to participate in funding of a project.

## Mechanic

Within one collection, NFTs can be minted within any number of pre-programmed tiers.

Each tier has the following optional properties:

- a contribution floor amount.
- a max quantity.
- a number of voting units to associate with each unit within the tier.
- a reserved rate, allowing a proprtion of units within the tier to be minted to a pre-programmed beneficiary.
- URI, overridable by a URI resolver that can return dynamic values for each unit with the tier.
- a lock date, before which the tier must remain accessible.

New tiers can be added, so long as they respect the contract's `flags` that specify if new tiers can influence voting units, reserved quantities, or be manually minted.

Tiers can also be removed, so long as they are not locked.

An incoming payment can specify any number of tiers to mint as part of the payment, so long as the tier's prices are contained within the paid amount. If specific tiers aren't specified, the best available tier will be minted, unless a flag is specifically sent along with the payment telling the contract to not mint.

If a payment received does not meet a minting threshold or is in excess of the minted tiers, the balance is stored as a credit which will be added to future payments and applied to mints at that time. A flag can also be passed to avoid accepting payments that aren't applied to mints in full. 

The contract's owner can mint on demand from tier's that have been pre-programmed to allow manual token minting.

The NFTs from each tier can also be used for redemptions against the underlying Juicebox treasury. The rate of redemptions corresponds to the price floor of the tier being redeemed, compared to the total price floors of all minted NFTs.

The collection can be used for on-chain governance. Votes can be solicited from all tiers, or only from specific tiers.

# Install Foundry

To get set up:

1. Install [Foundry](https://github.com/gakonst/foundry).

```bash
curl -L https://foundry.paradigm.xyz | sh
```

2. Install external lib(s)

```bash
git submodule update --init && yarn install
```

then run

```bash
forge update
```

If git modules are failing to clone, not installing, etc (ie overall submodule misbehaving), use `git submodule update --init --recursive --force`

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

## Rinkeby

```bash
yarn deploy-rinkeby
```

## Mainnet

```bash
yarn deploy-mainnet
```

The deployments are stored in ./broadcast

See the [Foundry Book for available options](https://book.getfoundry.sh/reference/forge/forge-create.html).
