#!/usr/bin/env bash
# ----------------------------------------------------------------------
# Aztec alpha-testnet one-click installer for Ubuntu – fixed 2025-05-16
# ----------------------------------------------------------------------
set -euo pipefail

### ─── ENSURE RUNTIME VARS ARE DEFINED (prevents nounset errors) ──────
L1_RPC_URL=${L1_RPC_URL-}
L1_CONSENSUS_URL=${L1_CONSENSUS_URL-}
VALIDATOR_PRIVATE_KEY=${VALIDATOR_PRIVATE_KEY-}
COINBASE_ADDRESS=${COINBASE_ADDRESS-}

prompt_or_env() {
  # $1 = bash variable name   | $2 = prompt message
  local var="$1" prompt="$2" val
  # Get current value (if any) without triggering set -u
  val="$(eval "printf '%s' \"\${$var-}\"")"
  while [[ -z $val ]]; do
    read -rp "$prompt" val
  done
  printf -v "$var" '%s' "$val"
}

### ─── COLOUR CONSTANTS ────────────────────────────────────────────────
CYAN='\033[0;36m'      LIGHTBLUE='\033[1;34m'
RED='\033[1;31m'       GREEN='\033[1;32m'
PURPLE='\033[1;35m'    BOLD='\033[1m'     RESET='\033[0m'

### ─── ROOT / SUDO HANDLING ────────────────────────────────────────────
if [[ $EUID -eq 0 ]]; then SUDO=''; else SUDO='sudo'; fi

### ─── BASE TOOLS ──────────────────────────────────────────────────────
echo -e "\n${CYAN}${BOLD}---- UPDATING APT & CORE UTILITIES ----${RESET}\n"
$SUDO apt-get update -y
$SUDO apt-get install -y \
  curl jq lsb-release ca-certificates gnupg screen software-properties-common

### ─── DOCKER ENGINE (NOT DESKTOP) ─────────────────────────────────────
echo -e "\n${CYAN}${BOLD}---- CHECKING DOCKER ENGINE ----${RESET}\n"
if ! command -v docker &>/dev/null; then
  echo -e "${LIGHTBLUE}${BOLD}Docker not found. Installing Docker Engine...${RESET}"
  $SUDO install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
    $SUDO gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  $SUDO chmod a+r /etc/apt/keyrings/docker.gpg

  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
    https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
    $SUDO tee /etc/apt/sources.list.d/docker.list >/dev/null

  $SUDO apt-get update -y
  $SUDO apt-get install -y docker-ce docker-ce-cli containerd.io \
    docker-buildx-plugin docker-compose-plugin
  $SUDO systemctl enable --now docker

  # Let non-root users run docker
  if [[ $EUID -ne 0 ]]; then
    $SUDO usermod -aG docker "$USER"
    echo -e "\n${GREEN}${BOLD}Added ${USER} to the docker group."
    echo -e "Log out & back in (or run \`newgrp docker\`) to use Docker without sudo.${RESET}"
  fi
fi

echo -n "Waiting for Docker daemon"
until docker info &>/dev/null; do printf '.'; sleep 2; done
echo -e " ${GREEN}${BOLD}Docker is running.${RESET}"

### ─── AZTEC TOOLKIT ───────────────────────────────────────────────────
AZTEC_PATH="$HOME/.aztec"
BIN_PATH="$AZTEC_PATH/bin"
mkdir -p "$BIN_PATH"

echo -e "\n${CYAN}${BOLD}---- INSTALLING AZTEC TOOLKIT ----${RESET}\n"
curl -fsSL https://install.aztec.network | bash

# Add Aztec CLI to PATH for this and future sessions
if ! command -v aztec &>/dev/null; then
  export PATH="$PATH:$BIN_PATH"
  if ! grep -q ".aztec/bin" "$HOME/.bashrc"; then
    echo 'export PATH="$PATH:$HOME/.aztec/bin"' >> "$HOME/.bashrc"
    echo -e "${GREEN}${BOLD}Aztec CLI added to PATH via ~/.bashrc${RESET}"
  fi
fi

command -v aztec &>/dev/null || {
  echo -e "${RED}${BOLD}ERROR: Aztec installation failed. Exiting.${RESET}"
  exit 1
}

echo -e "\n${CYAN}${BOLD}---- UPDATING AZTEC TO ALPHA-TESTNET ----${RESET}\n"
aztec-up alpha-testnet

### ─── NODE CONFIG PROMPTS ────────────────────────────────────────────
IP=$(curl -s https://api.ipify.org || true)
[[ -z $IP ]] && read -rp "Could not auto-detect IP. Enter your machine's public IP address: " IP

echo -e "${LIGHTBLUE}${BOLD}Get a Sepolia RPC URL at${RESET} ${PURPLE}https://dashboard.alchemy.com/apps${RESET}"
prompt_or_env L1_RPC_URL        "Enter your Sepolia Ethereum RPC URL: "

echo -e "${LIGHTBLUE}${BOLD}Get a Beacon RPC URL at${RESET} ${PURPLE}https://chainstack.com/global-nodes${RESET}"
prompt_or_env L1_CONSENSUS_URL  "Enter your Sepolia Beacon URL: "

echo -e "${LIGHTBLUE}${BOLD}Create & fund a new Sepolia wallet, then paste the private key.${RESET}"
prompt_or_env VALIDATOR_PRIVATE_KEY "Enter your wallet private key (0x…): "
prompt_or_env COINBASE_ADDRESS      "Enter the wallet address (0x…): "

### ─── PORT 8080 SANITY CHECK ─────────────────────────────────────────
echo -e "\n${CYAN}${BOLD}---- CHECKING PORT 8080 ----${RESET}\n"
if ss -ltn sport = :8080 | grep -q LISTEN; then
  echo -e "${LIGHTBLUE}${BOLD}Port 8080 in use. Terminating process...${RESET}"
  $SUDO fuser -k 8080/tcp || true
  sleep 1
  echo -e "${GREEN}${BOLD}Port 8080 freed.${RESET}"
else
  echo -e "${GREEN}${BOLD}Port 8080 is available.${RESET}"
fi

### ─── STARTER SCRIPT & SCREEN SESSION ────────────────────────────────
START_SCRIPT="$HOME/start_aztec_node.sh"
cat > "$START_SCRIPT" <<EOF
#!/usr/bin/env bash
export PATH="\$PATH:$BIN_PATH"

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
chmod +x "$START_SCRIPT"

command -v screen &>/dev/null || $SUDO apt-get install -y screen
screen -dmS aztec-node "$START_SCRIPT"

echo -e "\n${GREEN}${BOLD}🟢 Aztec node started in detached screen session 'aztec-node'.${RESET}"
echo -e "${LIGHTBLUE}Attach anytime with:  ${BOLD}screen -r aztec-node${RESET}"
