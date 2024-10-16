forti-status:
    ssh -p 2222 diglett@office.ambrosys.de "ssh kyogre@sapphire 'forticlient vpn status'"

# The password is the combination of your PR EMS App - TC PR (Produktion Maut) password and the FortiToken
forti-login:
    source .env && ssh -t -p 2222 diglett@office.ambrosys.de "ssh -t kyogre@sapphire 'forticlient vpn connect TC_TAS_VPNP -u $TC_USER -p'"
