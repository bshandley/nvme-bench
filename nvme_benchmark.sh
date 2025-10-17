#!/bin/bash

# nvme-bench - Universal NVMe Speed Test Script
# Works with any NVMe drive - Samsung, WD, Crucial, Kingston, etc.
# Repository: https://github.com/YOUR_USERNAME/nvme-bench
# Modern UI with colorful output and progress bars

set -e

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# Unicode symbols
CHECK="✓"
CROSS="✗"
WARN="⚠"
ROCKET="🚀"
DISK="💾"
CHART="📊"

# Banner
print_banner() {
    clear
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${WHITE}                        nvme-bench${NC}"
    echo -e "${GRAY}            Universal NVMe Benchmark Tool for Linux${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}\n"
}

# Section header
print_section() {
    echo -e "\n${BOLD}${CYAN}▶ $1${NC}"
    echo -e "${CYAN}───────────────────────────────────────────────────────────────${NC}"
}

# Check root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}${CROSS} Please run as root (sudo)${NC}"
    exit 1
fi

# Check for required tools
if ! command -v fio &> /dev/null; then
    echo -e "${RED}${CROSS} fio is not installed${NC}"
    echo -e "Install with: ${BOLD}sudo pacman -S fio${NC} (Arch) or ${BOLD}sudo apt install fio${NC} (Debian/Ubuntu)"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo -e "${RED}${CROSS} jq is not installed${NC}"
    echo -e "Install with: ${BOLD}sudo pacman -S jq${NC} (Arch) or ${BOLD}sudo apt install jq${NC} (Debian/Ubuntu)"
    exit 1
fi

print_banner

# Detect NVMe drives
print_section "Available NVMe Drives"
echo ""

NVME_COUNT=0
declare -a NVME_DEVICES
declare -a NVME_MODELS

for nvme_dev in /dev/nvme[0-9]*n1; do
    if [ -b "$nvme_dev" ]; then
        NVME_COUNT=$((NVME_COUNT + 1))
        NVME_DEVICES+=("$nvme_dev")
        
        # Get model name
        if command -v nvme &> /dev/null; then
            MODEL=$(nvme id-ctrl "$nvme_dev" 2>/dev/null | grep "^mn" | cut -d: -f2 | xargs || echo "Unknown Model")
        else
            MODEL=$(cat /sys/block/$(basename $nvme_dev)/device/model 2>/dev/null | xargs || echo "Unknown Model")
        fi
        NVME_MODELS+=("$MODEL")
        
        # Get size
        SIZE=$(lsblk -b -d -n -o SIZE "$nvme_dev" 2>/dev/null | awk '{printf "%.0f GB", $1/1024/1024/1024}')
        
        # Get PCIe info
        NVME_NUM=$(echo $nvme_dev | grep -o 'nvme[0-9]*' | grep -o '[0-9]*')
        PCI_ADDR=$(readlink -f /sys/class/nvme/nvme${NVME_NUM}/device 2>/dev/null)
        
        if [ -f "${PCI_ADDR}/current_link_speed" ]; then
            PCIE_SPEED=$(cat ${PCI_ADDR}/current_link_speed 2>/dev/null)
            PCIE_WIDTH=$(cat ${PCI_ADDR}/current_link_width 2>/dev/null)
            
            if echo "$PCIE_SPEED" | grep -q "32.0 GT/s"; then
                PCIE_BADGE="${GREEN}${ROCKET} Gen 5${NC}"
                PCIE_GEN="5"
            elif echo "$PCIE_SPEED" | grep -q "16.0 GT/s"; then
                PCIE_BADGE="${YELLOW}Gen 4${NC}"
                PCIE_GEN="4"
            elif echo "$PCIE_SPEED" | grep -q "8.0 GT/s"; then
                PCIE_BADGE="${GRAY}Gen 3${NC}"
                PCIE_GEN="3"
            else
                PCIE_BADGE="${GRAY}Unknown${NC}"
                PCIE_GEN="?"
            fi
        else
            PCIE_BADGE="${GRAY}Unknown${NC}"
            PCIE_GEN="?"
        fi
        
        echo -e "  ${CYAN}[$NVME_COUNT]${NC} ${BOLD}${WHITE}$nvme_dev${NC}"
        echo -e "      ${DISK} Model: ${MODEL}"
        echo -e "      📏 Capacity: ${SIZE}"
        echo -e "      ${PCIE_BADGE} (x${PCIE_WIDTH})"
        echo ""
    fi
done

if [ $NVME_COUNT -eq 0 ]; then
    echo -e "${RED}${CROSS} No NVMe drives found!${NC}"
    exit 1
