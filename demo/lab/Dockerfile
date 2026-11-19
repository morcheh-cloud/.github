# A throwaway "server" for the public demo: Debian with systemd, SSH, nginx,
# Docker and a small app, run under Sysbox so visitors can be root in it
# without being root on the host. Images for its Docker are baked in at build
# time, since the lab network has no way out.
FROM debian:trixie AS images
RUN apt-get update && apt-get install -y --no-install-recommends skopeo ca-certificates \
 && rm -rf /var/lib/apt/lists/*
RUN mkdir /images \
 && for ref in nginx:1.29-alpine redis:8-alpine traefik/whoami:v1.11 adminer:5; do \
      name=$(echo "$ref" | tr '/:' '__'); \
      skopeo copy --override-os linux "docker://docker.io/$ref" "docker-archive:/images/$name.tar:$ref"; \
    done

FROM debian:trixie
ENV container=docker DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
      systemd systemd-sysv dbus openssh-server openssh-sftp-server sudo \
      nginx cron fail2ban ufw iptables procps iproute2 less nano vim-tiny \
      curl ca-certificates python3 htop rsync zip unzip \
      docker.io docker-compose \
 && rm -rf /var/lib/apt/lists/* \
 && systemctl mask systemd-logind getty.target console-getty.service \
 && systemctl enable ssh nginx cron docker \
 && useradd -m -s /bin/bash -G docker,sudo ant \
 && echo 'ant ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/ant \
 && sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
COPY --from=images /images /opt/demo/images
COPY rootfs/ /
RUN chmod +x /usr/local/bin/demo-* \
 && systemctl enable demo-setup.service demo-load.service shop-api.service
STOPSIGNAL SIGRTMIN+3
ENTRYPOINT ["/usr/local/bin/demo-entrypoint"]
