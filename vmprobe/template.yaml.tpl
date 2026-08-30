apiVersion: operator.victoriametrics.com/v1beta1
kind: VMProbe
metadata:
  labels:
    app.kubernetes.io/component: exporter
    app.kubernetes.io/name: blackbox-NODE_NAME
    app.kubernetes.io/part-of: victoria-metrics-stack
    app.kubernetes.io/managed-by: kubectl
  name: blackbox-NODE_NAME
  namespace: monitoring-system
spec:
  jobName: blackbox-NODE_NAME
  interval: 30s
  # Module name harus sesuai dengan salah satu yang didefinisikan di
  # blackbox-exporter/configmap.yaml (http_2xx, http_post_2xx, irc_banner,
  # pop3s_banner, ssh_banner, tcp_connect, icmp_ipv4, https_kubeapi).
  # Kalau butuh module berbeda untuk target lain, duplikasikan file ini
  # dengan nama-file lain (misal template-tcp.yaml) lalu generate terpisah.
  module: https_kubeapi
  vmProberSpec:
    # Blackbox-exporter berjalan sebagai DaemonSet dengan hostNetwork,
    # sehingga tiap node punya instance blackbox-exporter sendiri di
    # NODE_IP:19115. NODE_IP diisi otomatis oleh script.sh.
    url: NODE_IP:19115
    path: /probe
    scheme: http
  targets:
    staticConfig:
      # src_node berlaku sama untuk semua target di bawah (label ini
      # menandai dari node mana probe dijalankan). Nama/URL target itu
      # sendiri sudah otomatis muncul di label "instance", jadi tidak
      # perlu dst_name manual lagi seperti skema :_: lama.
      labels:
        src_node: NODE_NAME
      targets:
      ##################################################################
      # Isi target yang mau di-probe DARI node ini di sini.            #
      # Cukup URL/host:port biasa, tidak perlu delimiter apa pun.      #
      # Semua target di bawah pakai module yang sama (lihat atas).     #
      # Kalau butuh module lain untuk sebagian target, taruh di file   #
      # template terpisah (lihat README.md).                          #
      ##################################################################
      - https://YOUR_TARGET_ENDPOINT
