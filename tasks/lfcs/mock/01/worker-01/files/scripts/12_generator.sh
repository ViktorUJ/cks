#!/bin/bash

useradd batman
useradd spiderman

echo "batman:password4batman" | sudo chpasswd
echo "spiderman:password4spiderman" | sudo chpasswd

passwd -u batman
passwd -l spiderman
