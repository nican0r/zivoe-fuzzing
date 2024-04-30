# Report For Zivoe Fuzzing/Invariant Testing

Throughout the course of the Zivoe competition on Sherlock a fuzzing/invariant testing campaign was conducted using Echidna and a scaffolding provided by Recon. The properties used were identified from the documentation and natspec for the repo. 

The primary contract of focus due to limited time constraint was `ZivoeITO` , although properties were also defined for the `ZivoeDAO`, `ZivoeRewards`, `ZivoeRewardsVesting`, `ZivoeToken`, `ZivoeTranches` and `ZivoeYDL` contracts in scope. During the engagement Echidna executed 100,000+ calls on the invariant/fuzzing suite and achieved coverage on all public functions in the  `ZivoeITO` contract. 

Recommendation: to provide a greater guarantee that the tested properties hold for all possible values the fuzzer should be run for an extended period of time (24-48hours) with the “time since new coverage” > 12 hours generally being a good rule of thumb that sufficient depth coverage has been achieved. Additionally, including tests for system properties in other contracts in the system is recommended. Including functions from these contracts into the existing `TargetFunctions` contract would also allow end-to-end invariant testing, more accurately modeling the system lifecycle.

The following properties were defined during the competition. 

- ✅ - tested
- 🚧 - started testing (incomplete)
- ❌ - not tested

### ZivoeITO

**Note: currently testing these where caller is also the depositor, could add in extra randomness by testing with caller not as depositor 

| Property | Description | Implemented | Tested | Passing |
| --- | --- | --- | --- | --- |
| ZTO-01 | claimAirdrop can only be called after ITO concludes | ✅ | ✅ | ✅ |
| ZTO-02 | $ZVE only gets vested once $zJTT and $zSTT are claimed | ✅ | ✅ | ❌ - could potentially be issue with the test, needs to be debugged |
| ZTO-03 | Deposits are always transferred to ZivoeDAO when migrateDeposits is called | ✅ | ✅ | ✅ |
| ZTO-04 | $zJTT and $zSTT are always minted after making a nonzero deposit | ✅ | ✅ | ✅ |
| ZTO-05 | $zJTT and $zSTT can’t be minted for free | ✅ | ✅ | ✅ |
| ZTO-06 | depositJunior and depositSenior can only be called during the ITO | ✅ | ✅ | ✅ |
| ZTO-07 | max ZVE amount set aside for ITO can’t be surpassed | ❌ | ❌ | ❌ |
| ZTO-08 | depositJunior and depositSenior can’t be called after migration | ✅ | ✅ | ✅ |

## **Note: All properties below were defined but not tested due to time constraints (recommend implmenting tests for these)

### ZivoeDAO

| Property | Description | Tested |
| --- | --- | --- |
| ZD-01 | only whitelisted lockers can have assets pushed to them | ❌ |
| ZD-02 | whitelist must not be enforced for pulling assets from a locker | ❌ |
| ZD-03 | must be capable of holding ERC721s and ERC1155s | ❌ |
| ZD-04 | calling pull pulls the entire balance of the locker | ❌ |

### ZivoeRewards

| Property | Description | Tested |
| --- | --- | --- |
| ZR-01 | User can only claim yield for their staked tokens | ❌ |
| ZR-02 | Stakers can’t claim more than vesting schedule permits | ❌ |
| ZR-03 | Users can always unstake after vesting schedule period passes | ❌ |
| ZR-04 | Users can always stake after ITO? | ❌ |
| ZR-05 | Rewards are vested linearly (should this slope not change?) | ❌ |
| ZR-06 | Multiple assets can be added as rewardToken for distribution | ❌ |
| ZR-07 | Users can always stake/withdraw nonzero amounts from ZivoeRewards | ❌ |

### ZivoRewardsVesting

| Property | Description | Tested |
| --- | --- | --- |
| ZRV-01 | vesting schedules can always be created for vestingToken | ❌ |
| ZRV-02 | vested tokens can always be unstaked | ❌ |
| ZRV-03 | yield can always be claimed after vesting period has passed | ❌ |

### ZivoeToken

| Property | Description | Tested |
| --- | --- | --- |
| ZVE-01 | totalSupply never exceeds 25 million | ❌ |
| ZVE-02 | holders can always vote  | ❌ |

### ZivoeTranches

| Property | Description | Tested |
| --- | --- | --- |
| ZT-01 | permissioned by $zJTT and $zSTT to call mint() | ❌ |
| ZT-02 | only whitelisted stablecoins can be used for liquidity  | ❌ |
| ZT-03 | depositJunior/depositSenior can only be called after ZivoeITO completes   | ❌ |

### ZivoeYDL

| Property | Description | Tested |
| --- | --- | --- |
| YDL-01 | yield can’t be withdrawn between distribution periods (< 30 days) | ❌ |

### General

| Property | Description | Tested |
| --- | --- | --- |
| G-01 | tranche tokens can only be minted via ZivoeTranches after ITO completes | ❌ |
| G-02 | Only lockers can increase/decrease defaults in ZivoeGlobals | ❌ |