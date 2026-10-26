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

The guests use `ubuntu/jammy64` (Ubuntu 22.04 LTS). The assignment recommends Ubuntu 24.04; this implementation uses 22.04. Host versions observed during setup were Vagrant 2.4.9 and VirtualBox 7.2.20. The guests use Node.js 24 (v24.22.0 observed in the 2026-10-26 verification). Private networking uses `enp0s8`; the NAT adapter provides internet access.

Traffic path: browser → VIP port 80 → active HAProxy → healthy web server port 3000.

All VMs run on one physical host. This provides service and guest-level availability, but does not protect against physical host failure. Brief interruptions during VIP transfer are acceptable.

## Repository layout

- `Vagrantfile`: all four VM definitions, complete guest provisioning, and a host DHCP preflight trigger.
- `react-app/`: React source, npm lockfile, and `server.mjs`.
- `systemd/react-app.service`: web-serving service.
- `haproxy/haproxy.cfg`: shared load-balancing configuration.
- `keepalived/lb01.conf` and `keepalived/lb02.conf`: per-balancer VRRP settings.
- `scripts/`: setup, deployment, monitoring, management, and reporting scripts.
- `verification/`: timestamped VM, HTTP, VIP ownership, and asset checksum evidence.
- `screenshots/`: optional screenshots for submission.

## Installation

Install Vagrant and VirtualBox on the Linux host, enable hardware virtualization, and allow at least 3 GB of guest RAM plus host overhead. Internet access is required to obtain the Ubuntu box, apt packages, Node.js, and npm dependencies. Run commands from the repository root.

### Create and configure the entire lab

```bash
vagrant up --provider=virtualbox
```

On a fresh lab, this one command creates all four VMs and provisions their services. No manual SSH installation steps are required:

1. The host trigger runs `scripts/prepare-host.sh`. It disables/stops only a DHCP server on this lab's 192.168.56.0/24 host-only network if its server address or lease range conflicts with VIP 192.168.56.100. Other networks are left unchanged. If the host-only network does not exist yet, the check is repeated before subsequent VMs start.
2. Vagrant configures each hostname and private address and mounts the repository at `/vagrant`.
3. `scripts/provision.sh` installs basic tools and selects the VM's role from its hostname.
4. On lb-01/lb-02, `scripts/setup-lb.sh` installs HAProxy and Keepalived, checks the expected enp0s8 address, validates and installs the repository configuration and tracking script, and enables/starts both services. Backends need not be running yet for this step to succeed.
5. On web-01/web-02, `scripts/setup-web.sh` installs Node.js 24/build tools and creates the dedicated reactapp account. `scripts/deploy-react.sh` installs locked npm dependencies, builds the unchanged UI, installs the systemd unit, activates the release, enables React, and retries its local health check.

Allow a few seconds after the final deployment for HAProxy backend health checks and VIP election to settle. Then verify:

```bash
vagrant status
bash scripts/check-health.sh
curl --noproxy '*' -fsS http://192.168.56.100/health
```

Open **http://192.168.56.100** to view the application. Vagrant manages SSH keys under the ignored `.vagrant/` directory; no application password is required.

### Stop, start, reconfigure, or rebuild

| Action | Commands | Behavior |
|---|---|---|
| Stop and resume | `vagrant halt`, then `vagrant up` | Retains installed services and application; systemd starts enabled services at boot. |
| Reapply complete setup | `vagrant up --provision` | Runs the host DHCP check and guest provisioning again, including a new React deployment. Use this after source/configuration changes or to retry interrupted provisioning. |
| Reprovision running guests | `vagrant provision` | Runs guest provisioning again; the host before-up trigger is not run by this command. |
| Rebuild from scratch | `vagrant destroy`, then `vagrant up` | Deletes the guests and their local data, then creates and fully provisions replacement VMs using this repository. |

Provisioning is safe to rerun: packages and users are reused, configuration is validated before replacing installed service configs, and services remain enabled. An already-installed Node.js 24/npm is reused. An unchanged Keepalived config does not cause an unnecessary service restart. React is rebuilt/restarted on explicit reprovisioning; deployment is not zero downtime.

### Configuration details

Both load balancers listen on IPv4 port 80. HAProxy explicitly uses round robin, with no sticky-session configuration. It checks backend GET `/health` for HTTP 200 every two seconds; three failed checks remove a backend and two successful checks restore it.

[Browser reload investigation and request evidence (2026-10-26)](verification/browser-investigation-2026-10-26.md) traces actual Chrome reloads against HAProxy logs. The badge identifies the HTML backend; asset and favicon requests consume intervening round-robin turns, so page badges need not alternate. Dynamic HTML remains `no-store`; identical fingerprinted JS/CSS assets now use a one-year immutable cache policy. Use sequential `/health` requests with other traffic quiet to demonstrate one-request round robin.

