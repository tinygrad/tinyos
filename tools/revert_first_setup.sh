#!/usr/bin/env bash
# go back to before first setup
(return 0 2>/dev/null) && sourced=1 || sourced=0

sed -i '/bash \/opt\/tinybox\/setup\/firstsetup.sh/d' "$HOME"/.profile
echo "bash /opt/tinybox/setup/firstsetup.sh" >> /home/tiny/.profile

touch /home/tiny/.before_firstsetup

rm -f /home/tiny/.bash_history
history -c

if [ "$sourced" -eq 1 ]; then
  rm -f /home/tiny/.ssh/authorized_keys
fi

sudo systemctl restart displayservice

exit
