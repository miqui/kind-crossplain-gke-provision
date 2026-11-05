package gke.privatecluster

import rego.v1

# Applies to GKECluster claims and XCluster composites (same spec.parameters shape).
is_cluster if input.kind == "GKECluster"

is_cluster if input.kind == "XCluster"

params := input.spec.parameters

deny contains msg if {
	is_cluster
	not params.privateCluster.enablePrivateNodes == true
	msg := "private nodes must be enabled: spec.parameters.privateCluster.enablePrivateNodes must be true"
}

deny contains msg if {
	is_cluster
	not params.privateCluster.enablePrivateEndpoint == true
	msg := "public control-plane endpoint is forbidden: spec.parameters.privateCluster.enablePrivateEndpoint must be true"
}

deny contains msg if {
	is_cluster
	some n in params.masterAuthorizedNetworks
	n.cidrBlock in {"0.0.0.0/0", "::/0"}
	msg := sprintf("master authorized network %q opens the control plane to the internet", [n.cidrBlock])
}

deny contains msg if {
	is_cluster
	not params.privateCluster.masterCidr
	msg := "spec.parameters.privateCluster.masterCidr must be set for a private cluster"
}