Keepalived uses enp0s8, unicast peers 192.168.56.10/11, router ID 51, and VIP 192.168.56.100/24. Both start as BACKUP; priorities 150/100 and default preemption prefer healthy lb-01. Its root-owned tracking script requires an active HAProxy service and exactly HTTP 200 from HAProxy's local `/haproxy-health` monitor. Backend detection delays therefore do not declare a healthy load balancer faulty. If all backends fail, the configured proxy retains its VIP and serves HTTP 503 for application requests; this scenario was not failure-tested in the earlier verification.

The frontend reads `window.__SERVER_NAME__ || 'LOCAL DEV'`; Express injects the uppercase hostname into HTML at runtime. Both servers build identical JS/CSS assets. Do not build a different `VITE_SERVER_NAME` per VM: different hashed assets can cause blank pages when requests reach different backends.

Deployment copies `react-app/` into a new `/opt/react-app/releases` directory, excluding host node_modules/dist, builds it, and switches `/opt/react-app/current` only after a successful build. Old releases remain available; automatic rollback is not implemented. The targeted web-01 paravirtualization workaround remains in Vagrantfile, as documented in the earlier verification.

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
| prepare-host.sh | Host-only DHCP preflight before vagrant up; scope changes to VIP conflicts on the lab subnet |
| provision.sh | Complete guest bootstrap; install common tools and dispatch by hostname |
| setup-lb.sh | Install, validate, configure, enable, and start HAProxy/Keepalived |
| setup-web.sh | Install Node.js and build tools; create application user/directories |
| deploy-react.sh | Install dependencies, build and activate a release, restart systemd, check health |
| check-health.sh | Check both backends; exit 0 if both healthy, 1 if either fails, 2 for invalid arguments |
| service-manager.sh | Validate and execute start, stop, restart, or status |
| server-report.sh | Show hostname, addresses, uptime, memory, CPU, and disk usage |
| check-haproxy.sh | Keepalived tracking check for local HAProxy service and HTTP response |

## Automatic provisioning verification — 2026-10-26

This was tested against a genuinely empty VM state: `vagrant status` reported all four guests as `not created` before the command. `vagrant up --provision` then imported, created, and fully provisioned all four guests successfully (exit 0). No guest installation commands were run manually. On newly created guests, ordinary `vagrant up` runs this same provisioner automatically; `--provision` also forces it for existing guests.

[Fresh-build and reprovisioning verification output](verification/provisioning-2026-10-26.txt) records the installed configuration, process users, service states, VIP ownership, round-robin responses, and frontend hashes.

| Check | Observed result |
|---|---|
| Fresh guest setup | Both load balancers installed/configured HAProxy and Keepalived; both web servers installed Node.js v24.22.1, created reactapp, built/deployed React, and passed deployment health checks. |
| Repository versus guests | HAProxy, per-node Keepalived configuration, tracking script, React unit, Express server, React source, and lockfiles matched. |
| Running services | HAProxy/Keepalived active and enabled on both balancers; React active/enabled on both web VMs and running as non-root reactapp. |
| VIP and HTTP | Only lb-01 owned 192.168.56.100 after election; 12/12 VIP health requests returned HTTP 200 across both backends. |
| Round robin and UI assets | 20/20 requests through each balancer returned HTTP 200 and alternated across both web servers in these samples. HTML runtime names were correct. Cross-server asset requests returned HTTP 200 with matching checksums; compiled JS/CSS hashes were unchanged from the original working UI. |
| Host DHCP guard | The Vagrant host trigger ran successfully. vboxnet0 DHCP remained disabled. Five fixture tests passed for direct VIP conflict, a lease range covering the VIP, an already-disabled conflict, a safe range, and unrelated networks/no DHCP servers. |
| Repeat provisioning | `vagrant provision lb-01 web-01` completed successfully (exit 0), covering both roles. Existing reactapp and Node.js 24/npm were reused; a new React release was deployed and passed its health check. |
| Static checks | Vagrant validation, Ruby syntax, all shell syntax checks, five host-guard tests, and Git whitespace checks passed. Original Vagrantfile comments were verified intact and in order. |

The earlier controlled failure tests below were not repeated as part of this fresh-install check. Bootstrap still requires internet/package registry access. npm's pre-existing body-parser advisory and the unrelated snapd unit-verification warning remain documented below.

To run the host-guard tests without changing VirtualBox networking:

```bash
python3 -m unittest discover -s tests -v
```

## Earlier configuration and failure-test verification — 2026-10-26

This section records the audit performed before automatic provisioning was added and before the subsequent fresh VM creation. Its failure-test evidence is retained as a historical test record.

