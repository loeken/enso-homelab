%{ for config in configs ~}
Host ${config.host}
    User ${config.user}
    IdentityFile ${config.identityfile}
    ProxyJump ${config.proxyjump}
%{ endfor ~}