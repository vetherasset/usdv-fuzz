# usdv-fuzz

```shell
git clone --recursive git@github.com:vetherasset/usdv-fuzz.git

npm i

# compile
dapp build
# test
dapp test -v --fuz-runs 100

# flatten
hevm flatten --source-file src/tokens/USDV.sol > tmp/flat.sol

# slither
pip3 install solc-select
solc-select install 0.8.9
solc-select use 0.8.9

pip3 install slither-analyzer
slither tmp/flat.sol
slither tmp/flat.sol --print human-summary
slither tmp/flat.sol --print vars-and-auth
```
