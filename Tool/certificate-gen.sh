#! /bin/bash
#https://www.mingfer.cn/2020/06/13/altern-name
echo "INFO: 清理环境"
rm *.rsa *.jks *.p12 *.csr *.srl

cat > ca.cnf <<EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req

[req_distinguished_name]
countryName = Country Name (2 letter code)
stateOrProvinceName = State or Province Name (full name)
organizationName = Organization Name (eg, company)
commonName = Common Name (eg, name)

[v3_req]
basicConstraints = CA:true
keyUsage = critical, keyCertSign
EOF

cat > server.cnf <<EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req

[req_distinguished_name]
countryName = Country Name (2 letter code)
stateOrProvinceName = State or Province Name (full name)
localityName = Locality Name (eg, city)
organizationName = Organization Name (eg, company)
commonName = Common Name (eg, name)
commonName_max = 64

policy = policy_anything
[ policy_anything ]
countryName = optional
stateOrProvinceName = optional
localityName = optional
organizationName = optional
organizationalUnitName  = optional
commonName = supplied
emailAddress = optional

[v3_req]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = clientAuth, serverAuth
subjectAltName = @alt_names

[alt_names]
IP.1 = 127.0.0.1
EOF

if [ -e ./ca.key ]; then
  echo "INFO: 无需生成 ca 证书"
else
  echo "INFO: 生成 ca 证书"
  openssl ecparam -genkey -name secp256r1 | openssl ec -out ca.key
  openssl req -x509 -new -key ca.key -out ca.pem -config ca.cnf -extensions v3_req -days 36500
fi

echo "INFO: 生成 server 证书"
read -p "请输入服务器域名或者主机名：" server
read -p "请输入证书文件名：" cert
echo "INFO: set alt_names $server"
old_server=$(grep "IP.1 = " server.cnf|awk -F " " '{print $3}')
echo "INFO: 将 alt_names 从 $old_server 修改为 $server"
sed -i "s/$old_server/$server/g" server.cnf
openssl ecparam -genkey -name secp256r1 | openssl ec -out "$cert".key
openssl req -new -key "$cert".key -out "$cert".csr -config server.cnf
openssl x509 -req -CA ca.pem -CAkey ca.key -CAcreateserial -in "$cert".csr -out "$cert".pem -extensions v3_req -extfile server.cnf -days 36500

echo "INFO: 合并证书链"
cat ca.pem >> "$cert".pem

echo "INFO：清理无用文件"
rm *.rsa *.csr ca.srl *cnf
