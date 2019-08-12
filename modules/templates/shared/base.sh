#!/usr/bin/env bash
set -e

echo "==> Base"

echo "==> libc6 issue workaround"
echo 'libc6 libraries/restart-without-asking boolean true' | sudo debconf-set-selections

function install_from_url {
  cd /tmp && {
    curl -sfLo "$${1}.zip" "$${2}"
    unzip -qq "$${1}.zip"
    sudo mv "$${1}" "/usr/local/bin/$${1}"
    sudo chmod +x "/usr/local/bin/$${1}"
    rm -rf "$${1}.zip"
  }
}

function ssh-apt {
  sudo DEBIAN_FRONTEND=noninteractive apt-get -yqq \
    --allow-downgrades \
    --allow-remove-essential \
    --allow-change-held-packages \
    -o Dpkg::Use-Pty=0 \
    -o Dpkg::Options::="--force-confdef" \
    -o Dpkg::Options::="--force-confold" \
    "$@"
}

echo "--> Adding helper for IP retrieval"
sudo tee /etc/profile.d/ips.sh > /dev/null <<EOF
function private_ip {
  curl -H "Metadata-Flavor: Google" -s http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip
}

function public_ip {
  curl -H "Metadata-Flavor: Google" http://metadata/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip
}
EOF
source /etc/profile.d/ips.sh

echo "--> Updating apt-cache"
ssh-apt update

echo "--> Adding trusted root CA"
sudo tee /usr/local/share/ca-certificates/01-me.crt > /dev/null <<EOF
${me_ca}
EOF
sudo update-ca-certificates &>/dev/null

echo "--> Adding my certificates"
sudo tee /etc/ssl/certs/me.crt > /dev/null <<EOF
${me_cert}
EOF
sudo tee /etc/ssl/certs/me.key > /dev/null <<EOF
${me_key}
EOF

echo "--> Installing common dependencies"
ssh-apt install \
  build-essential \
  curl \
  emacs \
  git \
  jq \
  tmux \
  unzip \
  vim \
  wget \
  tree \
  python3-pip \
  ruby-full \
  npm \
  &>/dev/null

echo "--> Installing git secrets"
git clone https://github.com/awslabs/git-secrets
cd git-secrets
sudo make install
cd -
rm -rf git-secrets

echo "--> Disabling checkpoint"
sudo tee /etc/profile.d/checkpoint.sh > /dev/null <<"EOF"
export CHECKPOINT_DISABLE=1
EOF
source /etc/profile.d/checkpoint.sh

echo "--> Installing dnsmasq"
sudo apt-get install -y -q dnsmasq

echo "--> Configuring DNSmasq"
sudo bash -c "cat >/etc/dnsmasq.d/10-consul" << EOF
server=/consul/127.0.0.1#8600
EOF

echo "==> Base is done!"
