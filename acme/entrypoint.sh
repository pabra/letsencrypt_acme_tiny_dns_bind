#!/bin/bash

set -e

ACCOUNT_KEY_FILE=/certs/account.key
ACME_CONFIG_FILE=/tmp/config.ini

ensure_rsa_key() {
    local file_path=$1
    local bits=$2

    if [ -z "$bits" ]; then
        bits=2048
    fi

    if [ ! -e "$file_path" ]; then
        echo "generating new key: '$file_path'"
        openssl genrsa "$bits" > "$file_path"
    else
        echo "key already exists: '$file_path'"
    fi
}

ensure_domain_config() {
    local config_file="$1"
    local base_name
    base_name=$( basename "$config_file" | sed 's/\.cfg//' )
    local csr_file="/certs/${base_name}.csr"
    local tmp_csr=/tmp/csr
    local domain_key_file="/certs/${base_name}.key"
    local common_name
    local alt_names
    local line

    if [ ! -e "$domain_key_file" ] && [ -e "$csr_file" ]; then
        echo "Found CSR '$csr_file' without key '$domain_key_file'. Deleting CSR now."
        unlink "$csr_file"
    fi

    ensure_rsa_key "$domain_key_file"

    if [ -e "$csr_file" ]; then
        echo "CSR file '$csr_file' already exists. Delete it first to generate a new/updated one."
        return 0
    fi

    while read -r line; do
        # ignore empty line
        if [ -z "$line" ]; then
            continue
        fi

        # ignore leading hash (#)
        if [ "$( echo "$line" | cut -c1-1 )" = '#' ]; then
            continue
        fi

        if [ -z "$common_name" ]; then
            common_name=$line
        elif [ -z "$alt_names" ]; then
            alt_names="DNS:${common_name},DNS:${line}"
        else
            alt_names="${alt_names},DNS:${line}"
        fi
    done < "$config_file"

    if [ -z "$alt_names" ]; then
        # no alternative names
        echo "Generate new CSR '$csr_file' - CN=${common_name}"

        if openssl req \
            -new \
            -sha256 \
            -key "$domain_key_file" \
            -subj "/CN=${common_name}" \
            > "$tmp_csr"
        then
            cp "$tmp_csr" "$csr_file"
            unlink "$tmp_csr"
        fi
    else
        # with alternative names
        echo "Generate new CSR '$csr_file' - CN=${common_name} ${alt_names}"

        if openssl req \
            -new \
            -sha256 \
            -key "$domain_key_file" \
            -subj "/CN=${common_name}" \
            -reqexts SAN \
            -config \
                <(cat /etc/ssl/openssl.cnf \
                    <(printf "[SAN]\\nsubjectAltName=%s" "$alt_names")) \
            > "$tmp_csr"
        then
            cp "$tmp_csr" "$csr_file"
            unlink "$tmp_csr"
        fi
    fi
}

ensure_acme_config() {
    [ -z "${CHALLENGE_ZONE}" ] && echo 'CHALLENGE_ZONE not set' && exit 1
    [ -z "${CHALLENGE_NS}" ] && echo 'CHALLENGE_NS not set' && exit 1
    [ -z "${TSIG_KEY_NAME}" ] && echo 'TSIG_KEY_NAME not set' && exit 1
    [ -z "${TSIG_KEY_ALGORITHM}" ] && echo 'TSIG_KEY_ALGORITHM not set' && exit 1

    local acme_config
    local acme_directory
    local contacts_entry
    local key_file="/keys/${TSIG_KEY_NAME}"
    local key_secret

    key_secret=$( grep secret "$key_file" | cut -d\" -f2 )


    if [ "$ACME_SERVER" = staging ]; then
        acme_directory=https://acme-staging-v02.api.letsencrypt.org/directory
    elif [ "$ACME_SERVER" = production ]; then
        acme_directory=https://acme-v02.api.letsencrypt.org/directory
    else
        echo "ACME_SERVER must be 'staging' or 'production'."
        exit 1
    fi


    if [ ! -e "$ACCOUNT_KEY_FILE" ]; then
        echo "Missing account key file: '$ACCOUNT_KEY_FILE'"
        exit 1
    fi


    if [ -z "${key_secret}" ]; then
        echo "key_secret not set in '$key_file'"
        cat "$key_file"
        exit 1
    fi


    if [ -n "$ACME_CONTACTS" ]; then
        contacts_entry="Contacts = $ACME_CONTACTS"
    fi

    acme_config="
[acmednstiny]
AccountKeyFile = ${ACCOUNT_KEY_FILE}
# ACMEDirectory = https://acme-v02.api.letsencrypt.org/directory
# ACMEDirectory = https://acme-staging-v02.api.letsencrypt.org/directory
ACMEDirectory = ${acme_directory}
# Contacts = mailto:mail@example.com;mailto:mail2@example.org
${contacts_entry}
# CertificateFormat = application/pem-certificate-chain

[TSIGKeyring]
KeyName = ${TSIG_KEY_NAME}
KeyValue = ${key_secret}
Algorithm = ${TSIG_KEY_ALGORITHM}

[DNS]
Zone = ${CHALLENGE_ZONE}
Host = ${CHALLENGE_NS}
"

    echo "$acme_config" > "$ACME_CONFIG_FILE"
}

request_cert() {
    local csr_file="$1"
    local base_name
    base_name=$( basename "$csr_file" | sed 's/\.csr//' )
    local tmp_cert=/tmp/cert
    local cert_file="/certs/${base_name}.pem"

    if [ ! -e "$csr_file" ]; then
        echo "Missing CSR file: '$csr_file'"
        exit 1
    fi

    if [ ! -e "$ACME_CONFIG_FILE" ]; then
        echo "Missing acme config file: '$ACME_CONFIG_FILE'"
        exit 1
    fi

    if acme_dns_tiny.py --verbose --csr "$csr_file" "$ACME_CONFIG_FILE" > "$tmp_cert"; then
        cp "$tmp_cert" "$cert_file"
        unlink "$tmp_cert"
    fi
}

do_renew() {
    local some_csr_files=false
    local csr_file

    ensure_acme_config

    while IFS= read -r -d '' csr_file; do
        some_csr_files=true
        echo "csr_file: '$csr_file'"
        request_cert "$csr_file"
    done < <( find /certs -name '*.csr' -print0 )

    if [ $some_csr_files = false ]; then
        echo 'no sign request files found'
    fi
}

do_prepare() {
    ensure_rsa_key "$ACCOUNT_KEY_FILE" 4096

    local some_cfg_files=false
    local config_file

    while IFS= read -r -d '' config_file; do
        some_cfg_files=true
        echo "config_file: '$config_file'"
        ensure_domain_config "$config_file"
    done < <( find /certs -name '*.cfg' -print0 )

    if [ $some_cfg_files = false ]; then
        echo 'no domain config files found'
    fi
}

show_usage() {
    echo "Usage: $0 <prepare | renew>"
    exit 1
}

case $1 in
    prepare)
        do_prepare
        ;;
    renew)
        do_renew
        ;;
    *)
        show_usage
        ;;
esac
