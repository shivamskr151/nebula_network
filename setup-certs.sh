#!/bin/bash

set -e

echo "📁 Creating folder structure..."
mkdir -p nebula-lighthouse/certs
mkdir -p nebula-client/certs

echo "🔐 Generating CA certificate..."
nebula-cert ca -name testnet

echo "🔐 Generating Lighthouse certificate (10.1.1.1)..."
nebula-cert sign -name lighthouse -ip 10.1.1.1/24

echo "🔐 Generating Client certificate (10.1.1.2)..."
nebula-cert sign -name client -ip 10.1.1.2/24

echo "📦 Copying certificates to Lighthouse folder..."
cp ca.crt nebula-lighthouse/certs/
cp lighthouse.crt nebula-lighthouse/certs/
cp lighthouse.key nebula-lighthouse/certs/

echo "📦 Copying certificates to Client folder..."
cp ca.crt nebula-client/certs/
cp client.crt nebula-client/certs/
cp client.key nebula-client/certs/

echo "🧹 Cleaning root certificate clutter..."
rm -f ca.crt lighthouse.crt lighthouse.key client.crt client.key

echo "✅ DONE!"
echo "Certificates generated and placed in:"
echo "  ✦ nebula-lighthouse/certs/"
echo "  ✦ nebula-client/certs/"
