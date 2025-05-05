#!/usr/bin/env bash

CYAN='\033[0;36m'
LIGHTBLUE='\033[1;34m'
RED='\033[1;31m'
GREEN='\033[1;32m'
PURPLE='\033[1;35m'
BOLD='\033[1m'
RESET='\033[0m'

# install Homebrew if missing
if ! command -v brew &>/dev/null; then
  echo -e "${LIGHTBLUE}${BOLD}Homebrew not found. Installing Homebrew...${RESET}"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  echo -e "${GREEN}${BOLD}Homebrew installed!${RESET}"
  # ensure brew is in PATH for this session
  eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null || true
fi

echo -e "\n${CYAN}${BOLD}---- CHECKING DOCKER DESKTOP ----${RESET}\n"
if ! brew list --cask docker &>/dev/null; then
  echo -e "${LIGHTBLUE}${BOLD}Docker Desktop not found. Installing Docker Desktop...${RESET}"
  brew install --cask docker
  echo -e "${GREEN}${BOLD}Docker Desktop installed!${RESET}"
fi

echo -e "${LIGHTBLUE}${BOLD}Launching Docker...${RESET}"
open -a Docker

# wait for Docker daemon
echo -n "Waiting for Docker to start"
until docker info &>/dev/null; do
  echo -n "."
  sleep 2
done
echo -e "\n${GREEN}${BOLD}Docker is running.${RESET}"

echo -e "\n${CYAN}${BOLD}---- INSTALLING DEPENDENCIES ----${RESET}\n"
brew update
brew install curl jq

# clean any old alpha-testnet data
[ -d "$HOME/.aztec/alpha-testnet" ] && rm -rf "$HOME/.aztec/alpha-testnet"

AZTEC_PATH="$HOME/.aztec"
BIN_PATH="$AZTEC_PATH/bin"
mkdir -p "$BIN_PATH"

echo -e "\n${CYAN}${BOLD}---- INSTALLING AZTEC TOOLKIT ----${RESET}\n"
curl -fsSL https://install.aztec.network | bash

# ensure aztec CLI is in PATH
if ! command -v aztec &>/dev/null; then
  echo -e "${LIGHTBLUE}${BOLD}Aztec CLI not found in PATH. Adding for this session...${RESET}"
  export PATH="$PATH:$HOME/.aztec/bin"
  if ! grep -Fxq 'export PATH=$PATH:$HOME/.aztec/bin' "$HOME/.zprofile"; then
    echo 'export PATH=$PATH:$HOME/.aztec/bin' >> "$HOME/.zprofile"
    echo -e "${GREEN}${BOLD}Added Aztec to PATH in .zprofile${RESET}"
  fi
  # reload
  source "$HOME/.zprofile"
fi

if ! command -v aztec &>/dev/null; then
  echo -e "${RED}${BOLD}ERROR: Aztec installation failed. Please check the logs above.${RESET}"
  exit 1
fi

echo -e "\n${CYAN}${BOLD}---- UPDATING AZTEC TO ALPHA-TESTNET ----${RESET}\n"
aztec-up alpha-testnet

echo -e "\n${CYAN}${BOLD}---- CONFIGURING NODE ----${RESET}\n"
# auto-detect public IP
IP=$(curl -s https://api.ipify.org || curl -s http://checkip.amazonaws.com || curl -s https://ifconfig.me)
if [ -z "$IP" ]; then
  echo -e "${LIGHTBLUE}${BOLD}Could not auto-detect IP.${RESET}"
  read -p "Enter your machine's public IP address: " IP
fi

echo -e "${LIGHTBLUE}${BOLD}Visit ${PURPLE}https://dashboard.alchemy.com/apps${RESET}${LIGHTBLUE}${BOLD} or ${PURPLE}https://developer.metamask.io/register${RESET}${LIGHTBLUE}${BOLD} to get a Sepolia RPC URL.${RESET}"
read -p "Enter Your Sepolia Ethereum RPC URL: " L1_RPC_URL

echo -e "${LIGHTBLUE}${BOLD}Visit ${PURPLE}https://chainstack.com/global-nodes${RESET}${LIGHTBLUE}${BOLD} to get a beacon RPC URL.${RESET}"
read -p "Enter Your Sepolia Ethereum BEACON URL: " L1_CONSENSUS_URL

echo -e "${LIGHTBLUE}${BOLD}Create a new EVM wallet, fund it via Sepolia Faucet, then provide its private key.${RESET}"
read -p "Enter your evm wallet private key (0x...): " VALIDATOR_PRIVATE_KEY
read -p "Enter the wallet address associated with that key: " COINBASE_ADDRESS

echo -e "\n${CYAN}${BOLD}---- CHECKING PORT 8080 ----${RESET}\n"
if lsof -i TCP:8080 &>/dev/null; then
  echo -e "${LIGHTBLUE}${BOLD}Port 8080 in use. Killing process...${RESET}"
  lsof -ti TCP:8080 | xargs kill -9
  sleep 1
  echo -e "${GREEN}${BOLD}Port 8080 freed.${RESET}"
else
  echo -e "${GREEN}${BOLD}Port 8080 is available.${RESET}"
fi

echo -e "\n${CYAN}${BOLD}---- STARTING AZTEC NODE ----${RESET}\n"
cat > "$HOME/start_aztec_node.sh" <<EOL
#!/usr/bin/env bash
export PATH=\$PATH:\$HOME/.aztec/bin
aztec start --node --archiver --sequencer \\
  --network alpha-testnet \\
  --port 8080 \\
  --l1-rpc-urls $L1_RPC_URL \\
  --l1-consensus-host-urls $L1_CONSENSUS_URL \\
  --sequencer.validatorPrivateKey $VALIDATOR_PRIVATE_KEY \\
  --sequencer.coinbase $COINBASE_ADDRESS \\
  --p2p.p2pIp $IP \\
  --p2p.maxTxPoolSize 1000000000
EOL

chmod +x "$HOME/start_aztec_node.sh"
screen -dmS aztec-node "$HOME/start_aztec_node.sh"

echo -e "${GREEN}${BOLD}🟢 Aztec node started in a detached screen session (name: aztec-node).${RESET}\n"
