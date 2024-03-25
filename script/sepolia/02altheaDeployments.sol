// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "lib/forge-std/src/Script.sol";
import {IAltheaCore} from "src/interfaces/IAltheaCore.sol";
import {AltheaCore} from "src/core/AltheaCore.sol";
import {PriceFeed} from "src/core/PriceFeed.sol";
import {Factory} from "src/core/Factory.sol";
import {IFactory} from "src/interfaces/IFactory.sol";
import {SortedTroves} from "src/core/SortedTroves.sol";
import {ILiquidationManager} from "src/interfaces/ILiquidationManager.sol";
import {LiquidationManager} from "src/core/LiquidationManager.sol";
import {GasPool} from "src/core/GasPool.sol";
import {IBorrowerOperations} from "src/interfaces/IBorrowerOperations.sol";
import {BorrowerOperations} from "src/core/BorrowerOperations.sol";
import {IDebtToken} from "src/interfaces/IDebtToken.sol";
import {DebtToken} from "src/core/DebtToken.sol";
import {IStabilityPool} from "src/interfaces/IStabilityPool.sol";
import {StabilityPool} from "src/core/StabilityPool.sol";
import {TroveManager} from "src/core/TroveManager.sol";

import {IIncentiveVoting} from "src/interfaces/IIncentiveVoting.sol";
import {IncentiveVoting} from "src/dao/IncentiveVoting.sol";
import {ITheaToken} from "src/interfaces/ITheaToken.sol";
import {TheaToken} from "src/dao/TheaToken.sol";
import {InterimAdmin} from "src/dao/InterimAdmin.sol";
import {FeeReceiver} from "src/dao/FeeReceiver.sol";
import {ITokenLocker} from "src/interfaces/ITokenLocker.sol";
import {TokenLocker} from "src/dao/TokenLocker.sol";
import {ITheaToken} from "src/interfaces/ITheaToken.sol";
import {IAltheaVault} from "src/interfaces/IVault.sol";
import {AltheaVault} from "src/dao/Vault.sol";
import "src/core/PriceFeed.sol";

import "script/sepolia/00constants.sol";