fi

# Select drive
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
read -p "$(echo -e ${BOLD}Select drive to test [1-$NVME_COUNT]:${NC} )" SELECTION

if ! [[ "$SELECTION" =~ ^[0-9]+$ ]] || [ "$SELECTION" -lt 1 ] || [ "$SELECTION" -gt $NVME_COUNT ]; then
    echo -e "${RED}${CROSS} Invalid selection!${NC}"
    exit 1
fi

SELECTED_INDEX=$((SELECTION - 1))
NVME_BASE="${NVME_DEVICES[$SELECTED_INDEX]}"
SELECTED_MODEL="${NVME_MODELS[$SELECTED_INDEX]}"

echo -e "\n${GREEN}${CHECK}${NC} Selected: ${BOLD}${WHITE}$NVME_BASE${NC}"
echo -e "   ${GRAY}$SELECTED_MODEL${NC}"

# Get PCIe gen for selected drive
NVME_NUM=$(echo $NVME_BASE | grep -o 'nvme[0-9]*' | grep -o '[0-9]*')
PCI_ADDR=$(readlink -f /sys/class/nvme/nvme${NVME_NUM}/device 2>/dev/null)
if [ -f "${PCI_ADDR}/current_link_speed" ]; then
    LINK_SPEED=$(cat ${PCI_ADDR}/current_link_speed)
    LINK_WIDTH=$(cat ${PCI_ADDR}/current_link_width)
    
    if echo "$LINK_SPEED" | grep -q "32.0 GT/s"; then
        GEN="5"
    elif echo "$LINK_SPEED" | grep -q "16.0 GT/s"; then
        GEN="4"
    elif echo "$LINK_SPEED" | grep -q "8.0 GT/s"; then
        GEN="3"
    else
        GEN="?"
    fi
fi

# Select partition
print_section "Available Partitions"
echo ""

MOUNT_POINTS=$(lsblk -n -o NAME,MOUNTPOINT "$NVME_BASE" 2>/dev/null | grep -v "^$(basename $NVME_BASE)" | awk '{if ($2) print $2}')

if [ -z "$MOUNT_POINTS" ]; then
    echo -e "${RED}${CROSS} No mounted partitions found on this drive!${NC}"
    exit 1
fi

PART_NUM=0
declare -a PART_MOUNTS
declare -a PART_AVAIL

while IFS= read -r mount; do
    AVAIL=$(df -BG "$mount" 2>/dev/null | tail -1 | awk '{print $4}' | sed 's/G//')
    if [ ! -z "$AVAIL" ]; then
        PART_NUM=$((PART_NUM + 1))
        PART_MOUNTS+=("$mount")
        PART_AVAIL+=("$AVAIL")
        
        if [ $AVAIL -ge 50 ]; then
            SPACE_COLOR=$GREEN
        elif [ $AVAIL -ge 15 ]; then
            SPACE_COLOR=$YELLOW
        else
            SPACE_COLOR=$RED
        fi
        
        echo -e "  ${CYAN}[$PART_NUM]${NC} ${WHITE}${mount}${NC} - ${SPACE_COLOR}${AVAIL}GB free${NC}"
    fi
done <<< "$MOUNT_POINTS"

echo ""
read -p "$(echo -e ${BOLD}Select partition [1-$PART_NUM] or press Enter for largest:${NC} )" PART_SELECTION

if [ -z "$PART_SELECTION" ]; then
    MAX_SPACE=0
    MAX_INDEX=0
    for i in "${!PART_AVAIL[@]}"; do
        if [ "${PART_AVAIL[$i]}" -gt "$MAX_SPACE" ]; then
            MAX_SPACE="${PART_AVAIL[$i]}"
            MAX_INDEX=$i
        fi
    done
    MOUNT_POINT="${PART_MOUNTS[$MAX_INDEX]}"
    echo -e "${GREEN}${CHECK}${NC} Auto-selected: ${BOLD}${MOUNT_POINT}${NC} (${MAX_SPACE}GB free)"
else
    if ! [[ "$PART_SELECTION" =~ ^[0-9]+$ ]] || [ "$PART_SELECTION" -lt 1 ] || [ "$PART_SELECTION" -gt $PART_NUM ]; then
        echo -e "${RED}${CROSS} Invalid selection!${NC}"
        exit 1
    fi
    PART_INDEX=$((PART_SELECTION - 1))
    MOUNT_POINT="${PART_MOUNTS[$PART_INDEX]}"
    echo -e "${GREEN}${CHECK}${NC} Selected: ${BOLD}${MOUNT_POINT}${NC}"
fi

