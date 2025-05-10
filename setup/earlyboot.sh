#!/usr/bin/env bash

source /etc/tinybox-release

systemctl enable tinybox-display
systemctl enable tinybox-button
systemctl start tinybox-display
systemctl start tinybox-button

systemctl enable tinybox-setup
