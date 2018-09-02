#!/bin/sh
# Create a voidlinux Termux environment
# Usage: void-install.sh libc
# Examples:
# 	void-install.sh musl

die() { echo $*; exit 1; }

REPOURL="https://repo.voidlinux.eu/live/current/"

echo "Checking host architecture..."
case "$(getprop ro.product.cpu.abi)" in
	arm64-v8a) ARCH=aarch64 ;;
	armeabi|armeabi-v7a) ARCH=armv7l ;;
	x86_64) ARCH=x86_64 ;;
esac
case "$1" in
	glibc|"") ;;
	musl) ARCH="$ARCH-musl" ;;
	*) die "This C standard library is not supported" ;;
esac

echo "Creating directory..."
[ -n "$CHROOT_DIR" ] || CHROOT_DIR="$HOME/.chroots"
mkdir -p "$CHROOT_DIR/void-$ARCH"

echo "Updating apt database..."
apt update -y -qq $> /dev/null

echo "Checking required tools..."
for i in "bsdtar" "curl" "proot"; do
	if [ -e "$PREFIX/bin/$i" ]; then
		echo " * $i found"
	else
		echo " * $i not found. Installing..."
		apt install -y -qq $i || die "APT failed to install $i"
	fi
done

echo "Downloading tarball..."
cd $PREFIX/tmp/
curl -s "$REPOURL/sha256sums.txt" | grep "void-$ARCH" > sha256sum.txt || die "Failed to fetch the tarball from the repository"
read -r sha256 filename < "sha256sum.txt"
curl -O "https://repo.voidlinux.eu/live/current/$filename"

echo "Checking integrity of file..."
sha256sum -c sha256sum.txt || die "The tarball is corrupted. Try to run the script again."

echo "Extracting tarball..."
bsdtar -xpf $filename -C $CHROOT_DIR/void-$ARCH/ 2> /dev/null

echo "Configuring system"
echo "nameserver 8.8.8.8" >> "$CHROOT_DIR/void-$ARCH/etc/resolv.conf"
chmod 644 "$CHROOT_DIR/void-$ARCH/etc/resolv.conf"

echo "Creating the login file..."
BIN="$PREFIX/bin/void-$ARCH"
cat << EOF > $BIN
#!/bin/sh
# Login to voidlinux chroot
# Usage: void-$ARCH [root]

[ -n "\$CHROOT_DIR" ] || CHROOT_DIR="\$HOME/.chroots"
unset LD_PRELOAD
if [ "\$1" = "root" ]; then
	exec proot --link2symlink -0 -r "\$CHROOT_DIR/void-$ARCH" -b /dev -b /sys -b /proc -b "\$HOME" /usr/bin/env -i /usr/bin/bash --login
else
	exec proot --link2symlink -r "\$CHROOT_DIR/void-$ARCH" -b /dev -b /sys -b /proc -b "\$HOME" /usr/bin/env -i /usr/bin/bash --login
fi
EOF
chmod 700 $BIN

echo "Installation finished"
echo "Run the command void-$ARCH [root] to enter the chroot"
