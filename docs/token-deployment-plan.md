# THEA token & Vesting contract deployment
- Contracts deployment date: 1st-2nd April approx
- Vesting schedules Start on 16th April (TGE)

## Token Mints destinations:

### [`42_000_000` THEA] to Vesting contract address:
- `20_000_000` 	from Core contributors  			[6 month cliff  + 24 month linear vesting]
- `8_000_000` 	from Treasury (minus liquidity) 	[24 month linear vesting]  (`10_000_000` - `2_000_000` for liquidity)
- `2_500_000` 	from Advisors						[3 month cliff  + 24 month linear vesting]
- `2_500_000` 	from Early supporters 				[20% TGE + 80% 12 month linear vesting]
- `9_000_000`	from IDO, 					[60% with linear vesting, redeemable for rTHEA]

### [`6_000_000` THEA + `9_000_000` rTHEA] to Hercules address (IDO):
- `6_000_000` THEA (the 40% released at TGE)
- `9_000_000` rTHEA (the 60% recept token with linear vesting)

### [`2_000_000` THEA] to Treasury for liquidity 
- `2_000_000` 	to Treasury multisig that will add liquidity

### [`50_000_000` THEA] to Vault/Multisig (For later emissions):  
- `50_000_000` 	for later Emissions 		[36 month linear vesting]
	- These tokens will wait in an Althea Vault until oTHEA logic is deployed. Then, oTHEA redemptions contract will handle the 36 linear vestings. Every oTHEA minted will be redeemable for THEA, so oTHEA emissions have to be vesting controller

## Deployment plan
- Deploy THEA Token contract
- Deploy rTHEA Token contract
- Deploy LinearVesting contract (with THEA in the constructor)
- `THEA.mintTo()` `6_000_000` THEA to Hercules address for IDO
- `rTHEA.mintTo()` `9_000_000` THEA to Hercules address for IDO
- `THEA.mintTo()` `50_000_000` THEA to Vault/Multisig for later Emissions
- `THEA.mintTo()` `2_000_000`  THEA to Treasury multisig (to add liquidity + incentives)
- `THEA.mintTo()` `42_000_000` THEA to LinearVesting contract (includes tokens available at TGE).
- `LinearVesting.setVestingSchedules()`  [start date = 16th April (hour??)]
- `THEA.renounceOwnership()`

## Missing Info:
- Time of the day in 16th April when tokens will be claimable from the vesting contract (TGE exact time)
- Treasury Multisig address (that will add liquidity, and have the vestings as well)
- Vault Multisig address (50% supply for later emissions)
- Addresses and allocations of all vesting schedules:
	- Core contributors (common multisigs as Jaimie suggested + payment spliiter?)
	- Early supporters
	- Advisors



