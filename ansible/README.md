# Ansible

Semua playbook dijalankan **dari Ansible controller** (10.0.0.135), bukan dari laptop.
`user_data` controller sudah clone repo ini dan memasang koleksi dari
`requirements.yml`, jadi cukup tarik perubahan terkini:

```bash
aws ssm start-session --target <controller-id> --region ap-southeast-1
sudo su - ubuntu
cd devops-bootcamp-project && git pull
cd ansible

ansible all -m ping
ansible-playbook playbook-web.yaml
ansible-playbook playbook-exporter.yaml
ansible-playbook playbook-monitoring.yaml
```

## Versi

| | Versi | Kenapa |
|---|---|---|
| ansible-core | `>=2.21,<2.22` (virtualenv `/opt/ansible`) | pakej apt Ubuntu 24.04 ialah 2.16 — **EOL sejak Julai 2025** |
| amazon.aws | `11.x` | plugin `aws_ssm`; perlukan ansible-core ≥ 2.17 |
| community.docker | `5.x` | `docker_container`, `docker_compose_v2`; perlukan ansible-core ≥ 2.17 |
| prometheus.prometheus | `0.30.x` | menyokong ansible-core **sehingga 2.21.x sahaja** — sebab had `<2.22` |
| geerlingguy.docker | `8.0.0` | |

Semua dipin dalam `requirements.yml`.

## Pengangkutan SSM, bukan SSH

Tiada port 22 dibuka dalam mana-mana security group. `inventory.ini` menetapkan
`ansible_connection=amazon.aws.aws_ssm`, jadi setiap tugas bergerak melalui AWS
Systems Manager.

Plugin ini **wajib** ada bucket S3 untuk pindah fail — walaupun untuk modul yang
tidak menghantar fail. Ia menggunakan bucket **berasingan**
`devops-bootcamp-ansible-transfer-raaid17`, bukan bucket state: objek ditulis di
akar bucket dengan kunci `<instance-id>/<laluan>`, jadi prefix tidak boleh
mengehadkan akses.

**Hanya `devops-controller-role` ada akses S3.** Controller menjana *presigned URL*
dan sasaran memuat turun/naik dengan `curl`, jadi web server dan monitoring server
tidak memerlukan sebarang kebenaran S3.

> Plugin ini dahulu berada dalam `community.aws`. Ia telah dipindahkan ke
> `amazon.aws`, dan `community.aws.aws_ssm` kini hanya *redirect*. Kebanyakan
> tutorial lama masih tunjuk nama lama.
