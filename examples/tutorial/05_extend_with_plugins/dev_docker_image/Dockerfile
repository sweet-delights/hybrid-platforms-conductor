# syntax=docker/dockerfile:1
# Pull the image containing Go
FROM debian:buster

# Install sshd
RUN apt-get update && apt-get install -y openssh-server
RUN mkdir /var/run/sshd
# Activate root login
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
# Speed-up considerably ssh performance and avoid huge lags and timeouts without DNS
RUN sed -i 's/#UseDNS yes/UseDNS no/' /etc/ssh/sshd_config
EXPOSE 22

# Upload our root key for key authentication of root
COPY hpc_root.key.pub /root/.ssh/authorized_keys
RUN chmod 700 /root/.ssh
RUN chmod 400 /root/.ssh/authorized_keys

# Startup command
CMD ["/usr/sbin/sshd", "-D"]
