
# vpn-instance

module:ct-vpn-instance

## configuration

### evpn

#### redundancy-mode

```lm
sb : huawei-evpn/evpn/base-process/redundancy-mode
```

#### source-address

```lm
sb : huawei-evpn/evpn/base-process/source-address
```

#### source-if

#### static-esi

- *

##### esi

```lm
sb : huawei-evpn/evpn/site/static-esis/static-esi/*/esi
```

##### redundancy-mode

```lm
sb : huawei-evpn/evpn/site/static-esis/static-esi/*/redundancy-mode
```

### instances

- *

#### name

```lm
sb : huawei-network-instance/network-instance/instances/instance/*/name
```

#### vpws

##### export-rt

grouping:vrf-common

- *

```lm
sb : huawei-evpn/evpn/instances/instance/*/vpws-evpn/rts/rt/*/vrf-rt-type
sb : huawei-evpn/evpn/instances/instance/*/vpws-evpn/rts/rt/*/vrf-rt-value
```

##### import-rt

grouping:vrf-common

- *

```lm
sb : huawei-evpn/evpn/instances/instance/*/vpws-evpn/rts/rt/*/vrf-rt-type
sb : huawei-evpn/evpn/instances/instance/*/vpws-evpn/rts/rt/*/vrf-rt-value
```

##### default-color

grouping:vrf-common

```lm
sb : huawei-evpn/evpn/instances/instance/*/vpws-evpn/default-color
```

##### frr-enable

grouping:vrf-common

frr-enable:
  type: "boolean"
  description: " Enable or disable the VPN FRR. "

```lm
sb : huawei-evpn/evpn/instances/instance/*/vpws-evpn/local-remote-frr
sb : huawei-evpn/evpn/instances/instance/*/vpws-evpn/remote-frr
```

##### rd

grouping:vrf-common

```lm
sb : huawei-evpn/evpn/instances/instance/*/vpws-evpn/rd
```

##### srv6-mode

```lm
sb : huawei-evpn/evpn/instances/instance/*/vpws-evpn/srv6-mode
```

#### binding-ifs

- *

##### if-name

```lm
sb : huawei-if-ip/network-instance/instances/instance/ipv4-ifs/ipv4-if/*/name
sb : huawei-if-ip/network-instance/instances/instance/ipv6-ifs/ipv6-if/*/name
```

##### if-mac

##### description

```lm
sb : huawei-evpn/evpn/instances/instance/*/vpws-evpn/description
```

##### ipv4-addr

```lm
sb : huawei-if-ip/network-instance/instances/instance/ipv4-ifs/ipv4-if/*/addresses/address/*/ip
sb : huawei-if-ip/network-instance/instances/instance/ipv4-ifs/ipv4-if/*/addresses/address/*/netmask
sb : huawei-if-ip/network-instance/instances/instance/ipv4-ifs/ipv4-if/*/addresses/address/*/type
```

##### ipv6-addr

```lm
sb : huawei-if-ip/network-instance/instances/instance/ipv6-ifs/ipv6-if/*/addresses/address/*/algorithm-type
sb : huawei-if-ip/network-instance/instances/instance/ipv6-ifs/ipv6-if/*/addresses/address/*/ip
sb : huawei-if-ip/network-instance/instances/instance/ipv6-ifs/ipv6-if/*/addresses/address/*/prefix-length
sb : huawei-if-ip/network-instance/instances/instance/ipv6-ifs/ipv6-if/*/addresses/address/*/type
```

#### afs

- *

##### vpn-type

vpn-type:
  type: "string"
  enum:
  - "default"
  - "evpn"
  - "evpn-vpws"

##### address-family

address-family:
  type: "string"
  description: "Address family"
  enum:
  - "ipv4-family"
  - "ipv6-family"

##### apply-lable

apply-lable:
  type: "string"
  description: " End.DT4/6 SID for SRv6, and MPLS label for MPLS or SR "
  enum:
  - "per-route"
  - "per-instance"
  - "per-nexthop"

##### load-balance-num

##### export-rt

grouping:vrf-common

- *

```lm
sb : huawei-evpn/network-instance/instances/instance/afs/af/evpn/extend-vpn-targets/extend-vpn-target/*/vrf-rt-type
sb : huawei-evpn/network-instance/instances/instance/afs/af/evpn/extend-vpn-targets/extend-vpn-target/*/vrf-rt-value
```

##### import-rt

grouping:vrf-common

- *

```lm
sb : huawei-evpn/network-instance/instances/instance/afs/af/evpn/extend-vpn-targets/extend-vpn-target/*/vrf-rt-type
sb : huawei-evpn/network-instance/instances/instance/afs/af/evpn/extend-vpn-targets/extend-vpn-target/*/vrf-rt-value
```

##### default-color

grouping:vrf-common

```lm
sb : huawei-l3vpn/network-instance/instances/instance/afs/af/*/default-color
```

##### frr-enable

grouping:vrf-common

```lm
sb : huawei-l3vpn/network-instance/instances/instance/afs/af/*/vpn-frr
```

##### rd

grouping:vrf-common

```lm
sb : huawei-l3vpn/network-instance/instances/instance/afs/af/*/route-distinguisher
```

##### vpn-ttlmode

###### ttlmode

```lm
sb : huawei-mpls-forward/network-instance/instances/instance/afs/af/vpn-ttlmode/ttlmode
```

##### vrfpipe

###### domain-name

```lm
sb : huawei-mpls-forward/network-instance/instances/instance/afs/af/vrfpipe/domain-name
```

###### color

```lm
sb : huawei-mpls-forward/network-instance/instances/instance/afs/af/vrfpipe/color
```

###### egress-pipe-mode

```lm
sb : huawei-mpls-forward/network-instance/instances/instance/afs/af/vrfpipe/egress-pipe-mode
```

###### ingress-pipe-mode

```lm
sb : huawei-mpls-forward/network-instance/instances/instance/afs/af/vrfpipe/ingress-pipe-mode
```

###### pipe-mode

```lm
sb : huawei-mpls-forward/network-instance/instances/instance/afs/af/vrfpipe/pipe-mode
```

###### service-class

```lm
sb : huawei-mpls-forward/network-instance/instances/instance/afs/af/vrfpipe/service-class
```

###### split-mode

```lm
sb : huawei-mpls-forward/network-instance/instances/instance/afs/af/vrfpipe/split-mode
```
