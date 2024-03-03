![Web_Official_Dark](https://user-images.githubusercontent.com/26582141/201743461-87df24c4-80fd-4abe-baf8-7cf6a85e0fba.png)

# Zivoe Unit/Fuzz Testing (_zivoe-core-testing_)

[![Docs](https://img.shields.io/badge/docs-%F0%9F%93%84-blue)](https://docs.zivoe.com)

This repository contains unit and fuzz testing for Zivoe v1 smart contracts.

## Setup & Environment

Install [foundry-rs](https://github.com/foundry-rs/foundry).

Generate a main-net RPC-URL from [Infura](https://www.infura.io/).

```
git clone https://github.com/Zivoe/zivoe-core-testing
git submodule update --init --recursive
forge test --rpc-url <RPC_URL_MAINNET>
```
