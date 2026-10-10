# OSINT Laptop Build

Setup files for an Ubuntu 26.04 laptop used for OSINT investigations.

## Contents

| File | Purpose |
| --- | --- |
| `osint-homepage.html` | Local browser homepage: multi-engine search, ~75 categorised OSINT links, link filter, UTC/local clocks, OPSEC reminder and a local scratchpad. No external dependencies. |
| `setup-osint-laptop.sh` | Installs Google Chrome and LibreOffice, copies the homepage to `/opt/osint/`, and sets it as the Chrome and Firefox homepage via system policy. |

## Usage

```bash
git clone git@github.com:northvein/<repo>.git
cd <repo>
sudo ./setup-osint-laptop.sh
```

Restart the browsers afterwards and confirm the policy at `chrome://policy`.

## Notes

- Chrome is amd64-only on Linux; the script exits on other architectures.
- The homepage is set as a *managed* Chrome policy, so Chrome shows "Managed by your organization" and users can't change it. Change `policies/managed` to `policies/recommended` in the script to make it a default instead.
- To add links, edit the `RESOURCES` array in `osint-homepage.html`, then re-run the script (or copy the file to `/opt/osint/`).