# Check space and set test sizes
AVAIL_SPACE=$(df -BG "$MOUNT_POINT" | tail -1 | awk '{print $4}' | sed 's/G//')

if [ "$AVAIL_SPACE" -lt 5 ]; then
    echo -e "\n${RED}${CROSS} ERROR: Need at least 5GB free space. Found: ${AVAIL_SPACE}GB${NC}"
    exit 1
elif [ "$AVAIL_SPACE" -lt 15 ]; then
    TEST_SIZE="2G"
    TEST_SIZE_4K="512M"
elif [ "$AVAIL_SPACE" -lt 30 ]; then
    TEST_SIZE="4G"
    TEST_SIZE_4K="1G"
else
    TEST_SIZE="8G"
    TEST_SIZE_4K="2G"
fi

# Create test directory
TEST_DIR="$MOUNT_POINT/nvme_benchmark_$$"
mkdir -p "$TEST_DIR"

# Determine expected speeds based on PCIe gen and model
if echo "$SELECTED_MODEL" | grep -iq "9100"; then
    EXP_SEQ_R=14800
    EXP_SEQ_W=13400
    EXP_RAND_R=2200
    EXP_RAND_W=2600
elif echo "$SELECTED_MODEL" | grep -iq "990 PRO"; then
    EXP_SEQ_R=7450
    EXP_SEQ_W=6900
    EXP_RAND_R=1400
    EXP_RAND_W=1550
elif echo "$SELECTED_MODEL" | grep -iq "980 PRO"; then
    EXP_SEQ_R=7000
    EXP_SEQ_W=5100
    EXP_RAND_R=1000
    EXP_RAND_W=1000
elif echo "$SELECTED_MODEL" | grep -iq "970"; then
    EXP_SEQ_R=3500
    EXP_SEQ_W=3300
    EXP_RAND_R=600
    EXP_RAND_W=600
else
    # Generic based on PCIe gen
    if [ "$GEN" = "5" ]; then
        EXP_SEQ_R=12000
        EXP_SEQ_W=10000
        EXP_RAND_R=1800
        EXP_RAND_W=2000
    elif [ "$GEN" = "4" ]; then
        EXP_SEQ_R=7000
        EXP_SEQ_W=5000
        EXP_RAND_R=1000
        EXP_RAND_W=1000
    else
        EXP_SEQ_R=3500
        EXP_SEQ_W=2500
        EXP_RAND_R=500
        EXP_RAND_W=500
    fi
fi

# Run tests
print_section "Running Performance Tests"
echo -e "${GRAY}Test size: ${TEST_SIZE} (sequential), ${TEST_SIZE_4K} (random)${NC}"
echo -e "${GRAY}Location: ${TEST_DIR}${NC}\n"

# Sequential Read
echo -e "${CHART} ${BOLD}Sequential Read Test${NC}"
fio --name=seq-read \
    --directory=$TEST_DIR \
    --direct=1 \
    --rw=read \
    --bs=1M \
    --size=$TEST_SIZE \
    --ioengine=libaio \
    --iodepth=32 \
    --numjobs=1 \
    --group_reporting \
    --output-format=json \
    --output=/tmp/seq_read.json > /dev/null 2>&1

SEQ_READ_BW=$(jq -r '.jobs[0].read.bw' /tmp/seq_read.json 2>/dev/null)
SEQ_READ_MBPS=$(awk "BEGIN {printf \"%.0f\", $SEQ_READ_BW/1024}")
SEQ_READ_PCT=$(awk "BEGIN {printf \"%.0f\", ($SEQ_READ_MBPS/$EXP_SEQ_R)*100}")

if [ $SEQ_READ_PCT -ge 80 ]; then
    COLOR=$GREEN
elif [ $SEQ_READ_PCT -ge 60 ]; then
    COLOR=$YELLOW
else
    COLOR=$RED
fi

echo -e "   ${COLOR}${SEQ_READ_MBPS} MB/s${NC} ${GRAY}(${SEQ_READ_PCT}% of expected ${EXP_SEQ_R} MB/s)${NC}\n"

# Sequential Write
echo -e "${CHART} ${BOLD}Sequential Write Test${NC}"
fio --name=seq-write \
    --directory=$TEST_DIR \
    --direct=1 \
    --rw=write \
    --bs=1M \
    --size=$TEST_SIZE \
    --ioengine=libaio \
    --iodepth=32 \
    --numjobs=1 \
    --group_reporting \
    --output-format=json \
    --output=/tmp/seq_write.json > /dev/null 2>&1

