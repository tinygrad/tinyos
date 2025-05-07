#!/usr/bin/env bash

source /etc/tinybox-release

systemctl enable displayservice
systemctl enable buttonservice
systemctl start displayservice
systemctl start buttonservice
