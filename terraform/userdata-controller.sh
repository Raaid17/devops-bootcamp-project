#!/bin/bash
set -uxo pipefail

# Everything Ansible needs to drive the two targets over SSM.
#
# Ansible comes from a pinned virtualenv, NOT apt: Ubuntu 24.04's apt package is
# ansible-core 2.16, which is end-of-life upstream (July 2025) and too old for
# amazon.aws 11 / community.docker 5 (both need >= 2.17). The <2.22 ceiling is
# because prometheus.prometheus supports ansible-core up to 2.21.x only.
#
# No `set -e`: a private-subnet instance can win the race against its own NAT
# route, so network steps wait and retry instead of aborting the whole script.

exec > >(tee -a /var/log/controller-bootstrap.log) 2>&1

ANSIBLE_CORE_SPEC='ansible-core>=2.21,<2.22'
REPO_URL='https://github.com/Raaid17/devops-bootcamp-project.git'

# Wait for egress through the NAT gateway before touching the network.
for i in $(seq 1 60); do
  if getent hosts archive.ubuntu.com >/dev/null 2>&1; then
    echo "network up after ${i} attempts"
    break
  fi
  echo "waiting for egress (${i}/60)"
  sleep 5
done

retry() {
  for i in $(seq 1 10); do
    "$@" && return 0
    echo "retry ${i}/10: $*"
    sleep 15
  done
  return 1
}

export DEBIAN_FRONTEND=noninteractive
retry apt-get update
retry apt-get install -y python3-venv unzip curl git

# ansible-core + boto3 (amazon.aws 11 needs boto3/botocore >= 1.35, newer than apt's)
python3 -m venv /opt/ansible
retry /opt/ansible/bin/pip install --upgrade pip
retry /opt/ansible/bin/pip install "${ANSIBLE_CORE_SPEC}" 'boto3>=1.35' 'botocore>=1.35'
for bin in ansible ansible-playbook ansible-galaxy ansible-config ansible-doc ansible-inventory; do
  ln -sf "/opt/ansible/bin/${bin}" "/usr/local/bin/${bin}"
done

# AWS CLI v2
retry curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
unzip -q /tmp/awscliv2.zip -d /tmp
/tmp/aws/install --update
rm -rf /tmp/awscliv2.zip /tmp/aws

# session-manager-plugin -- amazon.aws.aws_ssm shells out to this binary
retry curl -fsSL "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb" \
  -o /tmp/session-manager-plugin.deb
dpkg -i /tmp/session-manager-plugin.deb
rm -f /tmp/session-manager-plugin.deb

# Repo + pinned collections/roles, installed for the ubuntu user
sudo -u ubuntu bash -lc "cd ~ && { [ -d devops-bootcamp-project ] || git clone -q ${REPO_URL}; }"
sudo -u ubuntu bash -lc "cd ~/devops-bootcamp-project/ansible && ansible-galaxy install -r requirements.yml"

touch /var/lib/controller-bootstrap-done
echo "controller bootstrap finished"
