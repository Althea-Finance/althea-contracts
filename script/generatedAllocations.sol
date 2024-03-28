// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "src/token/AllocationVesting.sol";

contract GeneratedAllocations {
    AllocationVesting.LinearVesting[] allAllocations;

    constructor() {
        // EarlySupporters allocations
        allAllocations.push(
            AllocationVesting.LinearVesting(
                0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266, 625000, 125000, 1718208000, 1725840000
            )
        );
        allAllocations.push(
            AllocationVesting.LinearVesting(
                0x70997970C51812dc3A010C7d01b50e0d17dc79C8, 625000, 125000, 1718208000, 1725840000
            )
        );
        allAllocations.push(
            AllocationVesting.LinearVesting(
                0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC, 625000, 125000, 1718208000, 1725840000
            )
        );
        allAllocations.push(
            AllocationVesting.LinearVesting(
                0x90F79bf6EB2c4f870365E785982E1f101E93b906, 625000, 125000, 1718208000, 1725840000
            )
        );

        // IDO allocations
        allAllocations.push(
            AllocationVesting.LinearVesting(
                0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65, 3750000, 1500000, 1718208000, 1721088000
            )
        );
        allAllocations.push(
            AllocationVesting.LinearVesting(
                0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc, 3750000, 1500000, 1718208000, 1721088000
            )
        );
        allAllocations.push(
            AllocationVesting.LinearVesting(
                0x976EA74026E726554dB657fA54763abd0C3a0aa9, 3750000, 1500000, 1718208000, 1721088000
            )
        );
        allAllocations.push(
            AllocationVesting.LinearVesting(
                0x14dC79964da2C08b23698B3D3cc7Ca32193d9955, 3750000, 1500000, 1718208000, 1721088000
            )
        );

        // CoreContributors allocations
        allAllocations.push(
            AllocationVesting.LinearVesting(
                0x23618E81e3f5a4B2a83D6431a60359aa88b7c025, 5000000, 0, 1721539200, 1743072000
            )
        );
        allAllocations.push(
            AllocationVesting.LinearVesting(
                0xa0Ee7A142d267C1f36714E4a8F75612F20a79720, 5000000, 0, 1721539200, 1743072000
            )
        );
        allAllocations.push(
            AllocationVesting.LinearVesting(
                0xBcd4042DE499D14e55001CcbB24a551F3b954096, 5000000, 0, 1721539200, 1743072000
            )
        );
        allAllocations.push(
            AllocationVesting.LinearVesting(
                0x59b670e9fA9D0A427751Af201D676719a970857b, 5000000, 0, 1721539200, 1743072000
            )
        );

        // Advisors allocations
        allAllocations.push(
            AllocationVesting.LinearVesting(
                0x9E56625509c2F60Adf734258B7BcEdDbE7955DbE, 625000, 0, 1719936000, 1743072000
            )
        );
        allAllocations.push(
            AllocationVesting.LinearVesting(
                0x26064a2E2b568D9A6D01B93D039D1da9Cf2A58CD, 625000, 0, 1719936000, 1743072000
            )
        );
        allAllocations.push(
            AllocationVesting.LinearVesting(
                0xE037EC8EC9ec423826750853899394dE7F024fee, 625000, 0, 1719936000, 1743072000
            )
        );
        allAllocations.push(
            AllocationVesting.LinearVesting(
                0xE36Ea790bc9d7AB70C55260C66D52b1eca985f84, 625000, 0, 1719936000, 1743072000
            )
        );

        // Treasury allocations
        allAllocations.push(
            AllocationVesting.LinearVesting(
                0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2, 2500000, 0, 1723075200, 1743072000
            )
        );
        allAllocations.push(
            AllocationVesting.LinearVesting(
                0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db, 2500000, 0, 1723075200, 1743072000
            )
        );
        allAllocations.push(
            AllocationVesting.LinearVesting(
                0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB, 2500000, 0, 1723075200, 1743072000
            )
        );
        allAllocations.push(
            AllocationVesting.LinearVesting(
                0x617F2E2fD72FD9D5503197092aC168c91465E7f2, 2500000, 0, 1723075200, 1743072000
            )
        );
    }
}
