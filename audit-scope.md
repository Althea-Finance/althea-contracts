# Audit scopes

## [Phase 1]: Token Launch & Vesting 

- Deployment date: 16th April
- Expected audit start date: 1st April
- Expected audit duration: less than 1 week

### Scope

Contracts in scope:

| Contract                         | SLOC |
|----------------------------------|------|
| /src/common/DelegateOps.sol      | 18   | 
| /src/token/TheaToken.sol         | 37   | 
| /src/token/AllocationVesting.sol |      | 

Dependencies:
- LayerZero OFT for multichain support

### Not in scope

External libraries like OpenZeppelin and LayerZero are not in scope.


## [Phase 2]: CDP stablecoin & DAO

TBD

## [Phase 3]: Yield Market

TBD