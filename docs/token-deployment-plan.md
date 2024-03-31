# THEA TGE
- Contracts to deploy: `THEA`, `rTHEA`, `AllocationsVesting`, `RtheaAllocationsVesting`.
- Contracts deployment date: 1st-2nd April approx
- Vesting schedules Start on 16th April (TGE)

## Token Mints destinations:

### [`33_000_000` THEA] to `AllocationVesting` contract:
- `20_000_000` 	from Core contributors  			[6 month cliff  + 24 month linear vesting]
- `8_000_000` 	from Treasury (minus liquidity) 	[24 month linear vesting]  (`10_000_000` - `2_000_000` for liquidity)
- `2_500_000` 	from Advisors						[3 month cliff  + 24 month linear vesting]
- `2_500_000` 	from Early supporters 				[20% TGE + 80% 12 month linear vesting]

### [`2_000_000` THEA] to Treasury for liquidity 
- `2_000_000` 	to Treasury multisig that will add liquidity

### [`50_000_000` THEA] to Vault/Multisig (For later emissions):  
- `50_000_000` 	for later Emissions 		[36 month linear vesting]
	- These tokens will wait in an Althea Vault until oTHEA logic is deployed. Then, oTHEA redemptions contract will handle the 36 linear vestings. Every oTHEA minted will be redeemable for THEA, so oTHEA emissions have to be vesting controller

### [`9_000_000` THEA] to `RtheaAllocationVesting` contract:
- `9_000_000`	from IDO,  corresponding to the 60% linear vesting. Only claimable by redeeming rTHEA.

### [`6_000_000` THEA] to Hercules address (IDO):
- `6_000_000` THEA (the 40% released at TGE)
- `9_000_000` rTHEA (the 60% recept token to redeem in RtheaAllocationVesting)


## Deployment plan
First phase (soon after IDO 1st april):
- Deploy `THEA` Token contract
- Deploy `AllocationVesting` contract (needs `THEA` address)
- Deploy `RtheaAllocationVesting` contract (needs `THEA` address)
- Deploy `rTHEA` Token contract (needs `RtheaAllocationVesting` address)
- `RtheaAllocationVesting.setRtheaTokenAddress()` (needs `rTHEA` address)
- Mint and transfer `9_000_000` rTHEA to Hercules address for IDO
- `THEA.mintTo()` `6_000_000` THEA to Hercules address for IDO
  
Second phase (before TGE, 15th april, or when allocations are final)
- `THEA.mintTo()` `9_000_000` THEA `RtheaAllocationVesting`
- `THEA.mintTo()` `33_000_000` THEA `AllocationVesting`
- `THEA.mintTo()` `50_000_000` THEA to Vault/Multisig for later Emissions
- `THEA.mintTo()` `2_000_000`  THEA to Treasury multisig (to add liquidity + incentives)
- `AllocationVestings.setVestingSchedules()`  [start date = 16th April (hour??)]
- `RTheaAllocationVestings.setVestingSchedules()`  [start date = 16th April (hour??)]
- Renounce all relevant contract ownerships

## Missing Info:
- Time of the day in 16th April when tokens will be claimable from the vesting contract (TGE exact time)
- Treasury Multisig address (that will add liquidity, and have the vestings as well)
- Vault Multisig address (50% supply for later emissions)
- Addresses and allocations of all vesting schedules:
	- Core contributors (common multisigs as Jaimie suggested + payment spliiter?)
	- Early supporters
	- Advisors



