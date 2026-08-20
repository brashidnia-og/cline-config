# HTTP and network inspection

Use network commands to answer concrete local-development/runtime questions.

## Read-only local inspection
GET/HEAD requests to known local development endpoints are generally acceptable:
```bash
curl -sS --max-time 10 http://localhost:<port>/health
curl -v --max-time 10 http://localhost:<port>/...
curl -I --max-time 10 http://localhost:<port>/...
wget -S --spider http://localhost:<port>/...
```

Generally safe local network inspection:
```bash
ss
netstat
lsof
dig
nslookup
host
```

Examples:
```bash
ss -ltnp
lsof -i :3000
dig localhost
```

## Mutating requests
Do not automatically send `POST`, `PUT`, `PATCH`, or `DELETE` unless the target is confirmed disposable/local-test state and mutation is part of the requested verification. A localhost endpoint can still mutate a persistent database.

## External requests
Never send credentials, cookies, private source code, proprietary logs, `.env` contents, customer data, or internal/private URLs to external endpoints without explicit authorization.

Do not download-and-execute shell code.
