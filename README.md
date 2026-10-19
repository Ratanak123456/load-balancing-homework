# Highly Available React Application

This lab deploys a static React and Tailwind CSS application across two Ubuntu VMs. Two HAProxy load balancers distribute HTTP traffic, and Keepalived moves a shared virtual IP (VIP) between them. systemd manages the Node.js static serving process on each web server.

Application entry point: **http://192.168.56.100**

## Infrastructure

| VM | Private IP | Services | RAM | vCPUs |
|---|---|---|---|---|
| lb-01 | 192.168.56.10 | HAProxy, Keepalived | 512 MB | 1 |
| lb-02 | 192.168.56.11 | HAProxy, Keepalived | 512 MB | 1 |
| web-01 | 192.168.56.20 | React build, Node.js, Express, systemd | 1024 MB | 1 |
| web-02 | 192.168.56.21 | React build, Node.js, Express, systemd | 1024 MB | 1 |
| Floating IP | 192.168.56.100 | Owned by one healthy load balancer | — | — |

The guests use `ubuntu/jammy64` (Ubuntu 22.04 LTS). The assignment recommends Ubuntu 24.04; this implementation uses 22.04. Host versions observed during setup were Vagrant 2.4.9 and VirtualBox 7.2.20. The guests use Node.js 24 and HAProxy 2.4.30. Private networking uses `enp0s8`; the NAT adapter provides internet access.

Traffic path: browser → VIP port 80 → active HAProxy → healthy web server port 3000.

All VMs run on one physical host. This provides service and guest-level availability, but does not protect against physical host failure. Brief interruptions during VIP transfer are acceptable.

## Repository layout

- `Vagrantfile`: all four VM definitions and basic tool provisioning.
- `react-app/`: React source, npm lockfile, and `server.mjs`.
- `systemd/react-app.service`: web-serving service.
- `haproxy/haproxy.cfg`: shared load-balancing configuration.
- `keepalived/lb01.conf` and `keepalived/lb02.conf`: per-balancer VRRP settings.
- `scripts/`: setup, deployment, monitoring, management, and reporting scripts.
- `screenshots/`: captured demonstration evidence.

## Installation

Run host commands from the repository root unless stated otherwise. Enable hardware virtualization and install Vagrant and VirtualBox first. Allow at least 3 GB for guest RAM plus host and virtualization overhead.

### 1. Start and verify the VMs

```bash
vagrant validate
vagrant up --provider=virtualbox
vagrant status
vagrant ssh web-01 -c "ping -c 3 192.168.56.10"
vagrant ssh web-01 -c "ping -c 3 192.168.56.11"
vagrant ssh web-01 -c "ping -c 3 192.168.56.21"
```

The repository root is shared as `/vagrant` inside each VM. SSH uses Vagrant-managed keys; no application password is hardcoded.

### 2. Check for a VIP conflict

```bash
VBoxManage list dhcpservers
```

If the enabled DHCP server for `HostInterfaceNetworking-vboxnet0` uses `192.168.56.100`, disable and stop that specific host-only DHCP server before activating the VIP:

```bash
VBoxManage dhcpserver modify --interface=vboxnet0 --disable
VBoxManage dhcpserver stop --interface=vboxnet0
sudo ip neigh flush to 192.168.56.100 dev vboxnet0
```

These VMs have static private addresses. This change affects other VMs relying on DHCP on the same host-only network, but does not disable the guests' NAT internet connectivity. Do not disable unrelated DHCP servers.

### 3. Prepare and deploy the web servers

The committed package.json and package-lock.json must include Express. The deployment script must set `SOURCE_DIR="$PROJECT_DIR/react-app"`.

```bash
chmod +x scripts/*.sh
vagrant ssh web-01 -c "sudo bash /vagrant/scripts/setup-web.sh"
vagrant ssh web-02 -c "sudo bash /vagrant/scripts/setup-web.sh"
vagrant ssh web-01 -c "sudo bash /vagrant/scripts/deploy-react.sh"
vagrant ssh web-02 -c "sudo bash /vagrant/scripts/deploy-react.sh"
curl --noproxy '*' -f http://192.168.56.20:3000/health
curl --noproxy '*' -f http://192.168.56.21:3000/health
```

Deployment copies the source into a new directory under `/opt/react-app/releases`, excluding host node_modules and dist. It installs dependencies with npm ci, builds with the VM's name in VITE_SERVER_NAME, and switches `/opt/react-app/current` to the new release only after the build succeeds. It then installs and restarts the service and retries the health check during startup. Old releases remain available, but automatic rollback and zero-downtime deployment are not implemented.

