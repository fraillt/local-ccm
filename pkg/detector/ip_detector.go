/*
Copyright 2025 The simple-ccm Authors.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package detector

import (
	"fmt"
	"net"

	"github.com/vishvananda/netlink"
	"k8s.io/klog/v2"
)

// DetectIPBySubnet finds the local IP address of the first up interface whose IP falls
// within the given CIDR subnet. Returns an error if no matching interface is found.
// If multiple interfaces have IPs in the subnet, the first one in enumeration order is returned.
func DetectIPBySubnet(subnet string) (string, error) {
	if subnet == "" {
		return "", fmt.Errorf("subnet is empty")
	}

	_, ipNet, err := net.ParseCIDR(subnet)
	if err != nil {
		return "", fmt.Errorf("invalid subnet %q: %w", subnet, err)
	}

	ifaces, err := net.Interfaces()
	if err != nil {
		return "", fmt.Errorf("failed to list network interfaces: %w", err)
	}

	for _, iface := range ifaces {
		if iface.Flags&net.FlagUp == 0 {
			klog.V(4).Infof("Skipping interface %s: interface is down", iface.Name)
			continue
		}
		addrs, err := iface.Addrs()
		if err != nil {
			klog.V(4).Infof("Skipping interface %s: failed to get addresses: %v", iface.Name, err)
			continue
		}
		for _, addr := range addrs {
			var ip net.IP
			switch v := addr.(type) {
			case *net.IPNet:
				ip = v.IP
			case *net.IPAddr:
				ip = v.IP
			}
			if ip == nil {
				continue
			}
			if ipNet.Contains(ip) {
				klog.V(4).Infof("Found IP %s on interface %s matching subnet %s", ip.String(), iface.Name, subnet)
				return ip.String(), nil
			}
		}
	}

	return "", fmt.Errorf("no interface found with IP in subnet %s", subnet)
}

// DetectIP detects the local IP address by using netlink to query the route
// to the target IP and extracting the source IP from the route
func DetectIP(targetIP string) (string, error) {
	if targetIP == "" {
		return "", fmt.Errorf("target IP is empty")
	}

	// Parse target IP
	dstIP := net.ParseIP(targetIP)
	if dstIP == nil {
		return "", fmt.Errorf("invalid target IP address: %s", targetIP)
	}

	klog.V(4).Infof("Detecting IP using target: %s", targetIP)

	// Get route to target IP using netlink
	routes, err := netlink.RouteGet(dstIP)
	if err != nil {
		return "", fmt.Errorf("failed to get route to %s: %w", targetIP, err)
	}

	if len(routes) == 0 {
		return "", fmt.Errorf("no route found to %s", targetIP)
	}

	// Get the first route (preferred route)
	route := routes[0]

	// Extract source IP from route
	if route.Src == nil {
		return "", fmt.Errorf("route to %s has no source IP", targetIP)
	}

	detectedIP := route.Src.String()

	klog.V(4).Infof("Detected IP: %s (target: %s)", detectedIP, targetIP)

	return detectedIP, nil
}
