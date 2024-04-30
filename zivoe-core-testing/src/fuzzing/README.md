
### Invariant Fuzzing Suite

This fuzzing suite has been built with [Recon](https://getrecon.xyz/) to enable running Foundry + Echidna + Medusa invariant tests with debugging broken properties using the CryticToFoundry contract. To learn more about the Recon harness structure see [this](https://allthingsfuzzy.substack.com/p/introducing-recon-invariant-testing?r=34r2zr) post. 

Since this repo requires fork testing which isn't currently supported by Medusa, the invariant tests were run using Echidna. 

The following command can be used to run Echidna:

```bash
ECHIDNA_RPC_URL=${RPC_URL} ECHIDNA_RPC_BLOCK=BLOCK_NUMBER echidna . --contract CryticTester --config echidna.yaml
```

The current Echidna configuration uses Foundry as its build system, but executes `forge clean` by default during every new run, causing it to recompile all contracts and delete any existing build artifacts. To prevent having to recompile everything (~2 minutes each time) you can use the `cryticArgs: ["--foundry-compile-all", “--skip-clean”]` config in echidna.yaml if you have already run echidna at least once. 