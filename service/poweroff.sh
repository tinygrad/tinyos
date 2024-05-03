#!/usr/bin/env bash

echo "text,Shutting Down..." | nc -U /run/tinybox-screen.sock
