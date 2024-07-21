let 

  virtalHostCommon = {
    onlySSL = true;
    http2 = true;
  };

 in {
  services.nginx.enable = true;
  services.nginx.user = "www-data";

  services.nginx.httpConfig = "
  client_max_body_size 10G;

	sendfile on;
	tcp_nopush on;
	types_hash_max_size 2048;

	include /etc/nginx/mime.types;
	default_type application/octet-stream;

	ssl_certificate /etc/ssl/labile.cc.pem;
        ssl_certificate_key /etc/ssl/labile.cc.key;

	ssl_stapling off;

    	ssl_client_certificate /etc/ssl/cloudflare.crt;
    	ssl_verify_client on;

	ssl_protocols TLSv1 TLSv1.1 TLSv1.2 TLSv1.3; # Dropping SSLv3, ref: POODLE
	ssl_prefer_server_ciphers on;

	# Logging Settings
	access_log /var/log/nginx/access.log;
	error_log /var/log/nginx/error.log;

	gzip on;

	##
	# Virtual Host Configs
	##

	include /etc/nginx/conf.d/*.conf;
	include /etc/nginx/sites-enabled/*;

  ";

  services.nginx.virtualHosts = {
    "labile.cc" = { inherit virtalHostCommon; locations."/".proxyPass = "http://localhost:7004"; };
    "cloud.labile.cc" = { inherit virtalHostCommon; locations."/".proxyPass = "http://localhost:7009"; };
    "local.labile.cc" = { inherit virtalHostCommon; locations."/".proxyPass = "http://192.168.1.3:8080"; };
    "matrix.labile.cc" = { inherit virtalHostCommon; locations."/".proxyPass = "http://192.168.1.3:8008"; };
    "obsidian.labile.cc" = { inherit virtalHostCommon; locations."/".proxyPass = "http://192.168.1.3:7007"; };
    "torrent.labile.cc" = { inherit virtalHostCommon; locations."/".proxyPass = "http://192.168.1.3:7000"; };
    "vaultwarden.labile.cc" = { inherit virtalHostCommon; locations."/".proxyPass = "http://192.168.1.3:7005"; };
  };
  
}
