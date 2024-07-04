#!/bin/bash

# Define the base folder
baseFolder="/public"

# Generate a unique client name
echo ""
echo "Generating a unique client name..."
CLIENT="guru_$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 8)"
echo "Client name: $CLIENT"

# Create a new folder for the client configuration
clientFolder="$baseFolder/$CLIENT"
mkdir -p "$clientFolder"

# Check if the client already exists
CLIENTEXISTS=$(tail -n +2 /etc/openvpn/easy-rsa/pki/index.txt | grep -c -E "/CN=$CLIENT\$")
if [[ $CLIENTEXISTS == '1' ]]; then
    echo ""
    echo "The specified client CN was already found in easy-rsa, please choose another name."
    exit
else
    cd /etc/openvpn/easy-rsa/ || exit
    ./easyrsa --batch build-client-full "$CLIENT" nopass
    echo "Client $CLIENT added."
fi

# Generate the custom client.ovpn
cp /etc/openvpn/client-template.txt "$clientFolder/$CLIENT.ovpn"
{
    echo "<ca>"
    cat "/etc/openvpn/easy-rsa/pki/ca.crt"
    echo "</ca>"

    echo "<cert>"
    awk '/BEGIN/,/END CERTIFICATE/' "/etc/openvpn/easy-rsa/pki/issued/$CLIENT.crt"
    echo "</cert>"

    echo "<key>"
    cat "/etc/openvpn/easy-rsa/pki/private/$CLIENT.key"
    echo "</key>"

    if grep -qs "^tls-crypt" /etc/openvpn/server.conf; then
        echo "<tls-crypt>"
        cat /etc/openvpn/tls-crypt.key
        echo "</tls-crypt>"
    elif grep -qs "^tls-auth" /etc/openvpn/server.conf; then
        echo "key-direction 1"
        echo "<tls-auth>"
        cat /etc/openvpn/tls-auth.key
        echo "</tls-auth>"
    fi
} >>"$clientFolder/$CLIENT.ovpn"

echo "Success"
exit 0
