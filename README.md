# DevOps Bootcamp 2026 — Final Project

Satu sistem yang menyambungkan dua belas topik bootcamp: Terraform membina rangkaian dan
server, Ansible mengkonfigurasi semuanya dari controller peribadi **tanpa SSH**, aplikasi
berjalan sebagai container dari imej ECR peribadi, Prometheus dan Grafana memantau sebagai
container, dan Cloudflare mendedahkan kedua-dua perkhidmatan.

## Tiga URL

| | Pautan |
|---|---|
| 🌐 **Aplikasi** | https://web.sirbutterfinger.com |
| 📊 **Monitoring** | https://monitoring.sirbutterfinger.com |
| 📦 **Repo** | https://github.com/Raaid17/devops-bootcamp-project |

## Arkitektur

```
AWS · ap-southeast-1
└── devops-vpc · 10.0.0.0/24
    ├── devops-public-subnet · 10.0.0.0/25        ← devops-igw
    │   └── web server · 10.0.0.5 · Elastic IP 18.142.62.173
    │       ├── container aplikasi (imej ECR) :80
    │       └── node_exporter :9100
    └── devops-private-subnet · 10.0.0.128/25     ← devops-ngw
        ├── ansible controller · 10.0.0.135
        └── monitoring server · 10.0.0.136
            └── prometheus :9090 · grafana :3000 · cloudflared

Cloudflare
├── web.sirbutterfinger.com        → A record → Elastic IP (proxied · Flexible)
└── monitoring.sirbutterfinger.com → Cloudflare Tunnel → grafana:3000
```

Aliran metrik: `node_exporter (10.0.0.5:9100) → Prometheus (10.0.0.136:9090) → Grafana`

## Struktur repo

```
app/         aplikasi (fork Infratify/ship) + Dockerfile multi-stage
terraform/   VPC, subnet, gateway, security group, IAM, ECR, EC2
  bootstrap/ bucket S3 untuk state (dijalankan sekali sahaja)
ansible/     playbook untuk web server dan monitoring server
.github/     workflow pages, plan, deploy
```

## Tiada port 22 — langsung

Tiada mana-mana security group membuka port 22, dan tiada `key_name` pada mana-mana
instance. Ansible bercakap dengan kedua-dua sasaran melalui **AWS Systems Manager**.

```ini
ansible_connection=community.aws.aws_ssm
```

Plugin ini **wajib** ada bucket S3 untuk memindah fail — walaupun untuk modul yang tidak
menghantar fail. Objek ditulis di akar bucket dengan kunci `<instance-id>/<laluan>`, jadi
prefix tidak boleh digunakan untuk mengehadkan akses. Sebab itu ia menggunakan bucket
**berasingan** daripada bucket state, supaya state Terraform kekal terasing.

> Plugin ini berpindah ke `amazon.aws.aws_ssm` dalam keluaran yang lebih baharu. Ubuntu
> 24.04 menghantar ansible-core 2.16 dengan amazon.aws 7.2 yang **tiada** plugin connection
> langsung — pada versi itu ia masih `community.aws`.

## Cara menjalankan

### 1 · Terraform

```bash
cd terraform/bootstrap && terraform init && terraform apply   # sekali sahaja
cd ..                  && terraform init && terraform apply
```

### 2 · Ansible — dari controller, bukan dari laptop

```bash
aws ssm start-session --target i-09cb436d4016ca094 --region ap-southeast-1
sudo su - ubuntu
git clone https://github.com/Raaid17/devops-bootcamp-project.git
cd devops-bootcamp-project/ansible

ansible all -m ping
ansible-playbook playbook-web.yaml
ansible-playbook playbook-exporter.yaml
ansible-playbook playbook-monitoring.yaml
```

### 3 · Cloudflare

1. DNS → A record `web` → `18.142.62.173`, proxy **ON**, SSL/TLS mode **Flexible**.
2. Zero Trust → Networks → Tunnels → cipta tunnel, public hostname
   `monitoring.sirbutterfinger.com` → `http://grafana:3000`.
3. Simpan token tunnel:
   ```bash
   aws ssm put-parameter --name /devops-bootcamp-2026/final-project/tunnel-token \
     --type SecureString --value '<token>' --region ap-southeast-1
   ```
4. Jalankan semula `ansible-playbook playbook-monitoring.yaml`.

## Rujukan sumber

| | Nilai |
|---|---|
| Bucket state | `devops-bootcamp-terraform-raaid17` |
| Bucket transfer Ansible | `devops-bootcamp-ansible-transfer-raaid17` |
| Repositori ECR | `396608796485.dkr.ecr.ap-southeast-1.amazonaws.com/devops-bootcamp/final-project-raaid17` |
| Web server | `i-05c79e3f5c3218463` · 10.0.0.5 |
| Ansible controller | `i-09cb436d4016ca094` · 10.0.0.135 |
| Monitoring server | `i-09cb396686001557d` · 10.0.0.136 |

## CI/CD

| Workflow | Pencetus | Kerja |
|---|---|---|
| `plan` | pull request | `terraform fmt -check`, `validate`, `plan` (role **baca sahaja**), komen pada PR |
| `deploy` | push ke `main` | test → bina imej → tolak ke ECR → `ssm send-command` suruh web server tarik dan mula semula |
| `pages` | push ke `main` | terbitkan README ini sebagai halaman awam |

Tiada kunci AWS jangka panjang dalam repo: GitHub OIDC menukar token pendek setiap larian.
Role `plan` dan role `deploy` **berasingan** — PR tidak boleh menolak imej atau menyentuh
server, dan deploy tidak boleh membaca seluruh akaun.

## IAM least privilege

| Role | Dibenarkan |
|---|---|
| `devops-web-role` | SSM agent · tarik satu repo ECR sahaja |
| `devops-controller-role` | SSM agent · `StartSession` kepada **dua** instance sahaja · bucket transfer |
| `devops-monitoring-role` | SSM agent · baca **satu** parameter SSM sahaja |
| `devops-github-actions-role` | tolak ke ECR · `SendCommand` kepada web server sahaja |
| `devops-github-plan-role` | `ReadOnlyAccess` |

## Membersihkan

```bash
cd terraform && terraform destroy
cd bootstrap && terraform destroy
```

NAT gateway dan Elastic IP dikenakan bayaran setiap jam walaupun tiada trafik — itulah
benda paling mahal jika ditinggalkan hidup.