**Verdict:** round robin, backend failover, load-balancer failover/failback, and automatic service startup passed the observed tests after the fixes below. Brief request failures occurred during health-check detection and VIP transfer; this is not a zero-interruption result.

[Timestamped verification output](verification/2026-10-26.txt) records HTTP status/body samples, VIP ownership, boot IDs, service states, configuration comparisons, and checksums. Times use Asia/Phnom_Penh (UTC+07:00); guest journal entries use UTC. The log retains the initial failure and later successful retests. Host versions were Vagrant 2.4.9 and VirtualBox 7.2.22r175245.

All four existing VMs initially reported `aborted`. They were started with `vagrant up --no-provision`; none were destroyed or recreated. No AGENTS.md was found in the repository or checked ancestor directories. No commit or push was performed.

| Check | Actual result |
|---|---|
| Syntax and configuration validation | Vagrant validation, Ruby syntax, every shell script's syntax, Node server syntax, frontend lint/build, HAProxy validation, Keepalived validation, and VM-side systemd unit verification passed. Unit verification also printed an unrelated installed snapd `RestartMode` warning. |
| Installed configuration versus repository | Final `cmp` checks passed for HAProxy, each Keepalived config, the installed tracking script, React systemd unit, Express server, and npm lockfile. React source directory comparisons passed on both web VMs. Shared setup/deployment/management scripts run directly from `/vagrant/scripts`. |
| HAProxy listener and backends | Both balancers listened on IPv4 port 80. Backends were 192.168.56.20:3000 and 192.168.56.21:3000. |
| Algorithm and health checks | Explicit `balance roundrobin`, no cookie/stick-table persistence. Backend GET `/health` requires HTTP 200, with `inter 2s fall 3 rise 2`. |
| Round robin observations | Twenty direct `/health` requests to each balancer all returned HTTP 200 and alternated between WEB-01 and WEB-02 in these samples. |
| VRRP and VIP | Both use REACT_VIP, router ID 51, enp0s8, 1-second advertisements, reciprocal unicast peers, and VIP 192.168.56.100/24. Priorities are 150/100; default preemption restored lb-01 ownership. Final settled ownership was lb-01 only. |
| HAProxy tracking | Active service plus exactly HTTP 200 from local `/haproxy-health`; weight 0 and init_fail remain enabled. Stopping primary HAProxy caused VIP transfer. |
| Dedicated React user and boot enablement | Both Node processes ran as reactapp (UID 997), with react-app enabled/active. HAProxy and Keepalived were enabled/active on both balancers. All services started during initial VM boot; lb-01 services also started after its restart. |
| Deployment directory | Both deployments ran successfully from `/vagrant/scripts/deploy-react.sh`, using the renamed `/vagrant/react-app` source. Startup retry succeeded after the initial connection-refused response. |
| Runtime hostname and shared assets | Both HTML responses contained their own `window.__SERVER_NAME__` value. All five dist files had matching filenames/checksums. Every HTML-referenced JS, CSS, and favicon URL returned HTTP 200 and identical bytes from both servers. |
| DHCP conflict | `HostInterfaceNetworking-vboxnet0` still has configured DHCP IP 192.168.56.100, but `Enabled: No`. VIP HTTP requests succeeded from the host. No VirtualBox networks were modified. |
| Git credentials | No private-key content, password assignments, or key/secret-like tracked paths were detected in the current tracked files. `.vagrant/` is excluded. This was not a full Git-history credential audit. |
| Utility scripts | check-health, service-manager status, and server-report ran successfully on both web VMs after restoration. |

Shared frontend hashes observed before deployment and again after all tests:

| File | SHA-256 on both web servers |
|---|---|
| assets/index-B1XLAvFb.js | `8b79da582f56aefb5e41956182366ed0ea9cf216aadade9cef3503c03c2343f3` |
| assets/index-CTIQDBKY.css | `3efb148b2f89bc088fbfd9c0759141fb8802b3366e5192ed29e9c5421ec53ad2` |

### Controlled failure tests

Each component was restored and recovery checked before the next test. Steady-state checks used twelve VIP `/health` requests. Monitoring sampled HTTP with a two-second request timeout and queried both load balancer interfaces; SSH queries and HTTP samples are not simultaneous. Timing estimates are approximate, and sampling does not prove continuous availability between requests.