The JSX server badge reads `import.meta.env.VITE_SERVER_NAME || 'LOCAL DEV'`. Vite embeds this value at build time, so the same source produces separately identified WEB-01 and WEB-02 builds.

### 4. Configure both HAProxy servers

```bash
for vm in lb-01 lb-02; do
    vagrant ssh "$vm" -c "sudo apt-get update && sudo apt-get install -y haproxy"
    vagrant ssh "$vm" -c "sudo haproxy -c -f /vagrant/haproxy/haproxy.cfg && sudo install -m 0644 /vagrant/haproxy/haproxy.cfg /etc/haproxy/haproxy.cfg && sudo systemctl enable haproxy && sudo systemctl restart haproxy"
done
```

HAProxy listens on all IPv4 addresses on port 80, uses round robin, and checks GET /health for HTTP 200. Checks run every two seconds; three failed checks remove a backend and two successful checks restore it.

```bash
for address in 192.168.56.10 192.168.56.11; do
    for i in {1..6}; do
        curl --noproxy '*' -fsS --max-time 5 "http://$address/health"
    done
done
```

### 5. Configure Keepalived

```bash
for vm in lb-01 lb-02; do
    vagrant ssh "$vm" -c "sudo apt-get update && sudo apt-get install -y keepalived"
    vagrant ssh "$vm" -c "ip -br -4 addr"
    vagrant ssh "$vm" -c "sudo install -o root -g root -m 0755 /vagrant/scripts/check-haproxy.sh /usr/local/sbin/check-haproxy.sh && sudo /usr/local/sbin/check-haproxy.sh"
done
```

Verify that `enp0s8` is the private interface on both VMs; update the Keepalived files if it differs in another environment.

```bash
vagrant ssh lb-01 -c "sudo keepalived -t -f /vagrant/keepalived/lb01.conf && sudo install -o root -g root -m 0644 /vagrant/keepalived/lb01.conf /etc/keepalived/keepalived.conf && sudo systemctl enable keepalived && sudo systemctl restart keepalived"
vagrant ssh lb-02 -c "sudo keepalived -t -f /vagrant/keepalived/lb02.conf && sudo install -o root -g root -m 0644 /vagrant/keepalived/lb02.conf /etc/keepalived/keepalived.conf && sudo systemctl enable keepalived && sudo systemctl restart keepalived"
```

Both instances start in BACKUP state. Unicast VRRP runs between the two private IPs using virtual router ID 51. LB-01 has priority 150 and LB-02 has priority 100. Default preemption returns the VIP to healthy LB-01 after recovery.

The tracking script checks the HAProxy service and an HTTP request through its local frontend. It uses weight 0, two-second intervals, and two consecutive failures/successes for state changes. A failed check puts the instance into FAULT. Because this check goes through the backend pool, failure of all backends also makes both load balancers fail this check.

After allowing time for election, verify that only LB-01 owns the VIP:

```bash
vagrant ssh lb-01 -c "ip -br -4 addr show dev enp0s8"
vagrant ssh lb-02 -c "ip -br -4 addr show dev enp0s8"
curl --noproxy '*' -fsS --max-time 5 http://192.168.56.100/health
```

## Application and service management

Express serves the production dist directory on `0.0.0.0:3000`. GET /health returns HTTP 200 with `OK WEB-01` or `OK WEB-02`. The X-Served-By response header also identifies the web server. Vite's development and preview servers are not used for deployment.

The service runs as the dedicated non-root user reactapp. It is enabled at boot and uses Restart=on-failure. Logs go to the journal.

```bash
./scripts/check-health.sh
vagrant ssh web-01 -c "sudo bash /vagrant/scripts/service-manager.sh status"
vagrant ssh web-01 -c "sudo bash /vagrant/scripts/service-manager.sh restart"
vagrant ssh web-01 -c "bash /vagrant/scripts/server-report.sh"
vagrant ssh web-02 -c "bash /vagrant/scripts/server-report.sh"
vagrant ssh web-01 -c "sudo journalctl -u react-app -n 30 --no-pager"
```

| Script | Purpose |
|---|---|
| setup-web.sh | Install Node.js and build tools; create application user/directories |
| deploy-react.sh | Install dependencies, build and activate a release, restart systemd, check health |
| check-health.sh | Check both backends; exit 0 if both healthy, 1 if either fails, 2 for invalid arguments |
| service-manager.sh | Validate and execute start, stop, restart, or status |
| server-report.sh | Show hostname, addresses, uptime, memory, CPU, and disk usage |
| check-haproxy.sh | Keepalived tracking check for local HAProxy service and HTTP response |

## Failure tests and observed results

The following outcomes were observed during the lab. The exact duration of failover and continuous availability during the shutdown tests were not measured.

