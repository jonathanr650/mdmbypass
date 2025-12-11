#!/bin/bash

# MDM Bypass Script for macOS
# Run this from Recovery Mode after disabling SIP and authenticated-root
# Usage: bash mdm_bypass.sh

echo "Starting MDM Bypass Script..."

# Define volume paths
SYSTEM_VOL="/Volumes/Macintosh HD"
DATA_VOL="/Volumes/Macintosh HD - Datos"

# Check if volumes are mounted
if [ ! -d "$SYSTEM_VOL" ]; then
    echo "Error: System volume not found at $SYSTEM_VOL"
    exit 1
fi

if [ ! -d "$DATA_VOL" ]; then
    echo "Error: Data volume not found at $DATA_VOL"
    exit 1
fi

# Mount system volume as read-write
echo "Mounting system volume as read-write..."
mount -uw "$SYSTEM_VOL"

# Remove Remote Management plugins
echo "Removing Remote Management plugins..."
rm -rf "$SYSTEM_VOL/System/Library/CoreServices/Setup Assistant.app/Contents/Plugins/RemoteManagement."*

# Remove MDM configuration files
echo "Removing MDM configuration files..."
rm -f "$DATA_VOL/private/var/db/ConfigurationProfiles/Settings/.cloudConfigHasActivationRecord"
rm -f "$DATA_VOL/private/var/db/ConfigurationProfiles/Settings/.cloudConfigRecordFound"
rm -rf "$DATA_VOL/private/var/db/ConfigurationProfiles/Setup"
rm -rf "$DATA_VOL/private/var/db/ConfigurationProfiles/Settings/"*

# Remove additional MDM-related files
echo "Removing additional MDM files..."
rm -rf "$DATA_VOL/private/var/db/ConfigurationProfiles/Store"
rm -rf "$DATA_VOL/private/var/db/ConfigurationProfiles/ProfileInstallation"
rm -f "$DATA_VOL/private/var/db/.AppleSetupDone"

# Block MDM servers in hosts file
echo "Blocking MDM servers..."
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
echo "Creating directories for disabled services..."
mkdir -p "$SYSTEM_VOL/System/Library/LaunchDaemons.disabled"
mkdir -p "$SYSTEM_VOL/System/Library/LaunchAgents.disabled"

# Move MDM-related launch daemons and agents
echo "Disabling MDM launch services..."
mv "$SYSTEM_VOL/System/Library/LaunchDaemons/com.apple.ManagedClient"* "$SYSTEM_VOL/System/Library/LaunchDaemons.disabled/" 2>/dev/null
mv "$SYSTEM_VOL/System/Library/LaunchAgents/com.apple.ManagedClient"* "$SYSTEM_VOL/System/Library/LaunchAgents.disabled/" 2>/dev/null

# Also move additional MDM-related services
mv "$SYSTEM_VOL/System/Library/LaunchDaemons/com.apple.mdmclient"* "$SYSTEM_VOL/System/Library/LaunchDaemons.disabled/" 2>/dev/null
mv "$SYSTEM_VOL/System/Library/LaunchDaemons/com.apple.devicemanagement"* "$SYSTEM_VOL/System/Library/LaunchDaemons.disabled/" 2>/dev/null

# Disable MDM services via launchctl
echo "Disabling MDM services..."
launchctl disable system/com.apple.ManagedClient.enroll
launchctl disable system/com.apple.mdmclient.daemon
launchctl disable system/com.apple.mdmclient
launchctl disable system/com.apple.devicemanagementclient
launchctl disable system/com.apple.devicemanagementclient.teslad
launchctl disable system/com.apple.ManagedClient
launchctl disable system/com.apple.ManagedClient.cloudconfigurationd

# Create bypass indicator files
echo "Creating bypass indicator files..."
touch "$DATA_VOL/private/var/db/ConfigurationProfiles/Settings/.cloudConfigProfileInstalled"
touch "$DATA_VOL/private/var/db/ConfigurationProfiles/Settings/.cloudConfigRecordNotFound"

# Remove enrollment profiles
echo "Removing enrollment profiles..."
rm -rf "$SYSTEM_VOL/System/Library/CoreServices/Setup Assistant.app/Contents/Resources/Profiles/"*
rm -rf "$DATA_VOL/private/var/db/enrollmentState"
rm -rf "$DATA_VOL/Library/Application Support/CloudDocs/store/com.apple.CloudConfigurationDetails"

# Clear MDM caches
echo "Clearing MDM caches..."
rm -rf "$DATA_VOL/private/var/db/com.apple.apsd"
rm -rf "$DATA_VOL/private/var/db/com.apple.cloudconfigurationd"

# Flush DNS cache
echo "Flushing DNS cache..."
killall -HUP mDNSResponder 2>/dev/null

# Create completion indicator
touch "$DATA_VOL/.mdm_bypass_completed"

echo "MDM Bypass Script completed!"
echo ""
echo "Next steps:"
echo "1. Reboot your Mac"
echo "2. Complete Setup Assistant without connecting to internet"
echo "3. Once at desktop, connect to internet if needed"
echo ""
echo "Note: Some MDM policies may still apply if the device was previously enrolled."
echo "For complete removal, a clean macOS installation may be required."
