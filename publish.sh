#!/usr/bin/env bash
# Add one or more .deb files to this APT repository and re-sign the metadata.
#
# Usage: ./publish.sh <package.deb> [more.deb ...]
#
# Requires dpkg-dev, apt-utils, and a GPG secret key in GNUPGHOME.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

if [[ $# -eq 0 ]]; then
    echo "usage: $0 <package.deb> [more.deb ...]" >&2
    exit 2
fi

gpg --list-secret-keys >/dev/null 2>&1 || {
    echo "no GPG secret key available; set GNUPGHOME or import the archive key" >&2
    exit 1
}

mkdir -p pool/main/r/rewind dists/stable/main/binary-amd64 dists/stable/main/binary-arm64

for deb in "$@"; do
    [[ -f $deb ]] || { echo "not a file: $deb" >&2; exit 1; }
    arch=$(dpkg-deb -f "$deb" Architecture)
    case "$arch" in
        amd64 | arm64) ;;
        *) echo "unsupported architecture $arch in $deb" >&2; exit 1 ;;
    esac
    install -m 0644 "$deb" "pool/main/r/rewind/$(basename "$deb")"
    echo "added $(basename "$deb")"
done

for arch in amd64 arm64; do
    dpkg-scanpackages --multiversion --arch "$arch" pool /dev/null \
        > "dists/stable/main/binary-$arch/Packages" 2>/dev/null
    gzip -9kf "dists/stable/main/binary-$arch/Packages"
done

apt-ftparchive \
    -o APT::FTPArchive::Release::Origin="rewind" \
    -o APT::FTPArchive::Release::Label="rewind" \
    -o APT::FTPArchive::Release::Suite="stable" \
    -o APT::FTPArchive::Release::Codename="stable" \
    -o APT::FTPArchive::Release::Architectures="amd64 arm64" \
    -o APT::FTPArchive::Release::Components="main" \
    -o APT::FTPArchive::Release::Description="rewind - universal undo for destructive shell commands" \
    release dists/stable > Release.tmp

mv Release.tmp dists/stable/Release
gpg --batch --yes --clearsign -o dists/stable/InRelease dists/stable/Release
gpg --batch --yes --armor --detach-sign -o dists/stable/Release.gpg dists/stable/Release
gpg --batch --yes --export > rewind-archive-keyring.gpg
gpg --batch --yes --armor --export > rewind-archive-keyring.asc

latest=$(for deb in pool/main/r/rewind/*.deb; do
    dpkg-deb -f "$deb" Version
done | sort -Vu | tail -1)
if [[ -f index.html && -n ${latest:-} ]]; then
    sed -i -E "s#(<!--latest-->)[^<]*(<!--/latest-->)#\\1${latest}\\2#" index.html
fi

echo
echo "Repository updated and signed."
echo "Published packages:"
grep -hE '^(Package|Version|Architecture):' dists/stable/main/binary-*/Packages | paste - - -
