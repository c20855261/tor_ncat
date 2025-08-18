FROM debian:bullseye-slim
 
# 安裝必要套件
RUN apt-get update && apt-get install -y \
    tor \
    unzip \
    procps \
    proxychains4 \
    ncat \
    curl \
    dnsutils \
    libssl-dev \
    pkg-config \
    build-essential \
    net-tools \
    htop \
    tzdata \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
 
# 創建tor用戶和目錄
RUN useradd -r -s /bin/false tor && \
    mkdir -p /var/lib/tor && \
    chown -R tor:tor /var/lib/tor && \
    chmod 700 /var/lib/tor
 
# 配置proxychains
RUN echo "strict_chain" > /etc/proxychains4.conf && \
    echo "proxy_dns" >> /etc/proxychains4.conf && \
    echo "tcp_read_time_out 15000" >> /etc/proxychains4.conf && \
    echo "tcp_connect_time_out 8000" >> /etc/proxychains4.conf && \
    echo "[ProxyList]" >> /etc/proxychains4.conf && \
    echo "socks5 127.0.0.1 9050" >> /etc/proxychains4.conf
 
# 創建proxychains符號連結
RUN ln -sf /usr/bin/proxychains4 /usr/bin/proxychains
 
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && \
    echo "alias ll='ls -l'" >> ~/.bashrc && \
    echo $TZ > /etc/timezone
 
# 設置工作目錄                                                                                                                                                
WORKDIR /opt
 
# 複製腳本並設置權限
COPY stress-test.sh /opt/
RUN chmod +x /opt/stress-test.sh
 
#CMD ["bash", "/opt/stress-test.sh"]

