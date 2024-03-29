# THEA token & Vesting contract deployment
- Date: 1st-2nd april approx
- Vesting schedules strat on 16th april (TGE)

## Token Mints destinations:

### [`33_375_000` THEA] to Vesting contract address:
- `20_000_000` 	from Core contributors  			[6 month cliff  + 24 month linear vesting]
- `8_375_000` 	from Treasury (minus liquidity) 	[24 month linear vesting]  (`10_000_000` - `1_625_000` for liquidity)
- `2_500_000` 	from Advisors						[3 month cliff  + 24 month linear vesting]
- `2_500_000` 	from Early supporters 				[20% TGE + 80% 12 month linear vesting]

### [`15_000_000` THEA] to Hercules address (IDO):
- `15_000_000`	from IDO					[40% TGE + 60% 6 month linear vesting, but Hercules handles the vesting]

### [`1_625_000` THEA] to Treasury for liquidity 
- `1_625_000` 	to Treasury multisig that will add liquidity

### [`50_000_000` THEA] to Vault/Multisig (For later emissions):  
- `50_000_000` 	for later Emissions 		[36 month linear vesting]
	- These tokens will wait in an Althea Vault until oTHEA logic is deployed. Then, oTHEA redemptions contract will handle the 36 linear vesting. Every oTHEA minted will be redemable for THEA, so oTHEA emissions has to be vesting controller

## Deployment plan
- Deploy LinearVesting contract
- Deploy THEA Token contract
- `THEA.mintTo()` `50_000_000` THEA to Vault/Multisig for later Emissions
- `THEA.mintTo()` `15_000_000` THEA to Hercules address for IDO
- `THEA.mintTo()` `33_375_000` THEA to LinearVesting contract (includes the tokens that will be are available at TGE, so claiming is centralized in our webpage)
- `THEA.mintTo()` `1_625_000`  THEA to multisig that will add liquidity
- `LinearVesting.setToken(THEA)`
- `LinearVesting.setVestingSchedules()`  [start date = 16th april (hour??)]
- `renounceOwnership()`

## Missing Info:
- Time of the day in 16th april when tokens will be claimable from the vesting contract (TGE exact time)
- Treasury Multisig address (that will add liquidity, and have the vestings as well)
- Vault Multisig address (50% supply for later emissions)
- Addresses and allocations of all vesting schedules:
	- Core contributors (common multisigs as Jaimie suggested + payment spliiter?)
	- Early supporters
	- Advisors



