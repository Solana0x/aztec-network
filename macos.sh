#!/usr/bin/env bash
# macOS Aztec alpha‑testnet installer
# ------------------------------------
CYAN='\033[0;36m'; LIGHTBLUE='\033[1;34m'; RED='\033[1;31m'
GREEN='\033[1;32m'; PURPLE='\033[1;35m'; BOLD='\033[1m'; RESET='\033[0m'

# ── 1. Homebrew ───────────────────────────────────────────────────────
if ! command -v brew &>/dev/null; then
  echo -e "${LIGHTBLUE}${BOLD}Homebrew not found → installing...${RESET}"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  echo -e "${GREEN}${BOLD}Homebrew installed.${RESET}"
  eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null || true   # add brew to PATH
fi

# ── 2. Docker Desktop ─────────────────────────────────────────────────
echo -e "\n${CYAN}${BOLD}---- CHECKING DOCKER DESKTOP ----${RESET}\n"
if ! brew list --cask docker &>/dev/null; then
  echo -e "${LIGHTBLUE}${BOLD}Docker Desktop not found → installing...${RESET}"
  brew install --cask docker
  echo -e "${GREEN}${BOLD}Docker Desktop installed.${RESET}"
fi
echo -e "${LIGHTBLUE}${BOLD}Launching Docker...${RESET}"
open -a Docker
echo -n "Waiting for Docker to start"; until docker info &>/dev/null; do echo -n "."; sleep 2; done
echo -e " ${GREEN}${BOLD}Docker is running.${RESET}"

# ── 3. CLI dependencies (curl, jq, *screen*) ──────────────────────────
echo -e "\n${CYAN}${BOLD}---- INSTALLING DEPENDENCIES ----${RESET}\n"
brew update
# brew install is idempotent – safe to call even if already installed
brew install curl jq screen

# ── 4. House‑cleaning & Aztec CLI ─────────────────────────────────────
[ -d "$HOME/.aztec/alpha-testnet" ] && rm -rf "$HOME/.aztec/alpha-testnet"
AZTEC_PATH="$HOME/.aztec"; BIN_PATH="$AZTEC_PATH/bin"; mkdir -p "$BIN_PATH"

echo -e "\n${CYAN}${BOLD}---- INSTALLING AZTEC TOOLKIT ----${RESET}\n"
curl -fsSL https://install.aztec.network | bash

# Add Aztec CLI to PATH if needed
if ! command -v aztec &>/dev/null; then
  export PATH="$PATH:$HOME/.aztec/bin"
  if ! grep -Fxq 'export PATH=$PATH:$HOME/.aztec/bin' "$HOME/.zprofile"; then
    echo 'export PATH=$PATH:$HOME/.aztec/bin' >> "$HOME/.zprofile"
    echo -e "${GREEN}${BOLD}Aztec CLI added to PATH via ~/.zprofile${RESET}"
  fi
  source "$HOME/.zprofile"
fi
command -v aztec &>/dev/null || { echo -e "${RED}${BOLD}Aztec install failed!${RESET}"; exit 1; }

echo -e "\n${CYAN}${BOLD}---- UPDATING AZTEC TO ALPHA‑TESTNET ----${RESET}\n"
aztec-up alpha-testnet

# ── 5. Gather user‑specific settings ──────────────────────────────────
echo -e "\n${CYAN}${BOLD}---- CONFIGURING NODE ----${RESET}\n"
IP=$(curl -s https://api.ipify.org || curl -s https://ifconfig.me || true)
[[ -z $IP ]] && read -rp "Public IP not detected – enter manually: " IP

echo -e "${LIGHTBLUE}${BOLD}Get a Sepolia RPC URL at ${PURPLE}https://dashboard.alchemy.com/apps${RESET}"
read -rp "Enter Sepolia Ethereum RPC URL: " L1_RPC_URL
echo -e "${LIGHTBLUE}${BOLD}Get a Beacon RPC URL at ${PURPLE}https://chainstack.com/global-nodes${RESET}"
read -rp "Enter Sepolia Beacon URL: " L1_CONSENSUS_URL
echo -e "${LIGHTBLUE}${BOLD}Provide a funded Sepolia wallet private key.${RESET}"
read -rp "Wallet private key (0x…): " VALIDATOR_PRIVATE_KEY
read -rp "Wallet address      (0x…): " COINBASE_ADDRESS

# ── 6. Ensure port 8080 is free ───────────────────────────────────────
echo -e "\n${CYAN}${BOLD}---- CHECKING PORT 8080 ----${RESET}\n"
if lsof -i TCP:8080 &>/dev/null; then
  echo -e "${LIGHTBLUE}${BOLD}Port 8080 busy → killing process...${RESET}"
  lsof -ti TCP:8080 | xargs kill -9
  sleep 1
fi
echo -e "${GREEN}${BOLD}Port 8080 ready.${RESET}"

# ── 7. Create launcher & start in *screen* ────────────────────────────
LAUNCHER="$HOME/start_aztec_node.sh"
cat > "$LAUNCHER" <<EOF
#!/usr/bin/env bash
export PATH="\$PATH:$HOME/.aztec/bin"
aztec start --node --archiver --sequencer \\
  --network alpha-testnet \\
  --port 8080 \\
  --l1-rpc-urls "$L1_RPC_URL" \\
  --l1-consensus-host-urls "$L1_CONSENSUS_URL" \\
  --sequencer.validatorPrivateKey "$VALIDATOR_PRIVATE_KEY" \\
  --sequencer.coinbase "$COINBASE_ADDRESS" \\
  --p2p.p2pIp "$IP" \\
  --p2p.maxTxPoolSize 1000000000
EOF
chmod +x "$LAUNCHER"

screen -dmS aztec-node "$LAUNCHER"
echo -e "\n${GREEN}${BOLD}🟢 Aztec node is running in detached screen session 'aztec-node'.${RESET}"
echo -e "${LIGHTBLUE}Re‑attach with: ${BOLD}screen -r aztec-node${RESET}\n"
