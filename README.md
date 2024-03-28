# Setup

Install the [Foundry](https://book.getfoundry.sh/) framework.
See the [installation guide](https://book.getfoundry.sh/getting-started/installation).

## Dependencies

### Default installation

Initialize the git submodules:

    git submodule update --init --recursive

### Manual installation (if default fails)

Install manually the following dependencies:

    forge install --no-commit openzeppelin/openzeppelin-contracts@v4.8.0
    forge install --no-commit layerzerolabs=LayerZero-Labs/solidity-examples@main
    forge install --no-commit foundry-rs/forge-std

# Compilation

Check all dependencies were installed correctly:

    forge build

# Scripts

Install npx:

    npm install -g npx

To run a javascript script, use `npx tsx [file]`:

    npx tsx script/prepareAllocations.js

This will generate a contract with the allocations for the token holders that can be used in the test suite and the deployment scripts.
