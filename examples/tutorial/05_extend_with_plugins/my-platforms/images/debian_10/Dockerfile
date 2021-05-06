# syntax=docker/dockerfile:1
FROM debian:buster

RUN apt-get update && apt-get install -y openssh-server
RUN mkdir /var/run/sshd
# Activate root login with test password
RUN echo 'root:root_pwd' | chpasswd
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
# Speed-up considerably ssh performance and avoid huge lags and timeouts without DNS
RUN sed -i 's/#UseDNS yes/UseDNS no/' /etc/ssh/sshd_config
EXPOSE 22

CMD ["/usr/sbin/sshd", "-D"]
