DISK="/dev/sdX"

# Zap the GPT and partition table
sgdisk --zap-all $DISK

# Wipe common metadata offsets (0, 1GiB, 10GiB, 100GiB)
dd if=/dev/zero of=$DISK bs=1K count=200 oflag=direct,dsync seek=0
dd if=/dev/zero of=$DISK bs=1K count=200 oflag=direct,dsync seek=$((1 * 1024**2))
dd if=/dev/zero of=$DISK bs=1K count=200 oflag=direct,dsync seek=$((10 * 1024**2))
dd if=/dev/zero of=$DISK bs=1K count=200 oflag=direct,dsync seek=$((100 * 1024**2))

# Discard blocks (for SSDs/flash)
blkdiscard $DISK

# Inform kernel about changes
partprobe $DISK
