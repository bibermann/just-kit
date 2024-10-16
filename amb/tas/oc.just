[script]
oc-login project="dt-av-tas": (_check-cmd "oc")
    source .env
    export HTTPS_PROXY="$OC_PROXY"

    if ! oc whoami >/dev/null 2>&1; then
      oc login -u "$QLF_DEV_ACCOUNT" https://api.dt.ocp.tc.corp:6443
      oc registry login
    fi

    oc project '{{ project }}'

oc-logout: (_check-cmd "oc")
    oc logout

[script]
oc-port-forward project="dt-av-tas" instance="tas" labels="" *ports="": (_check-cmd "oc")
    # `labels` is a comma-separated list to identify the pod, examples:
    # - "app.kubernetes.io/name=tas-gis-server"
    # - "postgres-operator.crunchydata.com/role=pgbouncer"
    # A label to filter the instance is added automatically.
    # `ports` is [<local_port>:]<remote_port> [...[<local_port_n>:]<remote_port_n>]

    [ ! -z '{{ labels }}' ] || { echo >&2 'ERROR: Specify labels to identify the pod.'; exit 1; }
    [ ! -z '{{ ports }}' ] || { echo >&2 'ERROR: Specify port mappings.'; exit 1; }

    just oc-login '{{ project }}'
    source .env
    export HTTPS_PROXY="$OC_PROXY"

    POD="$(oc get pods -o=custom-columns=NAME:.metadata.name --no-headers -l app.kubernetes.io/instance="{{ instance }},{{ labels }}")"
    while true; do oc port-forward "$POD" {{ ports }} || true; done
