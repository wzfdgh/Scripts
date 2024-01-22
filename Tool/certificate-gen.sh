#! /bin/bash
#https://www.mingfer.cn/2020/06/13/altern-name
echo "INFO: 清理环境"
rm *.rsa *.jks *.p12 *.key *.csr *.srl

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

####################################################################
[ ca ]
default_ca = CA_default

####################################################################
[ CA_default ]

dir = .
certs = $dir
crl_dir = $dir
database = $dir/index.txt
#unique_subject = no

new_certs_dir = $dir

certificate = $dir/ca.pem
serial      = $dir/serial
crlnumber   = $dir/crlnumber

crl     = $dir/crl.pem
private_key = $dir/private/cakey.pem
RANDFILE    = $dir/private/.rand

x509_extensions = usr_cert

name_opt = ca_default
cert_opt = ca_default

default_days = 36500
default_crl_days = 30
default_md = default
preserve = no

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
subjectAltName = @alt_names

[alt_names]
IP.1 = 127.0.0.1
EOF

echo "INFO: 生成自签发证书"
openssl req -x509 -new -newkey rsa:2048 -nodes -keyout ca.key -out ca.pem -config ca.cnf -days 36500 -extensions v3_req

echo "INFO: 签发服务端证书"
read -p "请输入服务器域名或者主机名：" server
echo "INFO: set alt_names $server"
old_server=$(grep "IP.1 = " server.cnf|awk -F " " '{print $3}')
echo "INFO: 将 alt_names 从 $old_server 修改为 $server"
sed -i "s/$old_server/$server/g" server.cnf
openssl genrsa -out server.key 2048
openssl req -new -key server.key -out server.csr -config server.cnf
openssl x509 -req -CA ca.pem -CAkey ca.key -CAcreateserial -in server.csr -out server.pem -extensions v3_req -extfile server.cnf -days 36500

echo "INFO：清理无用文件"
rm *.rsa *.csr ca.srl *cnf