| Test | Actual result after correction |
|---|---|
| Stop and restore React on web-01 | Stopped service was directly unreachable. After detection, 12/12 VIP requests returned HTTP 200 from WEB-02. Restore returned both backends to the pool; VIP stayed on lb-01. One sampled timeout occurred during detection in the corrected-config rerun. |
| Stop and restore React on web-02 | Stopped service was directly unreachable. After detection, 12/12 VIP requests returned HTTP 200 from WEB-01. Restore returned both backends; VIP stayed on lb-01. One sampled timeout occurred during detection in the corrected-config rerun. |
| Stop and restore HAProxy on lb-01 | VIP moved to lb-02 in roughly 4–5 seconds; settled HTTP was 12/12 successful across both backends. Two early connection-refused samples occurred. Restoring HAProxy returned the VIP to lb-01 in roughly 8 seconds, with 12/12 successful settled responses. |
| Shut down and restart lb-01 | `vagrant halt lb-01` completed; lb-01 became unreachable and lb-02 owned the VIP. Settled HTTP was 12/12 successful across both web servers. `vagrant up lb-01 --no-provision` started HAProxy/Keepalived automatically and returned the VIP to lb-01. All sampled shutdown/restart HTTP requests in the corrected-config run succeeded. |
| Reboot web-01 and verify automatic React startup | An initial reboot passed, but a later reboot hung during kernel boot. Testing stopped for recovery. After the targeted Vagrantfile workaround, two consecutive `sudo reboot` tests passed: each produced a new boot ID and enabled/active React without manually starting it. WEB-02 served during detection/reboot, both backends returned afterward, and lb-01 retained the VIP. Two sampled timeouts occurred during each post-workaround reboot's backend detection window. |

Allow several seconds for failure/recovery detection before judging settled results. Each HAProxy has independent round-robin state. Browser refreshes request HTML and multiple assets, so displayed server names need not alternate. Keepalived's monitor requests are now answered locally without consuming backend turns.

### Problems found and changes made

- The old tracking request went through the application backend pool. During the first web reboot, its timeouts falsely put healthy lb-01 into FAULT and briefly moved the VIP. Added HAProxy's dedicated `/haproxy-health` monitor and changed check-haproxy.sh to require exactly HTTP 200 while bypassing proxy variables. Validated before installation on standby, then primary. Repeated backend tests and subsequent reboots retained primary VIP ownership.
- A later web-01 warm reboot stalled during early kernel boot, before networking or systemd. The [captured console](verification/web01-kernel-boot-hang.png) shows abnormally large kernel timestamps. A clock-interface issue is suspected from this evidence; an upstream root cause was not established. Added a targeted `minimal` paravirtualization setting for web-01 to Vagrantfile, then recovered the same VM by power cycling it. VirtualBox confirmed the effective provider, the guest used `tsc`, and two consecutive warm reboots passed. All original Vagrantfile comments remain verbatim and in order. Other VMs retain their existing provider setting. Oracle documents the [paravirtualization providers](https://docs.oracle.com/en/virtualization/virtualbox/7.2/user/AdvancedTopics.html); this workaround's observed success is local test evidence, not an upstream guarantee.
- README deployment instructions and the App.jsx comment still described per-server frontend builds. Corrected them to describe runtime hostname injection. Redeployed the repository source to both web VMs. The existing UI's compiled JS/CSS names and checksums remained unchanged.
- Deployment's npm audit reported one high-severity advisory in body-parser 2.3.0 ([GHSA-27r3-jxmh-p828](https://github.com/advisories/GHSA-27r3-jxmh-p828)). Dependencies were not upgraded during these configuration fixes; this remains a separate finding.

### Final state and verification limits

| VM | Final services | VIP |
|---|---|---|
| lb-01 | HAProxy active/enabled; Keepalived active/enabled | 192.168.56.100, sole settled owner |
| lb-02 | HAProxy active/enabled; Keepalived active/enabled | None |
| web-01 | react-app active/enabled, running as reactapp | None |
| web-02 | react-app active/enabled, running as reactapp | None |

All requested checks were completed, including recovery and retesting after the boot failure. No automated browser-rendering check, all-backends-down test, long-duration reboot soak, or physical-host failure test was performed. The intermittent boot issue passed two post-workaround reboot samples; long-term reliability is not established by those two samples. Final VIP HTTP checks returned 12/12 HTTP 200 responses across both web servers. All four VMs were left running.

## Troubleshooting

### VIP failed from host but worked inside LB-01

The VIP was correctly assigned and HAProxy listened on 0.0.0.0:80. An HTTP request to the VIP succeeded inside LB-01, while requests from the host were refused. `VBoxManage list dhcpservers` showed an enabled host-only DHCP server using the same address, 192.168.56.100. The host's neighbor entry also pointed to a different MAC from LB-01's private interface.

Disabling and stopping that DHCP server, then flushing the host's VIP neighbor entry using the commands above, resolved the conflict. On 2026-10-26, `VBoxManage list dhcpservers` still showed `Enabled: No` for `HostInterfaceNetworking-vboxnet0`. Its configured DHCP address remains 192.168.56.100, but it is disabled; do not re-enable it at that address. No VirtualBox network settings were changed during this verification.

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
