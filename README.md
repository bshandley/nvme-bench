# nvme-bench

A beautiful, modern command-line tool for benchmarking NVMe SSDs on Linux. Works with any NVMe drive from any manufacturer.

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Platform](https://img.shields.io/badge/platform-Linux-lightgrey.svg)
![Shell](https://img.shields.io/badge/shell-bash-green.svg)

## ✨ Features

- 🎨 **Modern, colorful UI** with clean output
- 🚀 **Universal compatibility** - works with any NVMe drive
- 📊 **Comprehensive testing** - Sequential and Random 4K performance
- 🎯 **Smart detection** - Automatically detects PCIe generation (Gen 3/4/5)
- 💡 **Intelligent analysis** - Compares results against expected speeds
- 🛡️ **Safe** - Tests on mounted filesystems without data loss
- ⚡ **Fast** - Complete benchmark in ~2 minutes

## 🖼️ Screenshot

The tool provides clear, color-coded results showing:
- Sequential Read/Write speeds
- Random 4K Read/Write IOPS
- Performance percentage vs expected speeds
- PCIe generation and bandwidth info

## 📋 Requirements

- Linux (tested on Arch, Ubuntu, Debian)
- Root/sudo access
- `fio` (Flexible I/O Tester)
- `jq` (JSON processor)

## 🚀 Installation

### Arch Linux
```bash
sudo pacman -S fio jq
```

### Ubuntu/Debian
```bash
sudo apt install fio jq
```

### Download Script
```bash
wget https://raw.githubusercontent.com/YOUR_USERNAME/nvme-bench/main/nvme_benchmark.sh
chmod +x nvme_benchmark.sh
```

Or clone the entire repository:
```bash
git clone https://github.com/YOUR_USERNAME/nvme-bench.git
cd nvme-bench
chmod +x nvme_benchmark.sh
```

## 💻 Usage

Simply run with sudo:

```bash
sudo ./nvme_benchmark.sh
```

The script will:
1. Detect all NVMe drives in your system
2. Show PCIe generation and drive details
3. Let you select which drive and partition to test
4. Run comprehensive benchmarks (~2 minutes)
5. Display color-coded results with performance analysis

## 📊 What It Tests

### Sequential Performance
- **Sequential Read** - Large file read speeds (1MB blocks)
- **Sequential Write** - Large file write speeds (1MB blocks)

### Random Performance  
- **Random 4K Read** - Small random read operations (typical of OS/database workloads)
- **Random 4K Write** - Small random write operations

## 🎯 Supported Drives

The tool automatically recognizes and provides expected speeds for:

### Samsung
- 9100 PRO (PCIe Gen 5) - up to 14,800 MB/s read
- 990 PRO (PCIe Gen 4) - up to 7,450 MB/s read
- 980 PRO (PCIe Gen 4) - up to 7,000 MB/s read
- 970 EVO/PRO (PCIe Gen 3)

### Other Brands
Works with any NVMe drive! Expected speeds are estimated based on PCIe generation:
- **Gen 5** - ~12,000 MB/s read, ~10,000 MB/s write
- **Gen 4** - ~7,000 MB/s read, ~5,000 MB/s write
- **Gen 3** - ~3,500 MB/s read, ~2,500 MB/s write

## ⚠️ Important Notes

### Performance Factors

Your results may be lower than expected due to:

1. **LVM/RAID overhead** - Software RAID or LVM adds 20-50% overhead
2. **Filesystem journaling** - ext4, btrfs add overhead vs raw device
3. **Drive fill level** - Performance drops when drive is >70% full
4. **Thermal throttling** - Drive may throttle if it gets too hot
5. **Background activity** - System processes can impact results

### For Best Results

- Test on a partition with >50GB free space
- Close unnecessary applications
- Ensure adequate cooling
- Test on a partition without LVM if possible
- Run multiple times and average the results

## 🔧 Technical Details

### Test Parameters

**Sequential Tests:**
- Block size: 1MB
- Queue depth: 32
- Jobs: 1
- Direct I/O: Yes

**Random 4K Tests:**
- Block size: 4KB
- Queue depth: 32
- Jobs: 4
- Test duration: 30 seconds
- Direct I/O: Yes

### Safety

The script:
- ✅ Tests on mounted filesystems (safe)
- ✅ Creates temporary test files
- ✅ Automatically cleans up after testing
- ✅ Never writes to raw devices
- ✅ Requires explicit user selection

## 🤝 Contributing

Contributions are welcome! Please feel free to:

1. Report bugs
2. Suggest new features
3. Add support for more drive models
4. Improve the documentation
5. Submit pull requests

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Built using [fio](https://github.com/axboe/fio) - Flexible I/O Tester
- Inspired by the need for a simple, beautiful NVMe benchmark tool
- Thanks to the Linux community for excellent NVMe support

## 📬 Support

If you encounter issues:

1. Check that `fio` and `jq` are installed
2. Ensure you're running with sudo
3. Verify the drive is actually NVMe (`ls /dev/nvme*`)
4. Open an issue on GitHub: `github.com/YOUR_USERNAME/nvme-bench/issues`

## ⭐ Star This Repo

If you find this tool useful, please consider giving it a star on GitHub!

**Repository:** `github.com/YOUR_USERNAME/nvme-bench`

---

Made with ❤️ for the Linux community
