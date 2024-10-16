office-port-forward:
    ssh -p 2222 diglett@office.ambrosys.de -L 6443:192.168.178.32:6443 -L 1337:192.168.178.55:1337
