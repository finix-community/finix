# Tcl script called by dhcpcd to apply network configuration.
# This script writes assertions into files that are monitored
# by a syndicate-server.

set reason $env(reason)
set iface $env(interface)
set assDir "/run/synit/config/network/$iface"
set assFile "$assDir/$reason.pr"
file mkdir $assDir

proc appendAssertions {path values template} {
    set fd [open $path a]
    set text [string map $values $template]
    puts $fd $text
    close $fd
}

case $reason {
     CARRIER {
         appendAssertions $assFile [list \
             @ifname $env(interface) \
             @metric $env(ifmetric) \
             @mtu    $env(ifmtu) \
           ] {<interface @ifname { "metric": @metric "mtu": @mtu }>}
     }
     NOCARRIER {
         file delete "$assDir/CARRIER.pr"
     }
     BOUND {
         appendAssertions $assFile [list \
               @ifname    $env(interface) \
               @address   $env(new_ip_address) \
               @prefixLen $env(new_subnet_cidr) \
               @gateway   $env(new_routers) \
               @lease_time $env(new_dhcp_lease_time) \
             ] {
               <address @ifname ipv4 { "local": "@address" "prefixlen": @prefixLen "life_time": @lease_time }>
               <route @ifname ipv4 { "gateway": "@gateway" } >
             }
     }
     default {
       puts stderr "unhandled dhcpcd event «$reason»"
     }
}
