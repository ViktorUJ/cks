# Using Falco to Monitor Audit Events
````` 
openssl req -newkey rsa:2048 -nodes -keyout key.pem -x509 -days 365 -out certificate.pem
cat certificate.pem key.pem > falco.pem
sudo cp falco.pem /etc/falco/falco.pem
sudo systemctl restart falco.service
sudo systemctl status falco.service

# in new terminal 
sudo journalctl -u falco.service -f
`````