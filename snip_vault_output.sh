#!/bin/bash

# input e.g. output of `vault write some-ca/issue/global-nomad common_name=broccoli.global.nomad ttl=87000h alt_names=localhost ip_sans=127.0.0.1`
# form: 
#  ca_chain            [-----BEGIN CERTIFICATE-----
#  -----END CERTIFICATE----- -----BEGIN CERTIFICATE-----
#  certificate         -----BEGIN CERTIFICATE-----
#  issuing_ca          -----BEGIN CERTIFICATE-----
#  private_key         -----BEGIN RSA PRIVATE KEY-----

function usage {
  echo "Usage: $0 <filename>, where <filename> contains the output of some \"vault write pki/issue\" command, that is: ca_chain, certificate, issuing_ca, private_key. It will output 3 files, based on the input filename: $FILE-key.pem $FILE.pem $FILE-chain.pem. Note that these files will be overwritten if they exist."
}

if [[ $# -ne 1 || ! -f $1 ]]; then usage; exit 1; fi

FILE=$1
set -euo pipefail
IFS=$'\n\t'
# please name the file nicely - or rename at your own risk
# create private key file
sed '/^private_key/,$!d' $FILE | sed '/private_key_type/,$d' | sed -E 's/private_key +(----.*)/\1/' > $FILE-key.pem
openssl rsa -in $FILE-key.pem -check > /dev/null 2>&1
KEY_OK=$?
echo "Created key file $FILE-key.pem, check returned $KEY_OK"
# create certificate file
sed '/^issuing_ca/,$d' $FILE | sed '/^certificate/,$!d' | sed -E 's/certificate +(----.*)/\1/' > $FILE.pem
openssl x509 -in $FILE.pem -noout
CERT_OK=$?
echo "Created key file $FILE.pem, check returned $CERT_OK"
# create chain file
sed '/^certificate/,$d' $FILE | tail --lines=+3 | sed -E 's/ca_chain +\[(----.*)/\1/' | sed 's/CERTIFICATE----- -----BEGIN/CERTIFICATE-----\n-----BEGIN/' | sed 's/-----END CERTIFICATE-----]/-----END CERTIFICATE-----/' > /tmp/chain; cat $FILE.pem /tmp/chain > $FILE-chain.pem; rm /tmp/chain
openssl x509 -in $FILE-chain.pem -noout
CHAIN_OK=$?
echo "Created key file $FILE-chain.pem, check returned $CHAIN_OK"

echo -e "Files created: \n $FILE-key.pem $FILE.pem $FILE-chain.pem\n"


