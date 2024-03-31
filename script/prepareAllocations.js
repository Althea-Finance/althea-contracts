import fs from "fs";
import path from "path";

// Define the path for the allocations JSON and the output Solidity contract
const allocationsFilePath = path.join(__dirname, "./data/allocations.json");
const outputSolFilePath = path.join(__dirname, "./generatedAllocations.sol");

const allocations = JSON.parse(fs.readFileSync(allocationsFilePath, "utf8"));

let contractContent = `// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "src/token/AllocationVesting.sol";

contract GeneratedAllocations {
   \n
   `;

const totalAllocations = Object.values(allocations).reduce(
  (acc, allocationEntries) => acc + allocationEntries.length,
  0
);
console.log(`Total allocations found: ${totalAllocations}`);

contractContent += `AllocationVesting.LinearVesting[] public allAllocations = new AllocationVesting.LinearVesting[](${totalAllocations});\n\n`;

contractContent += '    constructor() {\n'

Object.entries(allocations).forEach(([allocationType, allocationEntries], i1) => {
  contractContent += `        // ${allocationType} allocations\n`;
  allocationEntries.forEach((allocation, i2) => {
    contractContent += `        allAllocations.push(AllocationVesting.LinearVesting(${allocation.address}, ${allocation.allocationAtEndDate}, ${allocation.allocationAtStartDate}, ${allocation.startDate}, ${allocation.endDate}))`;
    // if (i1 === Object.entries(allocations).length - 1 && i2 === Object.entries(allocationEntries).length - 1) {
    //   contractContent += "\n";
    // } else {
      contractContent += ";\n";
    // }
  });
  contractContent += `   \n`;
});

contractContent += `    }\n}\n`;

// Write the Solidity contract content to a .sol file
fs.writeFileSync(outputSolFilePath, contractContent);
