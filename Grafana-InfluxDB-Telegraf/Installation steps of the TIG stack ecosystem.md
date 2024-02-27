# Installation steps of the TIG stack ecosystem on Rocky Linux 9.3


## Update the System

Ensure that all packages are up to date with the latest security patches and bug fixes.

```sh
sudo dnf update -y
```


## Clone the Github repository

```
sudo dnf install git -y
git clone https://github.com/jullienl/HPE-Synergy-OneView-demos
```

## Install InfluxDB

Add the InfluxData repository:
```sh
cat <<EOF | sudo tee /etc/yum.repos.d/influxdata.repo
[influxdata]
name = InfluxData Repository - Stable
baseurl = https://repos.influxdata.com/stable/\$basearch/main
enabled = 1
gpgcheck = 1
gpgkey = https://repos.influxdata.com/influxdata-archive_compat.key
EOF
```

Install InfluxDB:
```sh
sudo yum install -y influxdb
```

Start and enable InfluxDB service:
```sh
sudo systemctl start influxdb
sudo systemctl enable influxdb
```

Configure the Linux firewall (if applicable):

```sh
sudo firewall-cmd --add-port=8086/tcp --permanent
sudo firewall-cmd --reload
```

Enable authentication in the InfluxDB configuration file:
```sh
sudo vi /etc/influxdb/influxdb.conf
```

Locate the `[http]` section and find the setting `auth-enabled`. Set it to `true` to enable authentication.

```ini
[http]
...
auth-enabled = true
...
```

Restart InfluxDB:
```sh
sudo systemctl restart influxdb
```

Create an Administrative User:
```influxql
influx
```

Create an administrative user (you can replace `telegraf` and `password` with your chosen username and password):

```influxql
CREATE USER telegraf WITH PASSWORD 'password' WITH ALL PRIVILEGES
```

Exit the InfluxDB CLI:

```influxql
exit
```


## Install Telegraf

Install Telegraf:
```sh
sudo yum install -y telegraf
```

Configue Telegraf output to Influxdb:
```sh
cat <<EOF | sudo tee /etc/telegraf/telegraf.d/HPE_COM.conf
[[outputs.influxdb]]
   username = "telegraf"
   password = "password"
EOF
```

Start and enable Telegraf service:
```sh
sudo systemctl start telegraf
sudo systemctl enable telegraf
```

## Install Grafana

Add the Grafana repository:

```sh
cat <<EOF | sudo tee /etc/yum.repos.d/grafana.repo 
[grafana]
name=grafana
baseurl=https://rpm.grafana.com
repo_gpgcheck=1
enabled=1
gpgcheck=1
gpgkey=https://rpm.grafana.com/gpg.key
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
EOF
```

Install Grafana:
```sh
sudo yum install -y grafana
```

Start and enable Grafana service

```sh
sudo systemctl start grafana-server
sudo systemctl enable grafana-server
```

Configure the firewall (if applicable):
```sh
sudo firewall-cmd --add-port=3000/tcp --permanent
sudo firewall-cmd --reload
```

## Accessing Grafana Web Interface

- You can access Grafana's web interface by navigating to `http://<your-server-ip>:3000` in a web browser.
- The default login credentials are `admin` for both username and password.

## Install PowerShell Core on Linux 

Register the Microsoft RedHat repository
```sh
curl -sSL -O https://packages.microsoft.com/config/rhel/9/packages-microsoft-prod.rpm
```

Register the Microsoft repository keys
```sh
sudo rpm -i packages-microsoft-prod.rpm
```

Delete the repository keys after installing
```sh
rm packages-microsoft-prod.rpm
```

Install PowerShell
```sh
sudo yum install powershell -y
```



# Automated TIG Stack Deployment on Rocky Linux 9.3 with One-Paste Command


You can copy the following command block and paste it into your terminal window to install Telegraf, InfluxDB and Grafana in one shot on the Rocky Linux VM:

```sh
# Clone the Github repository
sudo dnf install git -y
git clone https://github.com/jullienl/HPE-Compute-Ops-Management
# Install InfluxDB
cat <<EOF | sudo tee /etc/yum.repos.d/influxdata.repo
[influxdata]
name = InfluxData Repository - Stable
baseurl = https://repos.influxdata.com/stable/\$basearch/main
enabled = 1
gpgcheck = 1
gpgkey = https://repos.influxdata.com/influxdata-archive_compat.key
EOF
sudo yum install -y influxdb
sudo systemctl start influxdb
sudo systemctl enable influxdb
sudo firewall-cmd --add-port=8086/tcp --permanent
sudo firewall-cmd --reload
sudo sed -i 's/^ *# *auth-enabled *=.*$/auth-enabled = true/g' /etc/influxdb/influxdb.conf
sudo systemctl restart influxdb
influx -execute "CREATE USER telegraf WITH PASSWORD 'password' WITH ALL PRIVILEGES"
# Install Telegraf
sudo yum install -y telegraf
cat <<EOF | sudo tee /etc/telegraf/telegraf.d/HPE_COM.conf
[[outputs.influxdb]]
   username = "telegraf"
   password = "password"
EOF
sudo systemctl start telegraf
sudo systemctl enable telegraf
# Install Grafana
cat <<EOF | sudo tee /etc/yum.repos.d/grafana.repo 
[grafana]
name=grafana
baseurl=https://rpm.grafana.com
repo_gpgcheck=1
enabled=1
gpgcheck=1
gpgkey=https://rpm.grafana.com/gpg.key
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
EOF
sudo yum install -y grafana
sudo systemctl start grafana-server
sudo systemctl enable grafana-server
sudo firewall-cmd --add-port=3000/tcp --permanent
sudo firewall-cmd --reload
# Install PowerShell Core on Linux 
curl -sSL -O https://packages.microsoft.com/config/rhel/9/packages-microsoft-prod.rpm
sudo rpm -i packages-microsoft-prod.rpm
rm packages-microsoft-prod.rpm
sudo yum install powershell -y

```