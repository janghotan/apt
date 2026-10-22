# rewind APT repository

Signed APT repository for [rewind](https://github.com/janghotan/rewind),
served from GitHub Pages at <https://janghotan.github.io/apt/>.

## Install

```bash
sudo install -d -m 0755 /etc/apt/keyrings
curl -fsSL https://janghotan.github.io/apt/rewind-archive-keyring.gpg \
  | sudo tee /etc/apt/keyrings/rewind.gpg >/dev/null

echo "deb [signed-by=/etc/apt/keyrings/rewind.gpg] https://janghotan.github.io/apt stable main" \
  | sudo tee /etc/apt/sources.list.d/rewind.list

sudo apt update
sudo apt install rewind
```

Supported architectures: `amd64`, `arm64`. Packages carry the statically
linked musl binary, so there are no runtime dependencies.

## Publishing a new version

The signing key must be available to GPG (default `GNUPGHOME`, or import it
from CI secrets):

```bash
GNUPGHOME=/path/to/keyring ./publish.sh ../rewind_0.2.0-1_amd64.deb ../rewind_0.2.0-1_arm64.deb
```

`publish.sh` copies the packages into `pool/`, regenerates `Packages` for both
architectures, rebuilds and signs `Release`, and refreshes `InRelease` and the
keyring. Commit and push the result to `gh-pages`.

## Layout

```
dists/stable/{InRelease,Release,Release.gpg}
dists/stable/main/binary-{amd64,arm64}/Packages{,.gz}
pool/main/r/rewind/*.deb
rewind-archive-keyring.{gpg,asc}
```