SEQ_WRITE_BW=$(jq -r '.jobs[0].write.bw' /tmp/seq_write.json 2>/dev/null)
SEQ_WRITE_MBPS=$(awk "BEGIN {printf \"%.0f\", $SEQ_WRITE_BW/1024}")
SEQ_WRITE_PCT=$(awk "BEGIN {printf \"%.0f\", ($SEQ_WRITE_MBPS/$EXP_SEQ_W)*100}")

if [ $SEQ_WRITE_PCT -ge 80 ]; then
    COLOR=$GREEN
elif [ $SEQ_WRITE_PCT -ge 60 ]; then
    COLOR=$YELLOW
else
    COLOR=$RED
fi

echo -e "   ${COLOR}${SEQ_WRITE_MBPS} MB/s${NC} ${GRAY}(${SEQ_WRITE_PCT}% of expected ${EXP_SEQ_W} MB/s)${NC}\n"

# Random 4K Read
echo -e "${CHART} ${BOLD}Random 4K Read Test${NC} ${GRAY}(30 seconds)${NC}"
fio --name=rand-read-4k \
    --directory=$TEST_DIR \
    --direct=1 \
    --rw=randread \
    --bs=4k \
    --size=$TEST_SIZE_4K \
    --ioengine=libaio \
    --iodepth=32 \
    --numjobs=4 \
    --runtime=30 \
    --time_based \
    --group_reporting \
    --output-format=json \
    --output=/tmp/rand_read.json > /dev/null 2>&1

RAND_READ_IOPS=$(jq -r '.jobs[0].read.iops' /tmp/rand_read.json 2>/dev/null)
RAND_READ_K=$(awk "BEGIN {printf \"%.0f\", $RAND_READ_IOPS/1000}")
RAND_READ_PCT=$(awk "BEGIN {printf \"%.0f\", ($RAND_READ_K/$EXP_RAND_R)*100}")

if [ $RAND_READ_PCT -ge 80 ]; then
    COLOR=$GREEN
elif [ $RAND_READ_PCT -ge 60 ]; then
    COLOR=$YELLOW
else
    COLOR=$RED
fi

echo -e "   ${COLOR}${RAND_READ_K}k IOPS${NC} ${GRAY}(${RAND_READ_PCT}% of expected ${EXP_RAND_R}k IOPS)${NC}\n"

# Random 4K Write
echo -e "${CHART} ${BOLD}Random 4K Write Test${NC} ${GRAY}(30 seconds)${NC}"
fio --name=rand-write-4k \
    --directory=$TEST_DIR \
    --direct=1 \
    --rw=randwrite \
    --bs=4k \
    --size=$TEST_SIZE_4K \
    --ioengine=libaio \
    --iodepth=32 \
    --numjobs=4 \
    --runtime=30 \
    --time_based \
    --group_reporting \
    --output-format=json \
    --output=/tmp/rand_write.json > /dev/null 2>&1

RAND_WRITE_IOPS=$(jq -r '.jobs[0].write.iops' /tmp/rand_write.json 2>/dev/null)
RAND_WRITE_K=$(awk "BEGIN {printf \"%.0f\", $RAND_WRITE_IOPS/1000}")
RAND_WRITE_PCT=$(awk "BEGIN {printf \"%.0f\", ($RAND_WRITE_K/$EXP_RAND_W)*100}")

if [ $RAND_WRITE_PCT -ge 80 ]; then
    COLOR=$GREEN
elif [ $RAND_WRITE_PCT -ge 60 ]; then
    COLOR=$YELLOW
else
    COLOR=$RED
fi

echo -e "   ${COLOR}${RAND_WRITE_K}k IOPS${NC} ${GRAY}(${RAND_WRITE_PCT}% of expected ${EXP_RAND_W}k IOPS)${NC}\n"

# Cleanup
rm -rf "$TEST_DIR"
rm -f /tmp/seq_read.json /tmp/seq_write.json /tmp/rand_read.json /tmp/rand_write.json

# Results summary
print_section "Performance Summary"
echo ""
echo -e "${BOLD}${WHITE}Drive:${NC} $SELECTED_MODEL"
echo -e "${BOLD}${WHITE}Device:${NC} $NVME_BASE | ${BOLD}${WHITE}Mount:${NC} $MOUNT_POINT"
echo -e "${BOLD}${WHITE}PCIe:${NC} Gen $GEN x${LINK_WIDTH}"
echo ""

