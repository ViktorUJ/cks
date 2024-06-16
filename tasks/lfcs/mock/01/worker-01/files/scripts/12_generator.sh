#!/bin/bash

useradd batman
useradd spiderman

echo "batman:password4batman" | sudo chpasswd
echo "spiderman:password4spiderman" | sudo chpasswd

passwd -l batman
passwd -u spiderman
