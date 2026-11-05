package gke.privatecluster_test

import rego.v1

import data.gke.privatecluster

good := {
	"kind": "GKECluster",
	"spec": {"parameters": {
		"privateCluster": {"enablePrivateNodes": true, "enablePrivateEndpoint": true, "masterCidr": "172.16.0.0/28"},
		"masterAuthorizedNetworks": [{"cidrBlock": "10.10.0.0/20"}],
	}},
}

test_good_claim_allowed if count(privatecluster.deny) == 0 with input as good

test_public_endpoint_denied if {
	bad := json.patch(good, [{"op": "replace", "path": "/spec/parameters/privateCluster/enablePrivateEndpoint", "value": false}])
	count(privatecluster.deny) == 1 with input as bad
}

test_public_nodes_denied if {
	bad := json.patch(good, [{"op": "replace", "path": "/spec/parameters/privateCluster/enablePrivateNodes", "value": false}])
	count(privatecluster.deny) == 1 with input as bad
}

test_missing_private_block_denied if {
	bad := json.remove(good, ["/spec/parameters/privateCluster"])
	count(privatecluster.deny) >= 2 with input as bad
}

test_open_authorized_network_denied if {
	bad := json.patch(good, [{"op": "add", "path": "/spec/parameters/masterAuthorizedNetworks/-", "value": {"cidrBlock": "0.0.0.0/0"}}])
	count(privatecluster.deny) == 1 with input as bad
}

test_xcluster_also_checked if {
	bad := json.patch(good, [
		{"op": "replace", "path": "/kind", "value": "XCluster"},
		{"op": "replace", "path": "/spec/parameters/privateCluster/enablePrivateEndpoint", "value": false},
	])
	count(privatecluster.deny) == 1 with input as bad
}

test_other_kinds_ignored if count(privatecluster.deny) == 0 with input as {"kind": "ConfigMap"}
