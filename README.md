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
    forge install --no-commit layerzerolabs=LayerZero-Labs/solidity-examples@3d3a09f14a1d05479a5a397d5f646fe3a455c00c

# Compilation

Check all dependencies were installed correctly:

    forge build
