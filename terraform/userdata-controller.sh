#!/bin/bash
set -uxo pipefail

# Everything Ansible needs to drive the two targets over SSM. Baked into
# user_data so a rebuilt controller is never missing the session-manager-plugin,
# which the amazon.aws.aws_ssm connection plugin shells out to.
#
# Note: no `set -e`. A private-subnet instance can win the race against its own
# NAT route, and a transient DNS/apt failure must not abort the whole script --
# it should wait and retry instead.

exec > >(tee -a /var/log/controller-bootstrap.log) 2>&1

# Wait for egress through the NAT gateway before touching the network.
for i in $(seq 1 60); do
  if curl -fsS --max-time 5 https://api.ubuntu.com >/dev/null 2>&1 \
    || getent hosts archive.ubuntu.com >/dev/null 2>&1; then
    echo "network up after ${i} attempts"
    break
  fi
  echo "waiting for egress (${i}/60)"
  sleep 5
done

apt_retry() {
  for i in $(seq 1 10); do
    if DEBIAN_FRONTEND=noninteractive apt-get "$@"; then
      return 0
    fi
    echo "apt-get $* failed, retry ${i}/10"
    sleep 15
  done
  return 1
}

apt_retry update
apt_retry install -y ansible python3-pip python3-boto3 unzip curl git

# AWS CLI v2
curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
unzip -q /tmp/awscliv2.zip -d /tmp
/tmp/aws/install --update
rm -rf /tmp/awscliv2.zip /tmp/aws

# session-manager-plugin -- the transport the connection plugin actually uses
curl -fsSL "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb" \
  -o /tmp/session-manager-plugin.deb
dpkg -i /tmp/session-manager-plugin.deb
rm -f /tmp/session-manager-plugin.deb

# Collections/roles the playbooks depend on, installed for the ubuntu user
sudo -u ubuntu ansible-galaxy collection install community.aws community.docker prometheus.prometheus
sudo -u ubuntu ansible-galaxy role install geerlingguy.docker

touch /var/lib/controller-bootstrap-done
echo "controller bootstrap finished"
