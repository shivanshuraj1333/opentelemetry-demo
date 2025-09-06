#!/bin/bash

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }

# Service definitions with ports and languages
declare -A SERVICES=(
    ["accounting"]="8080 .NET"
    ["ad"]="8081 Java"
    ["cart"]="8082 .NET"
    ["checkout"]="8083 Go"
    ["currency"]="8084 C++"
    ["email"]="8085 Ruby"
    ["fraud-detection"]="8086 Kotlin"
    ["frontend"]="3000 Node.js"
    ["frontend-proxy"]="8087 Envoy"
    ["image-provider"]="8088 Nginx"
    ["load-generator"]="8089 Python"
    ["payment"]="8090 Node.js"
    ["product-catalog"]="8091 Go"
    ["quote"]="8092 PHP"
    ["recommendation"]="8093 Python"
    ["shipping"]="8094 Rust"
)

# Function to create a simple HTTP server for any service
create_service() {
    local service_name=$1
    local port=$2
    local language=$3
    
    mkdir -p /opt/oteldemo/$service_name
    
    case $language in
        "Node.js")
            cat > /opt/oteldemo/$service_name/server.js << EOF
const http = require('http');
const port = $port;
const server = http.createServer((req, res) => {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
        service: '$service_name',
        status: 'running',
        port: port,
        language: '$language',
        timestamp: new Date().toISOString()
    }));
});
server.listen(port, '0.0.0.0', () => console.log(\`$service_name running on port \${port}\`));
EOF
            cat > /opt/oteldemo/$service_name/package.json << EOF
{
  "name": "$service_name",
  "version": "1.0.0",
  "main": "server.js",
  "scripts": {
    "start": "node server.js"
  }
}
EOF
            cd /opt/oteldemo/$service_name && npm install
            ;;
            
        "Python")
            cat > /opt/oteldemo/$service_name/server.py << EOF
#!/usr/bin/env python3
import http.server
import json
import socketserver
from datetime import datetime

class DemoHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.end_headers()
        response = {
            'service': '$service_name',
            'status': 'running',
            'port': $port,
            'language': '$language',
            'timestamp': datetime.now().isoformat()
        }
        self.wfile.write(json.dumps(response).encode())
    
    def do_POST(self):
        self.do_GET()

if __name__ == '__main__':
    with socketserver.TCPServer(('0.0.0.0', $port), DemoHandler) as httpd:
        print(f'$service_name running on port $port')
        httpd.serve_forever()
EOF
            chmod +x /opt/oteldemo/$service_name/server.py
            ;;
            
        "Go")
            cat > /opt/oteldemo/$service_name/main.go << EOF
package main

import (
    "encoding/json"
    "fmt"
    "net/http"
    "time"
)

type Response struct {
    Service   string \`json:"service"\`
    Status    string \`json:"status"\`
    Port      int    \`json:"port"\`
    Language  string \`json:"language"\`
    Timestamp string \`json:"timestamp"\`
}

func handler(w http.ResponseWriter, r *http.Request) {
    response := Response{
        Service:   "$service_name",
        Status:    "running",
        Port:      $port,
        Language:  "$language",
        Timestamp: time.Now().Format(time.RFC3339),
    }
    
    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(response)
}

func main() {
    http.HandleFunc("/", handler)
    fmt.Printf("$service_name running on port $port\\n")
    http.ListenAndServe(":${port}", nil)
}
EOF
            cd /opt/oteldemo/$service_name && go mod init $service_name && go build -o server main.go
            ;;
            
        "C++")
            cat > /opt/oteldemo/$service_name/server.cpp << EOF
#include <iostream>
#include <sstream>
#include <string>
#include <ctime>
#include <sys/socket.h>
#include <netinet/in.h>
#include <unistd.h>

int main() {
    int server_fd, new_socket;
    struct sockaddr_in address;
    int opt = 1;
    int addrlen = sizeof(address);
    
    if ((server_fd = socket(AF_INET, SOCK_STREAM, 0)) == 0) {
        perror("socket failed");
        exit(EXIT_FAILURE);
    }
    
    if (setsockopt(server_fd, SOL_SOCKET, SO_REUSEADDR | SO_REUSEPORT, &opt, sizeof(opt))) {
        perror("setsockopt");
        exit(EXIT_FAILURE);
    }
    
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = INADDR_ANY;
    address.sin_port = htons($port);
    
    if (bind(server_fd, (struct sockaddr *)&address, sizeof(address)) < 0) {
        perror("bind failed");
        exit(EXIT_FAILURE);
    }
    
    if (listen(server_fd, 3) < 0) {
        perror("listen");
        exit(EXIT_FAILURE);
    }
    
    std::cout << "$service_name running on port $port" << std::endl;
    
    while (true) {
        if ((new_socket = accept(server_fd, (struct sockaddr *)&address, (socklen_t*)&addrlen)) < 0) {
            perror("accept");
            exit(EXIT_FAILURE);
        }
        
        std::time_t now = std::time(0);
        std::string response = "HTTP/1.1 200 OK\\r\\nContent-Type: application/json\\r\\n\\r\\n";
        response += "{\\"service\\":\\"$service_name\\",\\"status\\":\\"running\\",\\"port\\":$port,\\"language\\":\\"$language\\",\\"timestamp\\":\\"" + std::to_string(now) + "\\"}";
        
        send(new_socket, response.c_str(), response.length(), 0);
        close(new_socket);
    }
    
    return 0;
}
EOF
            cd /opt/oteldemo/$service_name && g++ -o server server.cpp
            ;;
            
        "Ruby")
            cat > /opt/oteldemo/$service_name/server.rb << EOF
#!/usr/bin/env ruby
require 'webrick'
require 'json'
require 'time'

server = WEBrick::HTTPServer.new(:Port => $port, :BindAddress => '0.0.0.0')

server.mount_proc '/' do |req, res|
  res.status = 200
  res['Content-Type'] = 'application/json'
  response = {
    service: '$service_name',
    status: 'running',
    port: $port,
    language: '$language',
    timestamp: Time.now.iso8601
  }
  res.body = JSON.generate(response)
end

trap 'INT' do server.shutdown end
puts "$service_name running on port $port"
server.start
EOF
            chmod +x /opt/oteldemo/$service_name/server.rb
            ;;
            
        "Rust")
            cat > /opt/oteldemo/$service_name/Cargo.toml << EOF
[package]
name = "$service_name"
version = "0.1.0"
edition = "2021"

[dependencies]
tokio = { version = "1.0", features = ["full"] }
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"
warp = "0.3"
chrono = { version = "0.4", features = ["serde"] }
EOF
            cat > /opt/oteldemo/$service_name/src/main.rs << EOF
use warp::Filter;
use serde::{Deserialize, Serialize};
use chrono::{DateTime, Utc};

#[derive(Serialize, Deserialize)]
struct Response {
    service: String,
    status: String,
    port: u16,
    language: String,
    timestamp: String,
}

#[tokio::main]
async fn main() {
    let hello = warp::path::end()
        .map(|| {
            let response = Response {
                service: "$service_name".to_string(),
                status: "running".to_string(),
                port: $port,
                language: "$language".to_string(),
                timestamp: Utc::now().to_rfc3339(),
            };
            warp::reply::json(&response)
        });

    println!("$service_name running on port $port");
    warp::serve(hello)
        .run(([0, 0, 0, 0], $port))
        .await;
}
EOF
            cd /opt/oteldemo/$service_name && cargo build --release
            ;;
            
        "PHP")
            cat > /opt/oteldemo/$service_name/server.php << EOF
<?php
\$port = $port;
\$server = stream_socket_server("tcp://0.0.0.0:\$port", \$errno, \$errstr);

if (!\$server) {
    die("Failed to create server: \$errstr (\$errno)");
}

echo "$service_name running on port \$port\n";

while (true) {
    \$client = stream_socket_accept(\$server);
    if (\$client) {
        \$response = json_encode([
            'service' => '$service_name',
            'status' => 'running',
            'port' => \$port,
            'language' => '$language',
            'timestamp' => date('c')
        ]);
        
        \$http_response = "HTTP/1.1 200 OK\r\n";
        \$http_response .= "Content-Type: application/json\r\n";
        \$http_response .= "Content-Length: " . strlen(\$response) . "\r\n";
        \$http_response .= "\r\n";
        \$http_response .= \$response;
        
        fwrite(\$client, \$http_response);
        fclose(\$client);
    }
}
?>
EOF
            ;;
            
        "Envoy")
            cat > /opt/oteldemo/$service_name/envoy.yaml << EOF
static_resources:
  listeners:
  - name: listener_0
    address:
      socket_address:
        address: 0.0.0.0
        port_value: $port
    filter_chains:
    - filters:
      - name: envoy.filters.network.http_connection_manager
        typed_config:
          "@type": type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager
          stat_prefix: ingress_http
          route_config:
            name: local_route
            virtual_hosts:
            - name: local_service
              domains: ["*"]
              routes:
              - match:
                  prefix: "/"
                route:
                  cluster: service
          http_filters:
          - name: envoy.filters.http.router
  clusters:
  - name: service
    connect_timeout: 0.25s
    type: LOGICAL_DNS
    lb_policy: ROUND_ROBIN
    load_assignment:
      cluster_name: service
      endpoints:
      - lb_endpoints:
        - endpoint:
            address:
              socket_address:
                address: 127.0.0.1
                port_value: 3000
EOF
            ;;
            
        "Nginx")
            cat > /opt/oteldemo/$service_name/nginx.conf << EOF
events {
    worker_connections 1024;
}

http {
    server {
        listen $port;
        location / {
            return 200 '{"service":"$service_name","status":"running","port":$port,"language":"$language","timestamp":"'$(date -Iseconds)'"}';
            add_header Content-Type application/json;
        }
    }
}
EOF
            ;;
            
        ".NET")
            cat > /opt/oteldemo/$service_name/Program.cs << EOF
using System;
using System.Text.Json;
using System.Net;
using System.Text;

class Program
{
    static void Main()
    {
        var listener = new HttpListener();
        listener.Prefixes.Add($"http://*:$port/");
        listener.Start();
        
        Console.WriteLine("$service_name running on port $port");
        
        while (true)
        {
            var context = listener.GetContext();
            var response = context.Response;
            
            var data = new
            {
                service = "$service_name",
                status = "running",
                port = $port,
                language = "$language",
                timestamp = DateTime.UtcNow.ToString("o")
            };
            
            var json = JsonSerializer.Serialize(data);
            var buffer = Encoding.UTF8.GetBytes(json);
            
            response.ContentType = "application/json";
            response.ContentLength64 = buffer.Length;
            response.OutputStream.Write(buffer, 0, buffer.Length);
            response.OutputStream.Close();
        }
    }
}
EOF
            cat > /opt/oteldemo/$service_name/$service_name.csproj << EOF
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <OutputType>Exe</OutputType>
    <TargetFramework>net8.0</TargetFramework>
  </PropertyGroup>
</Project>
EOF
            cd /opt/oteldemo/$service_name && dotnet build -c Release
            ;;
            
        "Java")
            cat > /opt/oteldemo/$service_name/Main.java << EOF
import java.io.*;
import java.net.*;
import java.time.Instant;
import com.google.gson.Gson;

public class Main {
    public static void main(String[] args) throws IOException {
        ServerSocket serverSocket = new ServerSocket($port);
        System.out.println("$service_name running on port $port");
        
        while (true) {
            Socket clientSocket = serverSocket.accept();
            PrintWriter out = new PrintWriter(clientSocket.getOutputStream(), true);
            BufferedReader in = new BufferedReader(new InputStreamReader(clientSocket.getInputStream()));
            
            String response = "HTTP/1.1 200 OK\\r\\n" +
                            "Content-Type: application/json\\r\\n" +
                            "\\r\\n" +
                            new Gson().toJson(new Response("$service_name", "running", $port, "$language", Instant.now().toString()));
            
            out.println(response);
            clientSocket.close();
        }
    }
    
    static class Response {
        String service, status, language, timestamp;
        int port;
        
        Response(String service, String status, int port, String language, String timestamp) {
            this.service = service;
            this.status = status;
            this.port = port;
            this.language = language;
            this.timestamp = timestamp;
        }
    }
}
EOF
            ;;
            
        "Kotlin")
            cat > /opt/oteldemo/$service_name/Main.kt << EOF
import java.io.*
import java.net.*
import java.time.Instant
import com.google.gson.Gson

fun main() {
    val serverSocket = ServerSocket($port)
    println("$service_name running on port $port")
    
    while (true) {
        val clientSocket = serverSocket.accept()
        val out = PrintWriter(clientSocket.getOutputStream(), true)
        val response = Response("$service_name", "running", $port, "$language", Instant.now().toString())
        
        val httpResponse = "HTTP/1.1 200 OK\\r\\n" +
                         "Content-Type: application/json\\r\\n" +
                         "\\r\\n" +
                         Gson().toJson(response)
        
        out.println(httpResponse)
        clientSocket.close()
    }
}

data class Response(
    val service: String,
    val status: String,
    val port: Int,
    val language: String,
    val timestamp: String
)
EOF
            ;;
    esac
}

# Create all services
for service in "${!SERVICES[@]}"; do
    IFS=' ' read -r port language <<< "${SERVICES[$service]}"
    log_info "Creating $service service (port $port, $language)..."
    create_service "$service" "$port" "$language"
done

# Set ownership
chown -R oteldemo:oteldemo /opt/oteldemo

log_success "All demo services created!"
