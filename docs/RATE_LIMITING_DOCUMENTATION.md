# Cyvora Rate Limiting Documentation

## Existing controls

- `consume_scam_intelligence_quota`: 30 scans per UTC day.
- Threat, URL, and community quota RPCs remain server-side.
- AI provider/global/user/provider daily budget reservations are atomic.
- AI cooldown, duplicate-window, circuit, and concurrent-attempt controls remain.
- Family invites use an atomic five-per-hour family lock.

## Added cloud analysis control

`consume_edge_request_window` reserves a 10-request window for 10 minutes.
The RPC uses a user row lock/advisory context and is granted only to
`service_role`. It applies only to explicit cloud-AI analysis requests.

## Response

Exceeded limits return HTTP 429. Daily boundaries use UTC. Local counters are
not security controls.
