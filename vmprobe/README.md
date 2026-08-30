# HowTo

Directory ini pakai CRD `VMProbe` (sudah ter-install di cluster ini dan
RBAC-nya sudah diberikan ke operator), yang memang didesain khusus untuk
probing lewat blackbox_exporter.

Blackbox-exporter berjalan sebagai DaemonSet dengan `hostNetwork: true`,
artinya tiap node punya instance blackbox-exporter sendiri di port `19115`.
Satu `VMProbe` di-generate per node supaya target yang sama diprobe dari
sudut pandang jaringan tiap node (mesh check) — bukan cuma lewat satu
Service yang random pick salah satu pod.

## 1. Isi target di `template.yaml.tpl`

File ini sengaja diberi ekstensi `.tpl` (bukan `.yaml`) supaya tidak ikut
ke-apply kalau ada yang jalankan `kubectl apply -f vmprobe/` — `kubectl
apply -f <dir>` hanya membaca file `*.yaml`/`*.yml`/`*.json`, dan isi
template ini masih berupa placeholder yang belum valid untuk di-apply
langsung.

Ada 3 placeholder di dalam file. Berikut cara memperlakukan masing-masing:

| Placeholder | Contoh di file | Wajib diedit? | Cara isi |
|---|---|---|---|
| `NODE_NAME` | `metadata.name: blackbox-NODE_NAME`, `labels.src_node: NODE_NAME` | **Jangan diubah manual** | Otomatis diisi nama node oleh `script.sh` saat generate |
| `NODE_IP` | `spec.vmProberSpec.url: NODE_IP:19115` | **Jangan diubah manual** | Otomatis diisi internal IP node oleh `script.sh` saat generate |
| `YOUR_TARGET_ENDPOINT` | `spec.targets.staticConfig.targets: - YOUR_TARGET_ENDPOINT` | **Wajib diedit manual** | Ganti/tambah dengan URL/host:port target yang mau diprobe |

Jadi satu-satunya bagian yang perlu kamu edit tangan sebelum generate adalah
daftar `targets` (ganti `YOUR_TARGET_ENDPOINT`) dan `module:` di atasnya
kalau perlu (lihat tabel module di bawah). `NODE_NAME` dan `NODE_IP`
biarkan apa adanya — kalau ikut diganti manual, hasil generate per node
oleh `script.sh` justru akan rusak.

Contoh sebelum diedit (bagian target masih placeholder):

```yaml
spec:
  module: https_kubeapi
  vmProberSpec:
    url: NODE_IP:19115        # <- jangan diubah, ini placeholder untuk script.sh
    path: /probe
    scheme: http
  targets:
    staticConfig:
      labels:
        src_node: NODE_NAME    # <- jangan diubah, ini placeholder untuk script.sh
      targets:
      - https://YOUR_TARGET_ENDPOINT   # <- WAJIB diganti dengan target asli
```

Contoh setelah diedit (menambahkan 3 target real, module tetap
`https_kubeapi`):

```yaml
spec:
  module: https_kubeapi
  vmProberSpec:
    url: NODE_IP:19115
    path: /probe
    scheme: http
  targets:
    staticConfig:
      labels:
        src_node: NODE_NAME
      targets:
      - https://10.21.0.11:6443/healthz
      - https://10.21.0.12:6443/healthz
      - https://10.21.0.13:6443/healthz
```

### Ganti `module:` kalau target bukan HTTPS kube-apiserver

Default template pakai `module: https_kubeapi`, khusus untuk probing
endpoint HTTPS ber-TLS kube-apiserver. Kalau target kamu bukan itu, ganti
baris `module:` di `spec.module` sesuai jenis target, misal:

| Jenis target | `module:` yang dipakai |
|---|---|
| Endpoint HTTP biasa (mis. web app, ingress) | `http_2xx` |
| Endpoint HTTP yang perlu POST | `http_post_2xx` |
| IRC server | `irc_banner` |
| POP3S server | `pop3s_banner` |
| SSH server | `ssh_banner` |
| Sekadar cek TCP port kebuka | `tcp_connect` |
| Ping (ICMP) | `icmp_ipv4` |
| HTTPS kube-apiserver (default) | `https_kubeapi` |

Definisi lengkap tiap module ada di `blackbox-exporter/configmap.yaml`.

> Catatan: satu `VMProbe` cuma punya satu `module`. Kalau butuh module yang
> beda-beda untuk sebagian target, duplikasikan `template.yaml.tpl` (misal
> jadi `template-tcp.yaml.tpl` — **tetap pakai akhiran `.tpl`**, jangan
> `.yaml` langsung, supaya tidak ikut ke-apply dan tidak ikut kehapus oleh
> cleanup di `script.sh`) dengan target dan module masing-masing, lalu
> sesuaikan `script.sh` untuk generate dari kedua template tersebut.

## 2. Generate manifest per node

```
~/victoria-metrics-operator/vmprobe# bash script.sh
Generated list.txt
Generated jh-k8s-master001.yaml
Generated jh-k8s-master002.yaml
Generated jh-k8s-master003.yaml
Generated jh-k8s-worker001.yaml
...
```

Script ini juga otomatis menghapus file `<node>.yaml` lokal untuk node yang
sudah tidak ada lagi di cluster (misal setelah scale-down), supaya tidak ada
manifest basi yang ketinggalan. Kalau ada file yang dihapus, script akan
menyarankan `kubectl delete vmprobe` untuk objek yang sudah pernah di-apply
sebelumnya — cleanup lokal tidak menghapus objek yang sudah ada di cluster.

## 3. Review lalu apply

```
kubectl apply -f vmprobe/
```

## 4. Verifikasi

```
# kubectl -n monitoring-system get vmprobe
NAME                        AGE
blackbox-jh-k8s-master001   22m
blackbox-jh-k8s-master002   22m
blackbox-jh-k8s-master003   22m
blackbox-jh-k8s-worker001   22m
...
```
