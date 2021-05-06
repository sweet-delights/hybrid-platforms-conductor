hostname=${1}
check_flag=${2:-deploy}
if [ "${check_flag}" = "check" ]; then
  # Check if python3 is installed
  if ssh -o StrictHostKeyChecking=no root@${hostname} 'python3 --version' 2>/dev/null; then
    echo 'OK'
  else
    echo 'Missing'
  fi
else
  # Install python3
  ssh -o StrictHostKeyChecking=no root@${hostname} 'apt install -y python3-pip' 2>/dev/null
  echo 'Installed'
fi
