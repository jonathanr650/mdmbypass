#!/bin/bash

# MDM Bypass Script for macOS with User Creation
# Run this from Recovery Mode after disabling SIP and authenticated-root
# Usage: bash mdm_bypass.sh

# Define color codes
RED='\033[1;31m'
GRN='\033[1;32m'
BLU='\033[1;34m'
YEL='\033[1;33m'
PUR='\033[1;35m'
CYAN='\033[1;36m'
NC='\033[0m'

echo -e "${CYAN}Starting MDM Bypass Script...${NC}"
echo ""

# Define volume paths
SYSTEM_VOL="/Volumes/Macintosh HD"
DATA_VOL="/Volumes/Macintosh HD - Data"

# Check if volumes are mounted
if [ ! -d "$SYSTEM_VOL" ]; then
    echo -e "${RED}Error: System volume not found at $SYSTEM_VOL${NC}"
    exit 1
fi

if [ ! -d "$DATA_VOL" ]; then
    echo -e "${RED}Error: Data volume not found at $DATA_VOL${NC}"
    exit 1
fi

# Create user account
echo -e "${GRN}Creating User Account${NC}"
echo ""

# Get user details
read -p "Enter Full Name: " realName
while [[ -z "$realName" ]]; do
    echo -e "${RED}Full name cannot be empty${NC}"
    read -p "Enter Full Name: " realName
done

read -p "Enter Username: " username
while [[ -z "$username" ]]; do
    echo -e "${RED}Username cannot be empty${NC}"
    read -p "Enter Username: " username
done

read -sp "Enter Password: " passw
echo ""
while [[ -z "$passw" ]]; do
    echo -e "${RED}Password cannot be empty${NC}"
    read -sp "Enter Password: " passw
    echo ""
done

# Create User using dscl
echo -e "${GRN}Creating user account...${NC}"
dscl_path="$DATA_VOL/private/var/db/dslocal/nodes/Default"

dscl -f "$dscl_path" localhost -create "/Local/Default/Users/$username"
dscl -f "$dscl_path" localhost -create "/Local/Default/Users/$username" UserShell "/bin/zsh"
dscl -f "$dscl_path" localhost -create "/Local/Default/Users/$username" RealName "$realName"
dscl -f "$dscl_path" localhost -create "/Local/Default/Users/$username" UniqueID "501"
dscl -f "$dscl_path" localhost -create "/Local/Default/Users/$username" PrimaryGroupID "20"
mkdir -p "$DATA_VOL/Users/$username"
dscl -f "$dscl_path" localhost -create "/Local/Default/Users/$username" NFSHomeDirectory "/Users/$username"
dscl -f "$dscl_path" localhost -passwd "/Local/Default/Users/$username" "$passw"
dscl -f "$dscl_path" localhost -append "/Local/Default/Groups/admin" GroupMembership "$username"

echo -e "${GRN}User '$username' created successfully!${NC}"

# Mark Setup Assistant as complete
echo -e "${GRN}Skipping Setup Assistant...${NC}"
touch "$DATA_VOL/private/var/db/.AppleSetupDone"

echo ""

# Mount system volume as read-write
echo -e "${BLU}Mounting system volume as read-write...${NC}"
mount -uw "$SYSTEM_VOL"

# Remove Remote Management plugins
echo -e "${BLU}Removing Remote Management plugins...${NC}"
rm -rf "$SYSTEM_VOL/System/Library/CoreServices/Setup Assistant.app/Contents/Plugins/RemoteManagement."*

# Remove MDM configuration files
echo -e "${BLU}Removing MDM configuration files...${NC}"
rm -f "$DATA_VOL/private/var/db/ConfigurationProfiles/Settings/.cloudConfigHasActivationRecord"
rm -f "$DATA_VOL/private/var/db/ConfigurationProfiles/Settings/.cloudConfigRecordFound"
rm -rf "$DATA_VOL/private/var/db/ConfigurationProfiles/Setup"
rm -rf "$DATA_VOL/private/var/db/ConfigurationProfiles/Settings/"*

