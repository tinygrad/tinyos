#!/usr/bin/env bash

echo "text,Rebooting..." | nc -U /run/tinybox-screen.sock
