Tired of adding 4 or more additinal IPs by hand? Now you can add as many as you want with ease!


Usage:

A dialog menu will list all non‑loopback interfaces that are either connected or disconnected.

When prompted, type the CIDR you wish to expand (e.g., 192.168.0.0/30) and press Enter.
The script will:

    -Compute the additinal IP addresses for the given CIDR.

    -Iterate over every IP in that range.

    -Add each additional IP as a /32 address to the interface's profile.

    -Restart the Network Manager to apply changes.

A final dialog box will display each /32 address that was added.