# Remove additional MDM-related files
echo -e "${BLU}Removing additional MDM files...${NC}"
rm -rf "$DATA_VOL/private/var/db/ConfigurationProfiles/Store"
rm -rf "$DATA_VOL/private/var/db/ConfigurationProfiles/ProfileInstallation"

# Block MDM servers in hosts file
echo -e "${BLU}Blocking MDM servers...${NC}"
HOSTS_FILE="$DATA_VOL/private/etc/hosts"

# Backup original hosts file
cp "$HOSTS_FILE" "$HOSTS_FILE.backup" 2>/dev/null

# Add MDM server blocks
cat >> "$HOSTS_FILE" << EOF

# MDM Server Blocks
0.0.0.0 iprofiles.apple.com
0.0.0.0 mdmenrollment.apple.com
0.0.0.0 gdmf.apple.com
0.0.0.0 acmdm.apple.com
0.0.0.0 Albert.apple.com
0.0.0.0 deviceenrollment.apple.com
EOF

# Create directories for disabled services
echo -e "${BLU}Creating directories for disabled services...${NC}"
mkdir -p "$SYSTEM_VOL/System/Library/LaunchDaemons.disabled"
mkdir -p "$SYSTEM_VOL/System/Library/LaunchAgents.disabled"

# Move MDM-related launch daemons and agents
echo -e "${BLU}Disabling MDM launch services...${NC}"
mv "$SYSTEM_VOL/System/Library/LaunchDaemons/com.apple.ManagedClient"* "$SYSTEM_VOL/System/Library/LaunchDaemons.disabled/" 2>/dev/null
mv "$SYSTEM_VOL/System/Library/LaunchAgents/com.apple.ManagedClient"* "$SYSTEM_VOL/System/Library/LaunchAgents.disabled/" 2>/dev/null

# Also move additional MDM-related services
mv "$SYSTEM_VOL/System/Library/LaunchDaemons/com.apple.mdmclient"* "$SYSTEM_VOL/System/Library/LaunchDaemons.disabled/" 2>/dev/null
mv "$SYSTEM_VOL/System/Library/LaunchDaemons/com.apple.devicemanagement"* "$SYSTEM_VOL/System/Library/LaunchDaemons.disabled/" 2>/dev/null

# Disable MDM services via launchctl
echo -e "${BLU}Disabling MDM services...${NC}"
launchctl disable system/com.apple.ManagedClient.enroll
launchctl disable system/com.apple.mdmclient.daemon
launchctl disable system/com.apple.mdmclient
launchctl disable system/com.apple.devicemanagementclient
launchctl disable system/com.apple.devicemanagementclient.teslad
launchctl disable system/com.apple.ManagedClient
launchctl disable system/com.apple.ManagedClient.cloudconfigurationd

# Create bypass indicator files
echo -e "${BLU}Creating bypass indicator files...${NC}"
touch "$DATA_VOL/private/var/db/ConfigurationProfiles/Settings/.cloudConfigProfileInstalled"
touch "$DATA_VOL/private/var/db/ConfigurationProfiles/Settings/.cloudConfigRecordNotFound"

# Remove enrollment profiles
echo -e "${BLU}Removing enrollment profiles...${NC}"
rm -rf "$SYSTEM_VOL/System/Library/CoreServices/Setup Assistant.app/Contents/Resources/Profiles/"*
rm -rf "$DATA_VOL/private/var/db/enrollmentState"
rm -rf "$DATA_VOL/Library/Application Support/CloudDocs/store/com.apple.CloudConfigurationDetails"

# Clear MDM caches
echo -e "${BLU}Clearing MDM caches...${NC}"
rm -rf "$DATA_VOL/private/var/db/com.apple.apsd"
rm -rf "$DATA_VOL/private/var/db/com.apple.cloudconfigurationd"

# Flush DNS cache
echo -e "${BLU}Flushing DNS cache...${NC}"
killall -HUP mDNSResponder 2>/dev/null

# Create completion indicator
touch "$DATA_VOL/.mdm_bypass_completed"

echo ""
echo -e "${GRN}MDM Bypass Script completed!${NC}"
echo ""
echo -e "${YEL}Next steps:${NC}"
echo -e "1. Reboot your Mac"
echo -e "2. Login with username: ${GRN}$username${NC}"
echo ""
