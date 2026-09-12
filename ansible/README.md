# Ansible

Semua playbook dijalankan **dari Ansible controller** (10.0.0.135), bukan dari laptop.

```bash
aws ssm start-session --target <controller-id> --region ap-southeast-1
sudo su - ubuntu
git clone https://github.com/Raaid17/devops-bootcamp-project.git
cd devops-bootcamp-project/ansible

ansible all -m ping
ansible-playbook playbook-web.yaml
ansible-playbook playbook-exporter.yaml
ansible-playbook playbook-monitoring.yaml
```

## Pengangkutan SSM, bukan SSH

Tiada port 22 dibuka dalam mana-mana security group. `inventory.ini` menetapkan
`ansible_connection=amazon.aws.aws_ssm`, jadi setiap tugas bergerak melalui AWS
Systems Manager.

Plugin ini **wajib** ada bucket S3 untuk pindah fail — walaupun untuk modul yang
tidak menghantar fail. Kami guna semula bucket state dengan prefix
`ansible-transfer/`, dan itulah satu-satunya prefix yang dibenarkan oleh
`devops-controller-role`.

> Plugin ini berada dalam koleksi `amazon.aws`, bukan `community.aws` — ia sudah
> dipindahkan. Kebanyakan tutorial lama masih tunjuk nama lama.
