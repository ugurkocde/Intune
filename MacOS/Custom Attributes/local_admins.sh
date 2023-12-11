#!/bin/bash
# Script to list all local admin users

echo "Listing all local admin users:"
dscl . -read /Groups/admin GroupMembership
