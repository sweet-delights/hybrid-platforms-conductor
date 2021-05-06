# syntax=docker/dockerfile:1
# Pull the image containing Go
FROM golang:1.16.3-buster

# Install the web server
# Create the message file to be displayed by the web server
COPY hello_world.txt /root/hello_world.txt
# Copy the code
COPY main.go /codebase/src/main.go
# Build the binary
RUN cd /codebase && go build -v -o /codebase/bin/server ./src/main.go
# Set the env which will be available at runtime
ENV PORT=80
EXPOSE 80

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

# Startup script
COPY start.sh /start.sh
RUN chmod +x /start.sh
CMD ["/start.sh"]