# Function to draw progress bar
draw_progress_bar() {
    local value=$1
    local max=$2
    local width=40
    
    local filled=$(awk "BEGIN {printf \"%.0f\", ($value/$max)*$width}")
    [ $filled -gt $width ] && filled=$width
    [ $filled -lt 0 ] && filled=0
    
    local empty=$((width - filled))
    local percent=$(awk "BEGIN {printf \"%.0f\", ($value/$max)*100}")
    
    # Color based on percentage
    local color=$RED
    [ $percent -ge 60 ] && color=$YELLOW
    [ $percent -ge 80 ] && color=$GREEN
    
    # Build the bar as a complete string
    local bar="   ${color}"
    for ((i=0; i<filled; i++)); do bar+="█"; done
    bar+="${GRAY}"
    for ((i=0; i<empty; i++)); do bar+="░"; done
    bar+="${NC} ${percent}%"
    
    echo -e "$bar"
}

echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${BOLD}Sequential Read${NC}"

if [ $SEQ_READ_PCT -ge 80 ]; then
    SEQ_READ_COLOR=$GREEN
elif [ $SEQ_READ_PCT -ge 60 ]; then
    SEQ_READ_COLOR=$YELLOW
else
    SEQ_READ_COLOR=$RED
fi
echo -e "   ${SEQ_READ_COLOR}${SEQ_READ_MBPS} MB/s${NC} ${GRAY}(Expected: ${EXP_SEQ_R} MB/s)${NC}"
draw_progress_bar $SEQ_READ_MBPS $EXP_SEQ_R
echo ""

echo -e "${BOLD}Sequential Write${NC}"
if [ $SEQ_WRITE_PCT -ge 80 ]; then
    SEQ_WRITE_COLOR=$GREEN
elif [ $SEQ_WRITE_PCT -ge 60 ]; then
    SEQ_WRITE_COLOR=$YELLOW
else
    SEQ_WRITE_COLOR=$RED
fi
echo -e "   ${SEQ_WRITE_COLOR}${SEQ_WRITE_MBPS} MB/s${NC} ${GRAY}(Expected: ${EXP_SEQ_W} MB/s)${NC}"
draw_progress_bar $SEQ_WRITE_MBPS $EXP_SEQ_W
echo ""

echo -e "${BOLD}Random 4K Read${NC}"
if [ $RAND_READ_PCT -ge 80 ]; then
    RAND_READ_COLOR=$GREEN
elif [ $RAND_READ_PCT -ge 60 ]; then
    RAND_READ_COLOR=$YELLOW
else
    RAND_READ_COLOR=$RED
fi
echo -e "   ${RAND_READ_COLOR}${RAND_READ_K}k IOPS${NC} ${GRAY}(Expected: ${EXP_RAND_R}k IOPS)${NC}"
draw_progress_bar $RAND_READ_K $EXP_RAND_R
echo ""

echo -e "${BOLD}Random 4K Write${NC}"
if [ $RAND_WRITE_PCT -ge 80 ]; then
    RAND_WRITE_COLOR=$GREEN
elif [ $RAND_WRITE_PCT -ge 60 ]; then
    RAND_WRITE_COLOR=$YELLOW
else
    RAND_WRITE_COLOR=$RED
fi
echo -e "   ${RAND_WRITE_COLOR}${RAND_WRITE_K}k IOPS${NC} ${GRAY}(Expected: ${EXP_RAND_W}k IOPS)${NC}"
draw_progress_bar $RAND_WRITE_K $EXP_RAND_W
echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"

echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"

# Calculate overall performance
AVG_PCT=$(awk "BEGIN {printf \"%.0f\", ($SEQ_READ_PCT + $SEQ_WRITE_PCT + $RAND_READ_PCT + $RAND_WRITE_PCT) / 4}")

# Overall verdict
if [ $AVG_PCT -ge 80 ]; then
    echo -e "\n${GREEN}${ROCKET} Excellent!${NC} Drive performing at ${BOLD}${AVG_PCT}%${NC} of expected speeds."
elif [ $AVG_PCT -ge 60 ]; then
    echo -e "\n${YELLOW}${WARN} Good${NC} performance at ${BOLD}${AVG_PCT}%${NC}. May be limited by LVM/filesystem."
elif [ $AVG_PCT -ge 40 ]; then
    echo -e "\n${YELLOW}${WARN} Moderate${NC} performance at ${BOLD}${AVG_PCT}%${NC}. Check thermal throttling and drive fill level."
else
    echo -e "\n${RED}${WARN} Low${NC} performance at ${BOLD}${AVG_PCT}%${NC}. Check for issues (thermal, LVM overhead, drive health)."
fi

echo -e "\n${GRAY}${DIM}Note: Testing through LVM/RAID or on full drives reduces performance.${NC}"
echo -e "${GRAY}${DIM}For best results, test on a partition with >50GB free space.${NC}\n"
