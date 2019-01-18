
.PHONY: cert deploy plan

# Cosmetics
YELLOW := "\e[1;33m"
NC := "\e[0m"

# Shell Functions
INFO := @bash -c '\
  printf $(YELLOW); \
  echo "=> $$1"; \
  printf $(NC)' SOME_VALUE

cert:
	${INFO} "Creating CA Root Keyfile....."
	@ openssl genrsa -des3 -out cert/rootCA.key 4096
	${INFO} "Creating CA Root crtfile....."
	@ openssl req -x509 -new -nodes -key cert/rootCA.key -sha256 -days 1024 -out cert/rootCA.crt
	${INFO} "Creating *.localdomain certificate....."
	${INFO} "Creating keyfile....."
	@ openssl genrsa -out cert/localdomain.key 2048
	${INFO} "Creating csr file....."
	@ openssl req -new -key cert/localdomain.key -out cert/localdomain.csr -config cert/cert.conf
	${INFO} "Creating crt file....."
	@ openssl x509 -req -in cert/localdomain.csr -CA cert/rootCA.crt -CAkey cert/rootCA.key -CAcreateserial -out cert/localdomain.crt -days 500 -sha256 -extfile cert/cert.conf -extensions req_ext
	${INFO} "Creating pem file....."
	@ cat cert/localdomain.crt cert/localdomain.key > assets/localdomain.key.pem
	${INFO} "Finished!"

plan:
	${INFO} "Initializing....."
	@ terraform init
	${INFO} "Creating plan ...."
	@ terraform plan
	${INFO} "Finished!"

deploy:
	${INFO} "deploying....."
	@ terraform apply -auto-approve
	${INFO} "Finished!"