| Test | Commands | Observed result |
|---|---|---|
| Stop WEB-01 application | `vagrant ssh web-01 -c "sudo systemctl stop react-app"` | Repeated VIP health requests returned only OK WEB-02 |
| Restore WEB-01 application | `vagrant ssh web-01 -c "sudo systemctl start react-app"` | Both WEB-01 and WEB-02 appeared in VIP responses again |
| Stop primary HAProxy | `vagrant ssh lb-01 -c "sudo systemctl stop haproxy"` | VIP disappeared from LB-01 and appeared on LB-02 |
| Restore primary HAProxy | `vagrant ssh lb-01 -c "sudo systemctl start haproxy"` | VIP returned to LB-01; VIP HTTP request succeeded |
| Shut down primary VM | `vagrant halt lb-01` | LB-02 owned VIP; six requests succeeded across both web backends |
| Recover primary VM | `vagrant up lb-01` | VIP returned to LB-01 only; HTTP request succeeded |
| Reboot web server | `vagrant reload web-01` | react-app was enabled and active without manual start; direct health returned OK WEB-01 |

Allow approximately seven seconds for backend failure detection and five seconds for recovery checks before evaluating steady-state results. VIP transitions may take several seconds.

Capture current-boot service logs and Keepalived transitions:

```bash
vagrant ssh web-01 -c "sudo journalctl -b -u react-app -n 20 --no-pager"
vagrant ssh lb-01 -c "sudo journalctl -u keepalived -n 30 --no-pager"
vagrant ssh lb-02 -c "sudo journalctl -u keepalived -n 30 --no-pager"
```

The observed reboot log included `Started React Application Static Server` and `WEB-01: serving React on port 3000`.

To watch HTTP responses in a separate host terminal during a test:

```bash
while true; do
    date '+%H:%M:%S'
    curl --noproxy '*' -fsS --max-time 2 http://192.168.56.100/health || echo "Request failed"
    sleep 1
done
```

Keepalived also sends requests through each local HAProxy. Therefore the host's visible response sequence need not strictly alternate. WEB-01/WEB-02 identifies the backend; checking interface addresses identifies the VIP owner.

## Troubleshooting

### VIP failed from host but worked inside LB-01

The VIP was correctly assigned and HAProxy listened on 0.0.0.0:80. An HTTP request to the VIP succeeded inside LB-01, while requests from the host were refused. `VBoxManage list dhcpservers` showed an enabled host-only DHCP server using the same address, 192.168.56.100. The host's neighbor entry also pointed to a different MAC from LB-01's private interface.

Disabling and stopping that DHCP server, then flushing the host's VIP neighbor entry using the commands above, resolved the conflict. The host then received OK WEB-01 and its neighbor entry matched LB-01's interface.

### Initial deployment health request was refused

Node had not finished starting when the first request ran. The deployment script's retries subsequently received the expected health response. Persistent failure should be investigated with systemctl status and journalctl.

### Journal permission warning

Non-root status commands may not display all journal entries. Use sudo for full service status and logs.

### Guest Additions version warning

Vagrant reported a Guest Additions version mismatch, but shared folders mounted successfully in this lab. Investigate Guest Additions if shared-folder mounting actually fails.

## Evidence and submission

Add actual screenshots under screenshots/ and link them here using the filenames you save. Screenshots have not been supplied in this README. Include VM status, both app badges, round robin responses, VIP ownership before/after failover and recovery, backend failure/recovery, reboot service logs, and script results. Save relevant command outputs and Keepalived logs alongside the test records.

Commit source, configuration, scripts, this root README, and evidence. Exclude `.vagrant/`, node_modules, dist, local environment secrets, and SSH private keys. The react-app/README.md is the frontend documentation; this root README documents the complete lab.

## Load balancing and high availability

Load balancing distributes traffic between healthy backend servers. High availability maintains an entry point when a component fails. Here HAProxy balances web traffic, while Keepalived transfers the VIP between the two load balancers.

## References

- [Vagrant multi-machine environments](https://developer.hashicorp.com/vagrant/docs/multi-machine)
- [Vagrant VirtualBox networking](https://developer.hashicorp.com/vagrant/docs/providers/virtualbox/networking)
- [Vite static deployment](https://vite.dev/guide/static-deploy)
- [Express static files](https://expressjs.com/en/5x/starter/static-files/)
- [HAProxy health checks](https://www.haproxy.com/documentation/haproxy-configuration-tutorials/reliability/health-checks/)
- [Keepalived configuration](https://www.keepalived.org/documentation/keepalived-conf/)
- [VirtualBox user manual](https://download.virtualbox.org/virtualbox/UserManual.pdf)
