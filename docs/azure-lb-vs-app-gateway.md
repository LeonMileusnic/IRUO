# Choosing Between Load Balancer and Application Gateway

TechSprint uses an **Internal Azure Load Balancer** (Layer 4, TCP/UDP) rather than Application Gateway (Layer 7).

| | Load Balancer | Application Gateway |
|---|---|---|
| Layer | 4 | 7 |
| Fits TechSprint's need (distribute HTTP across 2 Moodle nodes, private frontend, health probes) | Yes, simply | Yes, but with more moving parts |
| URL/host-based routing, TLS termination, WAF | No | Yes |

## Decision

Application Gateway's Layer-7 features (WAF, TLS termination, host/URL routing) would matter for a production Moodle deployment with public HTTPS traffic, but this environment's frontend is private and doesn't need them. The Load Balancer gives the required traffic distribution and health checking with a simpler, cheaper setup.
