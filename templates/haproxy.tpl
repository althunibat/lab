#---------------------------------------------------------------------
# Global settings
#---------------------------------------------------------------------
global
    maxconn     5120
    tune.ssl.default-dh-param   2048

#---------------------------------------------------------------------
# common defaults that all the 'listen' and 'backend' sections will 
# use if not designated in their block
#---------------------------------------------------------------------
defaults
    log         global
    timeout connect 5s
    timeout client 5s
    timeout server 5s
    retries     3
    stats enable
    stats hide-version
    stats refresh 5s
    stats show-node
    stats uri  /haproxy?stats

#---------------------------------------------------------------------
# Listen  lb
#---------------------------------------------------------------------
frontend lb  
        mode http
	# we need to bind both to http and https
        bind ${bind_ip}:80
        bind ${bind_ip}:443 ssl crt /usr/local/etc/haproxy/localdomain.key.pem alpn h2,http/1.1
        option forwardfor
        http-request set-header X-Forwarded-Proto https if { ssl_fc }
        redirect scheme https if !{ ssl_fc }
        
	acl host_sw hdr(host) -i sw.localdomain 
	acl host_consul hdr(host) -i consul.localdomain
	acl host_api hdr(host) -i api.localdomain
	acl host_api_admin hdr(host) -i api-admin.localdomain
	 
	use_backend sw-cluster if host_sw
	use_backend consul-cluster if host_consul
	use_backend api-cluster if host_api
	use_backend api-admin-cluster if host_api_admin

