upstream php {
    server {{ getenv "NGINX_BACKEND_HOST" }}:9000;
}

map $http_x_forwarded_proto $fastcgi_https {
    default $https;
    http '';
    https on;
}

    fastcgi_cache_path /var/www/html/nginxcache keys_zone=islman:1024m inactive=7200m;
    fastcgi_cache_key "$scheme$request_method$host$request_uri";

server {
    server_name {{ getenv "NGINX_SERVER_NAME" "drupal" }};
    listen 80 default_server{{ if getenv "NGINX_HTTP2" }} http2{{ end }};

    root {{ getenv "NGINX_SERVER_ROOT" "/var/www/html/" }};
    index index.php;

    include fastcgi.conf;

{{ if getenv "NGINX_DRUPAL_HIDE_HEADERS" }}
    fastcgi_hide_header 'X-Drupal-Cache';
    fastcgi_hide_header 'X-Generator';
    fastcgi_hide_header 'X-Drupal-Dynamic-Cache';
{{ end }}

    location / {
{{ if getenv "NGINX_DRUPAL_FILE_PROXY_URL" }}
        location ~* /sites/.+/files {
            try_files $uri @file_proxy;
        }
{{ end }}
        location ~* /system/files/ {
            include fastcgi.conf;
            fastcgi_param QUERY_STRING q=$uri&$args;
            fastcgi_param SCRIPT_NAME /index.php;
            fastcgi_param SCRIPT_FILENAME $document_root/index.php;
            fastcgi_pass php;
            log_not_found off;
        }

        location ~* /sites/.+/files/private/ {
            internal;
        }

        location ~* /islandora/object/.+/datastream/.+/view {


            fastcgi_connect_timeout 10s;
            fastcgi_cache_lock on;
            fastcgi_cache_use_stale error timeout invalid_header updating http_500;
            fastcgi_cache_valid 7200m;
            fastcgi_ignore_headers Cache-Control Expires Set-Cookie;
            fastcgi_cache islman;

            add_header X-Cache-Status $upstream_cache_status;

            include fastcgi.conf;
            fastcgi_param QUERY_STRING $query_string;
            fastcgi_param SCRIPT_NAME /index.php;
            fastcgi_param SCRIPT_FILENAME $document_root/index.php;
            fastcgi_pass php;


        }

        location ~* /files/styles/ {
            access_log {{ getenv "NGINX_STATIC_CONTENT_ACCESS_LOG" "off" }};
            expires {{ getenv "NGINX_STATIC_CONTENT_EXPIRES" "30d" }};
            try_files $uri @drupal;
        }

        location ~* /sites/.+/files/.+\.txt {
            access_log {{ getenv "NGINX_STATIC_CONTENT_ACCESS_LOG" "off" }};
            expires {{ getenv "NGINX_STATIC_CONTENT_EXPIRES" "30d" }};
            tcp_nodelay off;
            open_file_cache {{ getenv "NGINX_STATIC_CONTENT_OPEN_FILE_CACHE" "max=3000 inactive=120s" }};
            open_file_cache_valid {{ getenv "NGINX_STATIC_CONTENT_OPEN_FILE_CACHE_VALID" "45s" }};
            open_file_cache_min_uses {{ getenv "NGINX_STATIC_CONTENT_OPEN_FILE_CACHE_MIN_USES" "2" }};
            open_file_cache_errors off;
        }

        location ~* /sites/.+/files/advagg_css/ {
            expires max;
            add_header ETag '';
            add_header Last-Modified 'Wed, 20 Jan 1988 04:20:42 GMT';
            add_header Accept-Ranges '';
            location ~* /sites/.*/files/advagg_css/css[_[:alnum:]]+\.css$ {
                access_log {{ getenv "NGINX_STATIC_CONTENT_ACCESS_LOG" "off" }};
                try_files $uri @drupal;
            }
        }

        location ~* /sites/.+/files/advagg_js/ {
            expires max;
            add_header ETag '';
            add_header Last-Modified 'Wed, 20 Jan 1988 04:20:42 GMT';
            add_header Accept-Ranges '';
            location ~* /sites/.*/files/advagg_js/js[_[:alnum:]]+\.js$ {
                access_log {{ getenv "NGINX_STATIC_CONTENT_ACCESS_LOG" "off" }};
                try_files $uri @drupal;
            }
        }

        location ~* /admin/reports/hacked/.+/diff/ {
            try_files $uri @drupal;
        }
{{ if getenv "NGINX_ALLOW_XML_ENDPOINTS" }}
        location ~* ^.+\.xml {
            try_files $uri @drupal;
        }
{{ else }}
        location ~* /rss.xml {
            try_files $uri @drupal-no-args;
        }

        location ~* /sitemap.xml {
            try_files $uri @drupal;
        }
{{ end }}
        location ~* ^.+\.(?:css|cur|js|jpe?g|gif|htc|ico|png|xml|otf|ttf|eot|woff|woff2|svg|svgz)$ {
            access_log {{ getenv "NGINX_STATIC_CONTENT_ACCESS_LOG" "off" }};
            expires {{ getenv "NGINX_STATIC_CONTENT_EXPIRES" "30d" }};
            tcp_nodelay off;
            open_file_cache {{ getenv "NGINX_STATIC_CONTENT_OPEN_FILE_CACHE" "max=3000 inactive=120s" }};
            open_file_cache_valid {{ getenv "NGINX_STATIC_CONTENT_OPEN_FILE_CACHE_VALID" "45s" }};
            open_file_cache_min_uses {{ getenv "NGINX_STATIC_CONTENT_OPEN_FILE_CACHE_MIN_USES" "2" }};
            open_file_cache_errors off;

            location ~* ^.+\.svgz$ {
                gzip off;
                add_header Content-Encoding gzip;
            }
        }

        location ~* ^.+\.(?:pdf|pptx?)$ {
            expires {{ getenv "NGINX_STATIC_CONTENT_EXPIRES" "30d" }};
            tcp_nodelay off;
        }

        location ~* ^(?:.+\.(?:htaccess|make|txt|engine|inc|info|install|module|profile|po|pot|sh|.*sql|test|theme|tpl(?:\.php)?|xtmpl)|code-style\.pl|/Entries.*|/Repository|/Root|/Tag|/Template)$ {
            return 404;
        }
{{ if getenv "NGINX_DRUPAL_BOOST_CACHE_ENABLE" }}
        try_files @cache $uri @drupal;
{{ else }}
        try_files $uri @drupal;
{{ end }}
    }

    location @cache {
        add_header Expires "Tue, 22 Sep 1974 08:00:00 GMT";
        add_header Cache-Control "must-revalidate, post-check=0, pre-check=0";
        try_files /cache/normal/islgman.qnl.qa/${uri}_${query_string}.html /cache/normal/islgman.qnl.qa/${uri}_.html  @drupal;
    }

{{ if getenv "NGINX_DRUPAL_FILE_PROXY_URL" }}
    location @file_proxy {
        rewrite ^ {{ getenv "NGINX_DRUPAL_FILE_PROXY_URL" }}$request_uri? permanent;
    }
{{ end }}

    location @drupal {



        if ($request_method !~ ^(GET|HEAD)$ ) {
        return 405;
        }
        error_page 405 = @drupalback;

        add_header X-Custom-Uri $uri;
        add_header X-Custom-Qry $query_string;
        add_header X-Cache-Status $upstream_cache_status;

        try_files /cache/normal/islgman.qnl.qa/${uri}_${query_string}.html  @drupalback;

    }

    location @drupalback{

        include fastcgi.conf;
        fastcgi_connect_timeout 10s;
        fastcgi_param QUERY_STRING $query_string;
        fastcgi_param SCRIPT_NAME /index.php;
        fastcgi_param SCRIPT_FILENAME $document_root/index.php;
        fastcgi_pass php;
        track_uploads {{ getenv "NGINX_DRUPAL_TRACK_UPLOADS" "uploads 60s" }};

    }

    location @drupal-no-args {
        include fastcgi.conf;
        fastcgi_param QUERY_STRING q=$uri;
        fastcgi_param SCRIPT_NAME /index.php;
        fastcgi_param SCRIPT_FILENAME $document_root/index.php;
        fastcgi_pass php;
    }

    location ~* ^/authorize.php {
        include fastcgi.conf;
        fastcgi_param QUERY_STRING $args;
        fastcgi_param SCRIPT_NAME /authorize.php;
        fastcgi_param SCRIPT_FILENAME $document_root/authorize.php;
        fastcgi_pass php;
    }

    location = /cron.php {
        fastcgi_pass php;
    }

    location = /index.php {
        fastcgi_pass php;
    }

    location = /install.php {
        fastcgi_pass php;
    }

    location ~* ^/update.php {
        fastcgi_pass php;
    }

    location = /xmlrpc.php {
        {{ if getenv "NGINX_XMLRPC_SERVER_NAME" "" }}
        include fastcgi.conf;
        fastcgi_param  SERVER_NAME {{ getenv "NGINX_XMLRPC_SERVER_NAME" }};
        {{ end }}
        fastcgi_pass php;
    }

    location ^~ /.bzr {
        return 404;
    }

    location ^~ /.git {
        return 404;
    }

    location ^~ /.hg {
        return 404;
    }

    location ^~ /.svn {
        return 404;
    }

    location ^~ /.cvs {
        return 404;
    }

    location ^~ /patches {
        return 404;
    }

    location ^~ /backup {
        return 404;
    }

    location = /robots.txt {
        access_log {{ getenv "NGINX_STATIC_CONTENT_ACCESS_LOG" "off" }};
        try_files $uri @drupal-no-args;
    }

    location = /favicon.ico {
        expires {{ getenv "NGINX_STATIC_CONTENT_EXPIRES" "30d" }};
        try_files /favicon.ico @empty;
    }

    location ~* ^/.well-known/ {
        allow all;
    }

    location @empty {
        expires {{ getenv "NGINX_STATIC_CONTENT_EXPIRES" "30d" }};
        empty_gif;
    }

    location ~* ^.+\.php$ {
        return 404;
    }

    location ~ (?<upload_form_uri>.*)/x-progress-id:(?<upload_id>\d*) {
        rewrite ^ $upload_form_uri?X-Progress-ID=$upload_id;
    }

    location ~ ^/progress$ {
        upload_progress_json_output;
        report_uploads uploads;
    }

    include healthz.conf;
{{ if getenv "NGINX_SERVER_EXTRA_CONF_FILEPATH" }}
    include {{ getenv "NGINX_SERVER_EXTRA_CONF_FILEPATH" }};
{{ end }}
}
