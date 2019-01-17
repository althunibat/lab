

.PHONY: pre deploy plan

# Cosmetics
YELLOW := "\e[1;33m"
NC := "\e[0m"

# Shell Functions
INFO := @bash -c '\
  printf $(YELLOW); \
  echo "=> $$1"; \
  printf $(NC)' SOME_VALUE

pre:
	${INFO} "Creating CA Root....."
	@ openssl genrsa -des3 -out cert/rootCA.key 4096
	@ openssl req -x509 -new -nodes -key cert/rootCA.key -sha256 -days 1024 -out cert/rootCA.crt
	${INFO} "Creating *.localdomain certificate....."
	@ openssl genrsa -out cert/localdomain.key 2048
	@ openssl req -new -key cert/localdomain.key -out cert/localdomain.csr -config cert/cert.conf
	@ openssl x509 -req -in cert/localdomain.csr -CA cert/rootCA.crt -CAkey cert/rootCA.key -CAcreateserial -out cert/localdomain.crt -days 500 -sha256 -extfile cert/cert.conf -extensions req_ext
	@ cat cert/localdomain.crt cert/localdomain.key > assets/localdomain.key.pem
	${INFO} "Finished!"
	
plan:
	${INFO} "Initializing....."
	@ terraform init
	${INFO} "Creating plan ...."
	@ terraform plan -o out
	${INFO} "Finished!"

deploy:
	${INFO} "deploying....."
	@ terraform apply -auto-approve
	${INFO} "Finished!"