contract AltheaCoreDeployment is Script {
    AltheaCore altheaCore;
    PriceFeed priceFeed;
    FeeReceiver feeReceiver;
    TheaToken theaToken;
    TokenLocker tokenLocker;
    AltheaVault altheaVault;
    InterimAdmin interimAdmin;
    SortedTroves sortedTroves;
    LiquidationManager liquidationManager;
    Factory factory;
    GasPool gasPool;
    BorrowerOperations borrowerOperations;
    DebtToken debtToken;
    StabilityPool stabilityPool;
    TroveManager troveManager;
    IncentiveVoting incentiveVoting;


    function setUp() public virtual {}

    function run() public {
        vm.startBroadcast();
        deployAltheaCore();
        vm.stopBroadcast();

        vm.startBroadcast();
        deployPriceFeed();
        altheaCore.setPriceFeed(address(priceFeed));
        vm.stopBroadcast();

        vm.startBroadcast();
        deployFeeReceiver();
        vm.stopBroadcast();

        vm.startBroadcast();
        deployInterimAdmin();
        vm.stopBroadcast();

        vm.startBroadcast();
        deployTheaToken();
        vm.stopBroadcast();

        vm.startBroadcast();
        deployTokenLocker();
        theaToken.setLockerAddress(address(tokenLocker));
        vm.stopBroadcast();

        vm.startBroadcast();
        deploySortedTroves();
        vm.stopBroadcast();

        vm.startBroadcast();
        deployFactory();
        vm.stopBroadcast();

        vm.startBroadcast();
        deployLiquidationManager();
        factory.setLiquidationManagerAddress(address(liquidationManager));
        vm.stopBroadcast();

        vm.startBroadcast();
        deployGasPool();
        vm.stopBroadcast();

        vm.startBroadcast();
        deployBorrowerOperations();
        factory.setBorrowerOperationsAddress(address(borrowerOperations));
        liquidationManager.setBorrowerOperationsAddress(address(borrowerOperations));
        vm.stopBroadcast();

        vm.startBroadcast();
        deployDebtToken();
        factory.setDebtTokenAddress(address(debtToken));
        borrowerOperations.setDebtTokenAddress(address(debtToken));
        vm.stopBroadcast();

        vm.startBroadcast();
        deployStabilityPool();
        factory.setStabilityPoolAddress(address(stabilityPool));
        vm.stopBroadcast();


        vm.startBroadcast();
        deployTroveManager();
        factory.setTroveManagerAddress(address(troveManager));
        vm.stopBroadcast();

        vm.startBroadcast();
        deployIncentiveVoting();
        tokenLocker.setIncentiveVotingAddress(address(incentiveVoting));
        vm.stopBroadcast();

        vm.startBroadcast();
        deployAltheaVault();
        stabilityPool.setAltheaVaultAddress(address(altheaVault));
        theaToken.setAltheaVaultAddress(address(altheaVault));
        troveManager.setAltheaVaultAddress(address(altheaVault));
        incentiveVoting.setAltheaVaultAddress(address(altheaVault));
        vm.stopBroadcast();

        // new instances of TroveManager and SortedTroves
//        vm.startBroadcast();
//        factory.deployNewInstance(
//            address(0), // debtToken. Will be set later
//            address(stabilityPool),
//            address(borrowerOperations),
//            address(sortedTroves),
//            address(troveManager),
//            address(liquidationManager)
//        );
//        vm.stopBroadcast();


    }

    function deployAltheaCore() internal {
        altheaCore = new AltheaCore(
            OWNER_ADDRESS,
            GUARDIAN_ADDRESS,
            address(0), // Price feed. Will be set later
            FEE_RECEIVER_ADDRESS
        );
    }

    function deployPriceFeed() internal {

        PriceFeed.OracleSetup[] memory emptyArray = new PriceFeed.OracleSetup[](0);

        priceFeed = new PriceFeed(
            address(altheaCore),
            ETH_PRICEFEED,
            emptyArray
        );
    }


    function deployFeeReceiver() internal {
        feeReceiver = new FeeReceiver(
            address(altheaCore)
        );
    }

    function deployInterimAdmin() internal {
        interimAdmin = new InterimAdmin(address(altheaCore));
    }

    function deployTheaToken() internal {
        uint8 sharedDecimals = 18;

        theaToken = new TheaToken(
            address(0), // Vault. Will be set later
            address(LAYERZERO_ENDPOINT),
            address(0), // TokenLocker. Will be set later
            sharedDecimals
        );
    }

    function deployTokenLocker() internal {

        uint256 lockToTokenRatio = 10 ** 18;
        //TODO: Frontend has to take this into account.
        //TODO: Can this actually have any other value?

        tokenLocker = new TokenLocker(
            address(altheaCore),
            ITheaToken(address(theaToken)),
            IIncentiveVoting(address(0)), // IncentiveVoting. Will be set later
            OWNER_ADDRESS, // should be deployment manager, but owner is used
            lockToTokenRatio
        );
    }

    function deploySortedTroves() internal {
        sortedTroves = new SortedTroves();
    }

    function deployFactory() internal {
        factory = new Factory(
            address(altheaCore),
            IDebtToken(address(0)), //debtToken. Will be set later
            IStabilityPool(address(0)), //stabilityPool. Will be set later
            IBorrowerOperations(address(0)), //borrowerOperations. Will be set later
            address(sortedTroves),
            address(0), // TroveManager. Will be set later
            ILiquidationManager(address(0)) // LiquidationManager. Will be set later
        );
    }

    function deployLiquidationManager() internal {

        uint gasCompensation = 200 * 10 ** 18;
        // in debt units, from Prisma

        liquidationManager = new LiquidationManager(
            address(altheaCore),
            IStabilityPool(address(0)), // StabilityPool. Will be set later
            IBorrowerOperations(address(0)), // borrowerOperations. Will be set later
            address(factory),
            gasCompensation
        );
    }

    function deployGasPool() internal {
        gasPool = new GasPool();
    }

    function deployBorrowerOperations() internal {
        // taken from Prisma
        uint minNetDebt = 180 * 10 ** 18;

        // in debt units, from Prisma
        uint gasCompensation = 200 * 10 ** 18;


        borrowerOperations = new BorrowerOperations(
            address(altheaCore),
            address(0), // DebtToken. Will be set later
            address(factory),
            minNetDebt,
            gasCompensation
        );
    }

    function deployDebtToken() internal {

        string memory name = "aUSD";
        string memory symbol = "aUSD";

        uint gasCompensation = 200 * 10 ** 18; //TODO: taken from PRISMA
        uint8 sharedDecimals = 18;

        debtToken = new DebtToken(
            name,
            symbol,
            address(0), // StabilityPool. Will be set later
            address(borrowerOperations),
            IAltheaCore(address(altheaCore)),
            address(LAYERZERO_ENDPOINT),
            address(factory),
            address(gasPool),
            gasCompensation,
            sharedDecimals
        );
    }

    function deployStabilityPool() internal {
        stabilityPool = new StabilityPool(
            address(altheaCore),
            IDebtToken(address(debtToken)),
            IAltheaVault(address(0)), //Vault. Will be set later
            address(factory),
            address(liquidationManager)
        );
    }


    function deployTroveManager() internal {

        uint gasCompensation = 200 * 10 ** 18; //TODO: taken from PRISMA

        troveManager = new TroveManager(
            address(altheaCore),
            address(gasPool),
            address(debtToken),
            address(borrowerOperations),
            address(0), // AltheaVault. Will be set later
            address(liquidationManager),
            gasCompensation
        );
    }

    function deployIncentiveVoting() internal {
        incentiveVoting = new IncentiveVoting(
            address(altheaCore),
            ITokenLocker(address(tokenLocker)),
            address(0) //AltheaVault. Will be set later
        );
    }

    function deployAltheaVault() internal {
        altheaVault = new AltheaVault(
            address(altheaCore),
            ITheaToken(address(theaToken)),
            ITokenLocker(address(tokenLocker)),
            IIncentiveVoting(address(incentiveVoting)),
            address(stabilityPool),
            OWNER_ADDRESS // TODO: should be deployment manager
        );
    }

}
