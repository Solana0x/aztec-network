# aztec-network
Automated Script for Ubuntu / Windows / MacOs users to Run aztec-network node and  Get  🧑‍🎓 Apprentice Role

Aztec is building a decentralized, privacy-focused network and the sequencer node is a key part of it. Running a sequencer helps produce and propose blocks using regular consumer hardware. This guide will walk you through setting one up on the testnet.

Note : There’s no official confirmation of any rewards, airdrop, or incentives. This is purely for learning, contribution and being early in a cutting-edge privacy project.

## 💻 System Requirements

| Component      | Specification               |
|----------------|-----------------------------|
| CPU            | 4-core Processor            |
| RAM            | 8 GiB                       |
| Storage        | 54 GB SSD                   |
| Internet Speed | 25 Mbps Upload / Download   |

## Requirements

- Ethereum Sepolia RPC - [INFURA RPC](https://developer.metamask.io/) , [QuickNode](https://dashboard.quicknode.com/)
- Ethereum Beacon Sepolia RPC - [chainstack](https://console.chainstack.com/nodes)
- Docker , nodejs , homebrew etc

## STEPS

- Install the required code as per your system either via `git clone https://github.com/Solana0x/aztec-network.git` or if you have curl installed then via `curl -fsSL https://raw.githubusercontent.com/Solana0x/aztec-network/main/linux.sh | bash` For Linux/ windows and `curl -fsSL https://raw.githubusercontent.com/Solana0x/aztec-network/main/macos.sh | bash` for the macos users ...
- Once installation is done then execute the script via `bash macos.sh` or `bash linux.sh` as per your system.
- Once Script starts running fill the `Sepolia RPC` and `Beacon Sepolia RPC` , evm `Pvt key` , `public key` and fund your wallet with some Sepolia testnet ETH.
- Once Script is running in other screen you just need to run this command after 10-20 Mins to get your Latest Block and proof to get the role !!

# Command - 

```
BLOCK=$(curl -s -X POST -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"node_getL2Tips","params":[],"id":67}' \
  http://localhost:8080 | jq -r ".result.proven.number")

if [[ -z "$BLOCK" || "$BLOCK" == "null" ]]; then
  echo "❌ Failed to get block number"
else
  echo "✅ Block Number: $BLOCK"
  echo "🔗 Sync Proof:"
  curl -s -X POST -H 'Content-Type: application/json' \
    -d "{\"jsonrpc\":\"2.0\",\"method\":\"node_getArchiveSiblingPath\",\"params\":[\"$BLOCK\",\"$BLOCK\"],\"id\":67}" \
    http://localhost:8080 | jq -r ".result"
fi 
```
Now copy and paste the following in Discord [Operators | Start Here] :

`/operator start your-address: block-number: proof: `

**Just replace:**
`your-address` → your operator Ethereum address
`block-number` → the block number shown as ✅ Block Number
`proof:` → the sync proof array shown after 🔗 Sync Proof:

# Discord Link - [https://discord.gg/aztec](https://discord.gg/aztec)



## FOR ANY KIND OF HELP CONTACT : ` 0xphatom ` on Discord  https://discord.com/users/979641024215416842

# Socials 

# Telegram - [https://t.me/phantomoalpha](https://t.me/phantomoalpha)
# Discord - [https://discord.gg/pGJSPtp9zz](https://discord.gg/pGJSPtp9zz)


